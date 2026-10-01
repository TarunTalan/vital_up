// Self-healing Gemini / Groq clients shared by edge functions.
//
// Model IDs are the part of these functions that rots fastest: providers
// retire models on a months-long cadence and a hardcoded ID turns into a hard
// 404 for every user (this is exactly what took the food scanner down when
// `gemini-2.0-flash` and `qwen/qwen3.6-27b` were shut off). So:
//   1. Each call tries an ordered list of models, overridable per environment
//      with a comma-separated secret (see each caller), so a retirement can be
//      fixed with `supabase secrets set`, no deploy.
//   2. When a model 404s it is blacklisted for this isolate's lifetime and
//      the provider's model catalogue is queried to discover a live
//      replacement automatically.
//   3. Rate limits move on to the next model, since quotas are per model.

type ErrorKind = 'model_not_found' | 'rate_limited' | 'bad_request' | 'auth' | 'server' | 'timeout' | 'blocked' | 'parse';

export class ProviderError extends Error {
  // Explicit field (not a constructor parameter property) so this module
  // also loads under Node's type stripping for unit tests.
  readonly kind: ErrorKind;

  constructor(kind: ErrorKind, message: string) {
    super(message);
    this.kind = kind;
  }
}

export const envList = (key: string, fallback: string[]): string[] => {
  const raw = Deno.env.get(key);
  const list = raw ? raw.split(',').map((s) => s.trim()).filter(Boolean) : [];
  return list.length > 0 ? list : fallback;
};

const DISCOVERY_TTL_MS = 6 * 60 * 60 * 1000;

function classifyHttpError(status: number, body: string): ErrorKind {
  const lower = body.toLowerCase();
  if (status === 404 || lower.includes('model_not_found') || lower.includes('decommissioned') ||
      lower.includes('no longer available') || lower.includes('is not found for api version')) {
    return 'model_not_found';
  }
  if (status === 429 || lower.includes('resource_exhausted')) return 'rate_limited';
  if (status === 401 || status === 403 || lower.includes('api key not valid') || lower.includes('invalid api key')) {
    return 'auth';
  }
  if (status === 400) return 'bad_request';
  return 'server';
}

function short(body: string): string {
  return body.replace(/\s+/g, ' ').slice(0, 300);
}

async function fetchWithSignal(url: string, init: RequestInit, signal?: AbortSignal): Promise<Response> {
  try {
    return await fetch(url, { ...init, signal });
  } catch (e) {
    if (signal?.aborted) throw new ProviderError('timeout', 'Request timed out');
    throw new ProviderError('server', `Network error: ${(e as Error).message}`);
  }
}

/**
 * Tries [models] in order, skipping blacklisted ones; if any were retired (or
 * none were usable) tries models from [discover]. Errors another model can't
 * fix (auth, timeout, blocked, bad request) are rethrown immediately.
 */
async function withModelFallback(
  provider: string,
  models: string[],
  dead: Set<string>,
  discover: () => Promise<string[]>,
  call: (model: string) => Promise<string>,
): Promise<string> {
  const tried = new Set<string>();
  const errors: string[] = [];
  let sawMissingModel = false;

  const attempt = async (list: string[]): Promise<string | null> => {
    for (const model of list) {
      if (tried.has(model) || dead.has(model)) continue;
      tried.add(model);
      try {
        return await call(model);
      } catch (e) {
        const err = e as ProviderError;
        errors.push(err.message);
        if (err.kind === 'model_not_found') {
          dead.add(model);
          sawMissingModel = true;
          console.warn(`${provider} model ${model} is unavailable; blacklisted.`);
          continue;
        }
        if (err.kind === 'rate_limited' || err.kind === 'server' || err.kind === 'parse') continue;
        throw err;
      }
    }
    return null;
  };

  const primary = await attempt(models);
  if (primary !== null) return primary;

  if (sawMissingModel || tried.size === 0) {
    try {
      const discovered = await attempt(await discover());
      if (discovered !== null) return discovered;
    } catch (e) {
      errors.push(`discovery: ${(e as Error).message}`);
    }
  }

  const rateLimited = errors.length > 0 && errors.every((m) => /\b429\b|RESOURCE_EXHAUSTED/i.test(m));
  throw new ProviderError(rateLimited ? 'rate_limited' : 'server', errors.join(' | ') || `No ${provider} model available`);
}

// ---------------------------------------------------------------------------
// Gemini
// ---------------------------------------------------------------------------

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta';
export const GEMINI_DEFAULT_MODELS = ['gemini-3.8-flash', 'gemini-flash-latest', 'gemini-3.5-flash-lite'];

const geminiDead = new Set<string>();
const geminiNoThinkingConfig = new Set<string>();
let geminiDiscovered: { models: string[]; at: number } | null = null;

export type GeminiPart = { text: string } | { inline_data: { mime_type: string; data: string } };

export interface GeminiOptions {
  /** Ordered model IDs; defaults to the GEMINI_MODELS secret, then [GEMINI_DEFAULT_MODELS]. */
  models?: string[];
  signal?: AbortSignal;
  json?: boolean;
  googleSearch?: boolean;
  maxOutputTokens?: number;
  temperature?: number;
  topP?: number;
}

function geminiRank(name: string): number {
  const version = parseFloat(name.match(/gemini-(\d+(?:\.\d+)?)/)?.[1] ?? '0');
  let score = version * 10;
  if (/-lite/.test(name)) score -= 3; // prefer full flash for quality
  if (/preview|exp|experimental/.test(name)) score -= 5; // prefer stable
  if (/latest/.test(name)) score -= 1;
  return score;
}

async function discoverGeminiModels(apiKey: string, signal?: AbortSignal): Promise<string[]> {
  if (geminiDiscovered && Date.now() - geminiDiscovered.at < DISCOVERY_TTL_MS) {
    return geminiDiscovered.models;
  }
  const res = await fetchWithSignal(`${GEMINI_BASE}/models?pageSize=1000&key=${apiKey}`, {}, signal);
  if (!res.ok) throw new ProviderError(classifyHttpError(res.status, ''), `Gemini ListModels ${res.status}`);
  const data = await res.json();
  const models: string[] = (data.models ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((m: any) => (m.supportedGenerationMethods ?? []).includes('generateContent'))
    // deno-lint-ignore no-explicit-any
    .map((m: any) => String(m.name ?? '').replace(/^models\//, ''))
    .filter((n: string) => /flash/.test(n) && !/image|tts|live|audio|embed|native|robotics|computer|thinking-exp/.test(n))
    .sort((a: string, b: string) => geminiRank(b) - geminiRank(a))
    .slice(0, 4);
  geminiDiscovered = { models, at: Date.now() };
  console.log(`Discovered Gemini models: ${models.join(', ')}`);
  return models;
}

async function geminiCall(apiKey: string, model: string, parts: GeminiPart[], opts: GeminiOptions): Promise<string> {
  const generationConfig: Record<string, unknown> = {
    temperature: opts.temperature ?? 0.2,
    maxOutputTokens: opts.maxOutputTokens ?? 4096,
  };
  if (opts.topP !== undefined) generationConfig.topP = opts.topP;
  // JSON mode + search grounding is not accepted by every model; with search
  // the caller parses JSON out of free text instead.
  if (opts.json && !opts.googleSearch) generationConfig.responseMimeType = 'application/json';
  // Keep reasoning short: it's the dominant latency cost on 3.x Flash models.
  if (!geminiNoThinkingConfig.has(model)) generationConfig.thinkingConfig = { thinkingLevel: 'low' };

  const body: Record<string, unknown> = { contents: [{ role: 'user', parts }], generationConfig };
  if (opts.googleSearch) body.tools = [{ googleSearch: {} }];

  const res = await fetchWithSignal(
    `${GEMINI_BASE}/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify(body),
    },
    opts.signal,
  );

  if (!res.ok) {
    const text = await res.text();
    const kind = classifyHttpError(res.status, text);
    if (kind === 'bad_request' && /thinking/i.test(text) && !geminiNoThinkingConfig.has(model)) {
      geminiNoThinkingConfig.add(model);
      return geminiCall(apiKey, model, parts, opts);
    }
    throw new ProviderError(kind, `Gemini ${model} ${res.status}: ${short(text)}`);
  }

  const data = await res.json();
  if (data.promptFeedback?.blockReason) {
    throw new ProviderError('blocked', `Gemini blocked prompt: ${data.promptFeedback.blockReason}`);
  }
  const candidate = data.candidates?.[0];
  const text = (candidate?.content?.parts ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((p: any) => !p.thought && typeof p.text === 'string')
    // deno-lint-ignore no-explicit-any
    .map((p: any) => p.text)
    .join('');
  if (!text) {
    throw new ProviderError('parse', `Gemini ${model} returned no text (finishReason=${candidate?.finishReason})`);
  }
  return text;
}

export function geminiGenerate(apiKey: string, parts: GeminiPart[], opts: GeminiOptions = {}): Promise<string> {
  return withModelFallback(
    'Gemini',
    opts.models ?? envList('GEMINI_MODELS', GEMINI_DEFAULT_MODELS),
    geminiDead,
    () => discoverGeminiModels(apiKey, opts.signal),
    (model) => geminiCall(apiKey, model, parts, opts),
  );
}

// ---------------------------------------------------------------------------
// Groq (OpenAI-compatible)
// ---------------------------------------------------------------------------

const GROQ_BASE = 'https://api.groq.com/openai/v1';

const groqDead = new Set<string>();
const groqPlainParams = new Set<string>();
const groqDiscovered = new Map<string, { models: string[]; at: number }>();

export interface GroqOptions {
  /** Ordered model IDs to try first. */
  models: string[];
  /** Which kind of replacement to look for if these are retired. */
  capability: 'vision' | 'text';
  signal?: AbortSignal;
  json?: boolean;
  temperature?: number;
  maxTokens?: number;
}

async function discoverGroqModels(apiKey: string, capability: 'vision' | 'text', signal?: AbortSignal): Promise<string[]> {
  const cached = groqDiscovered.get(capability);
  if (cached && Date.now() - cached.at < DISCOVERY_TTL_MS) return cached.models;
  const res = await fetchWithSignal(`${GROQ_BASE}/models`, { headers: { Authorization: `Bearer ${apiKey}` } }, signal);
  if (!res.ok) throw new ProviderError(classifyHttpError(res.status, ''), `Groq models ${res.status}`);
  const data = await res.json();
  // Groq's catalogue doesn't flag modality, so match known model families.
  const vision = /vision|scout|maverick|-vl\b|vl-|llava|qwen\/qwen3\.\d+-\d+b|gemma-?3|pixtral/i;
  const models: string[] = (data.data ?? [])
    // deno-lint-ignore no-explicit-any
    .filter((m: any) => m.active !== false)
    // deno-lint-ignore no-explicit-any
    .map((m: any) => String(m.id))
    .filter((id: string) => !/whisper|tts|guard|orpheus|playai|compound|embed|coder/i.test(id))
    .filter((id: string) => capability === 'text' ? /llama|gpt-oss|qwen|kimi|deepseek|gemma|mistral/i.test(id) : vision.test(id))
    .sort((a: string, b: string) => b.localeCompare(a, undefined, { numeric: true }))
    .slice(0, 3);
  groqDiscovered.set(capability, { models, at: Date.now() });
  console.log(`Discovered Groq ${capability} models: ${models.join(', ')}`);
  return models;
}

async function groqCall(apiKey: string, model: string, content: unknown, opts: GroqOptions): Promise<string> {
  const plain = groqPlainParams.has(model);
  const messages: unknown[] = [];
  if (opts.json) {
    messages.push({ role: 'system', content: 'You output only valid JSON. No reasoning, no markdown, no <think> tags.' });
  }
  messages.push({ role: 'user', content });

  const body: Record<string, unknown> = {
    model,
    messages,
    temperature: opts.temperature ?? 0.2,
    max_completion_tokens: opts.maxTokens ?? 2048,
  };
  if (!plain) {
    if (opts.json) body.response_format = { type: 'json_object' };
    body.reasoning_format = 'hidden';
  }

  const res = await fetchWithSignal(
    `${GROQ_BASE}/chat/completions`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    },
    opts.signal,
  );

  if (!res.ok) {
    const text = await res.text();
    const kind = classifyHttpError(res.status, text);
    // Some models reject reasoning_format / json mode, or fail json
    // validation: retry once with plain params and let the caller parse.
    if (kind === 'bad_request' && !plain && /reasoning|response_format|json/i.test(text)) {
      groqPlainParams.add(model);
      return groqCall(apiKey, model, content, opts);
    }
    throw new ProviderError(kind, `Groq ${model} ${res.status}: ${short(text)}`);
  }

  const data = await res.json();
  const text = data.choices?.[0]?.message?.content;
  if (!text) throw new ProviderError('parse', `Groq ${model} returned no content`);
  return text;
}

export function groqGenerate(apiKey: string, content: unknown, opts: GroqOptions): Promise<string> {
  return withModelFallback(
    'Groq',
    opts.models,
    groqDead,
    () => discoverGroqModels(apiKey, opts.capability, opts.signal),
    (model) => groqCall(apiKey, model, content, opts),
  );
}

// ---------------------------------------------------------------------------
// JSON extraction
// ---------------------------------------------------------------------------

/**
 * Models occasionally wrap JSON in markdown fences, prepend reasoning
 * (`<think>…</think>`), or add a sentence before/after the payload even in
 * JSON mode. Strip all of that and parse the first complete JSON value.
 */
export function extractJson(text: string): unknown {
  let cleaned = text.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
  cleaned = cleaned.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();

  try {
    return JSON.parse(cleaned);
  } catch {
    // fall through to bracket scanning
  }

  const start = cleaned.search(/[{[]/);
  if (start === -1) throw new Error('No JSON found in model output');

  // Walk forward tracking string state so braces inside strings don't count.
  const stack: string[] = [];
  let inString = false;
  let escaped = false;
  for (let i = start; i < cleaned.length; i++) {
    const ch = cleaned[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{' || ch === '[') stack.push(ch === '{' ? '}' : ']');
    else if (ch === '}' || ch === ']') {
      if (stack.pop() !== ch) break;
      if (stack.length === 0) return JSON.parse(cleaned.slice(start, i + 1));
    }
  }
  throw new Error('Unterminated JSON in model output');
}

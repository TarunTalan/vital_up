// Request hardening shared by the edge functions: body size / type checks,
// field validation, text sanitising, short JSON errors and constant-time
// secret comparison.
//
// No Deno-only APIs here (only web standards) so modules that import it stay
// loadable under Node's type stripping for unit tests (scan-food/nutrition.ts).

// ---------------------------------------------------------------------------
// Errors and responses
// ---------------------------------------------------------------------------

/** Thrown by validators; turned into `{ error }` with [status] by the handler. */
export class HttpError extends Error {
  // Explicit field (not a parameter property) so Node type stripping accepts it.
  readonly status: number;
  readonly extra?: Record<string, unknown>;

  constructor(status: number, message: string, extra?: Record<string, unknown>) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

export function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

/** `{ error: message, ...extra }`. [message] must be a short, user-safe sentence. */
export function errorResponse(
  status: number,
  message: string,
  extra: Record<string, unknown> = {},
  headers: Record<string, string> = {},
): Response {
  return jsonResponse({ ...extra, error: message }, status, headers);
}

/**
 * Maps anything thrown inside a handler to a safe JSON error. HttpErrors carry
 * their own status and message; everything else is logged and becomes a
 * generic 500 so internal details never reach the client.
 */
export function handleError(e: unknown, label: string, headers: Record<string, string> = {}): Response {
  if (e instanceof HttpError) return errorResponse(e.status, e.message, e.extra ?? {}, headers);
  console.error(`${label} failed:`, e);
  return errorResponse(500, "Something went wrong. Please try again.", {}, headers);
}

export function requireMethod(req: Request, ...allowed: string[]): void {
  if (!allowed.includes(req.method)) throw new HttpError(405, "Method not allowed.");
}

// ---------------------------------------------------------------------------
// Bodies
// ---------------------------------------------------------------------------

export const KB = 1024;
export const MB = 1024 * 1024;

/**
 * Reads the raw body as UTF-8, refusing anything over [maxBytes] (checked
 * against Content-Length first, then the bytes actually received, so a
 * missing or lying header can't get past it). Rejects a non-JSON
 * Content-Type when [json] is set; a missing Content-Type is tolerated.
 */
export async function readTextBody(req: Request, maxBytes: number, json = true): Promise<string> {
  const type = req.headers.get("content-type");
  if (json && type && !/\bjson\b/i.test(type)) {
    throw new HttpError(415, "Send the request body as JSON.");
  }

  const declared = req.headers.get("content-length");
  if (declared !== null && declared.trim() !== "") {
    const length = Number(declared);
    if (!Number.isFinite(length) || length < 0) throw new HttpError(400, "Invalid Content-Length.");
    if (length > maxBytes) throw new HttpError(413, "Request is too large.");
  }

  if (!req.body) return "";
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        reader.cancel().catch(() => {});
        throw new HttpError(413, "Request is too large.");
      }
      chunks.push(value);
    }
  } catch (e) {
    if (e instanceof HttpError) throw e;
    throw new HttpError(400, "Could not read the request body.");
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new HttpError(400, "Request body is not valid UTF-8.");
  }
}

export type JsonObject = Record<string, unknown>;

export function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Parses [text] as a JSON object (400 otherwise). Empty text is `{}` when [allowEmpty]. */
export function parseJsonObject(text: string, allowEmpty = false): JsonObject {
  if (text.trim() === "") {
    if (allowEmpty) return {};
    throw new HttpError(400, "Request body is required.");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new HttpError(400, "Request body is not valid JSON.");
  }
  if (!isObject(parsed)) throw new HttpError(400, "Request body must be a JSON object.");
  return parsed;
}

export async function readJsonBody(req: Request, maxBytes: number, allowEmpty = false): Promise<JsonObject> {
  return parseJsonObject(await readTextBody(req, maxBytes), allowEmpty);
}

// ---------------------------------------------------------------------------
// Auth helpers
// ---------------------------------------------------------------------------

/** The bearer token from the Authorization header, or "" when absent. */
export function bearerToken(req: Request): string {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : "";
}

/**
 * Constant-time string comparison. Runs over the longer input regardless of
 * where (or whether) the strings differ, so neither content nor length leaks
 * through timing beyond the input sizes themselves.
 */
export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  const len = Math.max(x.length, y.length);
  let diff = x.length ^ y.length;
  for (let i = 0; i < len; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

/** Character limits shared with the app's input fields. */
export const LIMITS = {
  name: 50,
  usernameMin: 3,
  usernameMax: 20,
  shortText: 80, // food names, titles
  note: 500,
  chatMessage: 1000,
  city: 60,
  search: 100,
} as const;

/** Numeric ranges shared with the app. */
export const RANGES = {
  weightKg: { min: 20, max: 350 },
  heightCm: { min: 50, max: 272 },
  age: { min: 13, max: 120 },
  calories: { min: 0, max: 10000 },
  grams: { min: 0, max: 5000 },
} as const;

// Built from code points so this file holds no literal invisible characters.
const ch = (code: number) => String.fromCharCode(code);
const span = (from: number, to: number) => ch(from) + "-" + ch(to);

/**
 * C0/C1 control characters (except tab, LF, CR), soft hyphen, Mongolian vowel
 * separator, zero-width characters, bidi embeddings/overrides/isolates, word
 * joiners and invisible operators, BOM and interlinear annotation marks.
 */
const INVISIBLE = new RegExp(
  "[" +
    span(0x00, 0x08) + ch(0x0b) + ch(0x0c) + span(0x0e, 0x1f) + span(0x7f, 0x9f) +
    ch(0xad) + ch(0x180e) + span(0x200b, 0x200f) + span(0x202a, 0x202e) +
    span(0x2060, 0x206f) + ch(0xfeff) + span(0xfff9, 0xfffb) +
    "]",
  "g",
);

export interface TextOptions {
  /** Keep line breaks (notes, chat). Otherwise all whitespace collapses to single spaces. */
  multiline?: boolean;
}

/**
 * Normalises (NFC), strips control and invisible characters, collapses
 * whitespace and trims. Never throws; non-strings become "".
 */
export function sanitizeText(value: unknown, opts: TextOptions = {}): string {
  if (typeof value !== "string") return "";
  let text = value.normalize("NFC").replace(INVISIBLE, "");
  if (opts.multiline) {
    text = text
      .replace(/\r\n?/g, "\n")
      .replace(/[^\S\n]+/g, " ")
      .replace(/ *\n */g, "\n")
      .replace(/\n{3,}/g, "\n\n");
  } else {
    text = text.replace(/\s+/g, " ");
  }
  return text.trim();
}

/** Cuts [text] to at most [max] UTF-16 units without splitting a surrogate pair. */
export function clipText(text: string, max: number): string {
  if (text.length <= max) return text;
  let cut = text.slice(0, max);
  const last = cut.charCodeAt(cut.length - 1);
  if (last >= 0xd800 && last <= 0xdbff) cut = cut.slice(0, -1);
  return cut.trimEnd();
}

/** Sanitises then clips; for model output and server-sourced strings. */
export function cleanText(value: unknown, max: number, opts: TextOptions = {}): string {
  return clipText(sanitizeText(value, opts), max);
}

export interface FieldTextOptions extends TextOptions {
  min?: number;
  max: number;
  /** Cut over-long input instead of rejecting it. */
  clip?: boolean;
  pattern?: RegExp;
}

/**
 * Validates an optional text field: undefined/null gives undefined; a
 * non-string or out-of-bounds value is a 400 naming [field].
 */
export function optionalText(value: unknown, field: string, opts: FieldTextOptions): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") throw new HttpError(400, `${field} must be text.`);
  let text = sanitizeText(value, opts);
  if (text.length > opts.max) {
    if (!opts.clip) throw new HttpError(400, `${field} must be at most ${opts.max} characters.`);
    text = clipText(text, opts.max);
  }
  if (opts.min !== undefined && text.length < opts.min) {
    throw new HttpError(400, `${field} must be at least ${opts.min} characters.`);
  }
  if (opts.pattern && !opts.pattern.test(text)) throw new HttpError(400, `${field} is not valid.`);
  return text;
}

export function requireText(value: unknown, field: string, opts: FieldTextOptions): string {
  const text = optionalText(value, field, opts);
  if (text === undefined || text === "") throw new HttpError(400, `${field} is required.`);
  return text;
}

// ---------------------------------------------------------------------------
// Numbers, enums, arrays
// ---------------------------------------------------------------------------

export interface NumberOptions {
  min: number;
  max: number;
  integer?: boolean;
}

export function optionalNumber(value: unknown, field: string, opts: NumberOptions): number | undefined {
  if (value === undefined || value === null) return undefined;
  const n = typeof value === "number" ? value : NaN;
  if (!Number.isFinite(n)) throw new HttpError(400, `${field} must be a number.`);
  if (opts.integer && !Number.isInteger(n)) throw new HttpError(400, `${field} must be a whole number.`);
  if (n < opts.min || n > opts.max) {
    throw new HttpError(400, `${field} must be between ${opts.min} and ${opts.max}.`);
  }
  return n;
}

export function requireNumber(value: unknown, field: string, opts: NumberOptions): number {
  const n = optionalNumber(value, field, opts);
  if (n === undefined) throw new HttpError(400, `${field} is required.`);
  return n;
}

/** Lenient number for model / upstream output: parses, clamps, falls back. */
export function clampNumber(value: unknown, min: number, max: number, fallback = 0): number {
  const n = typeof value === "number" ? value : typeof value === "string" ? parseFloat(value) : NaN;
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

export function optionalEnum<T extends string>(value: unknown, field: string, allowed: readonly T[]): T | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string" || !(allowed as readonly string[]).includes(value)) {
    throw new HttpError(400, `${field} is not a supported value.`);
  }
  return value as T;
}

export function requireEnum<T extends string>(value: unknown, field: string, allowed: readonly T[]): T {
  const v = optionalEnum(value, field, allowed);
  if (v === undefined) throw new HttpError(400, `${field} is required.`);
  return v;
}

/**
 * Validates an optional array. Arrays longer than [maxItems] are rejected,
 * or trimmed to their first / last [maxItems] items when [keep] is set.
 */
export function optionalArray(
  value: unknown,
  field: string,
  maxItems: number,
  keep?: "first" | "last",
): unknown[] | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value)) throw new HttpError(400, `${field} must be a list.`);
  if (value.length <= maxItems) return value;
  if (!keep) throw new HttpError(400, `${field} can have at most ${maxItems} items.`);
  return keep === "first" ? value.slice(0, maxItems) : value.slice(-maxItems);
}

export function optionalObject(value: unknown, field: string): JsonObject | undefined {
  if (value === undefined || value === null) return undefined;
  if (!isObject(value)) throw new HttpError(400, `${field} must be an object.`);
  return value;
}

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Deep-copies arbitrary client JSON with bounded depth, keys, array length
 * and string length, sanitising every string. For context blobs (e.g. Vita's
 * health snapshot) that go into a prompt as-is.
 */
export function boundedJson(
  value: unknown,
  opts: { maxDepth: number; maxKeys: number; maxItems: number; maxString: number },
  depth = 0,
): unknown {
  if (value === null || typeof value === "boolean") return value;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string") return cleanText(value, opts.maxString, { multiline: true });
  if (depth >= opts.maxDepth) return null;
  if (Array.isArray(value)) {
    return value.slice(0, opts.maxItems).map((v) => boundedJson(v, opts, depth + 1));
  }
  if (isObject(value)) {
    const out: JsonObject = {};
    for (const [key, v] of Object.entries(value).slice(0, opts.maxKeys)) {
      const k = cleanText(key, 64);
      if (k) out[k] = boundedJson(v, opts, depth + 1);
    }
    return out;
  }
  return null;
}

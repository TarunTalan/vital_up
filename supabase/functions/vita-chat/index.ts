// Vita, the in-app AI health coach.
//
// POST { mode: "chat", messages: [{ role, text }], snapshot }
//   -> { text, bullets: string[], action: "view_diet_plan" | "update_diet_plan" | "view_analysis" | "view_stress_guide" | null,
//        planInstructions: string | null }
// POST { mode: "insights", snapshot }
//   -> { headline, stressTip, dietNote }
//
// `snapshot` is a compact summary of the user's on-device health data (meals,
// sleep, water, screen time, activity, vitals, stress estimate, profile, diet
// plan) built by the app. Numbers are computed on the device; the model only
// writes coaching text, so it must never invent figures beyond the snapshot.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { envList, extractJson, GEMINI_DEFAULT_MODELS, geminiGenerate, groqGenerate } from "../_shared/llm.ts";
import { type AiFeature, consumeDailyQuota, dailyLimit, refundDailyQuota } from "../_shared/quota.ts";
import {
  bearerToken,
  boundedJson,
  cleanText,
  handleError,
  HttpError,
  isObject,
  KB,
  LIMITS,
  optionalArray,
  readJsonBody,
  requireEnum,
  requireMethod,
} from "../_shared/validate.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/** Turns accepted as context (the app sends at most 12). */
const MAX_HISTORY = 12;
/** Longest single turn accepted (the app clips every turn to this). */
const MAX_TURN_CHARS = 2000;
/** Vita's own earlier replies (text + bullets) can run longer than a user message. */
const MAX_VITA_TURN_CHARS = MAX_TURN_CHARS;
/** Raw snapshot JSON accepted before bounding (the app's is a few KB). */
const MAX_RAW_SNAPSHOT_CHARS = 100_000;
/** Whole conversation in the prompt; oldest turns are dropped to fit. */
const MAX_TRANSCRIPT_CHARS = 12000;
const MAX_SNAPSHOT_CHARS = 12000;
const MAX_BODY_BYTES = 256 * KB;
const SNAPSHOT_BOUNDS = { maxDepth: 6, maxKeys: 60, maxItems: 60, maxString: 500 };
const ACTIONS = new Set(["view_diet_plan", "update_diet_plan", "view_analysis", "view_stress_guide"]);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

const PERSONA = `You are Vita, the friendly AI health companion inside the VitalUp app.
You coach users on diet (Indian cuisine aware), sleep, stress, hydration and activity
using ONLY the health snapshot provided. Rules:
- Be warm, concise and practical. 1-3 short sentences, optionally up to 4 short bullet points.
- Quote numbers only if they appear in the snapshot; never invent data. If data is missing, say so briefly and suggest logging it.
- Stress scores are estimates (from check-ins, wearable HRV or lifestyle signals) - never present them as a diagnosis.
- You are not a doctor. For symptoms, medication changes or anything concerning, recommend a qualified healthcare professional.
- For emergencies (chest pain, self-harm thoughts, severe symptoms) tell the user to contact local emergency services immediately.
- Respect allergies, dietary preference and health conditions from the profile.
- Stay on health and wellbeing topics; politely steer back if asked about unrelated things.`;

interface Turn {
  role: "user" | "vita";
  text: string;
}

/**
 * Validated, sanitised chat history. Oversized or malformed input is
 * rejected (400 / 413) rather than processed: at most [MAX_HISTORY] turns,
 * each an object with a known role and text of at most [MAX_TURN_CHARS].
 * User turns are then cut to the app's chat message limit, and the oldest
 * turns dropped until the transcript fits [MAX_TRANSCRIPT_CHARS].
 */
function parseHistory(value: unknown): Turn[] {
  const raw = optionalArray(value, "messages", MAX_HISTORY) ?? [];
  const turns: Turn[] = [];
  for (const m of raw) {
    if (!isObject(m)) throw new HttpError(400, "Each message must be an object.");
    const role = m.role === "user" ? "user" : m.role === "vita" || m.role === "assistant" ? "vita" : null;
    if (!role) throw new HttpError(400, "Message role is not supported.");
    if (typeof m.text !== "string") throw new HttpError(400, "Message text must be text.");
    if (m.text.length > MAX_TURN_CHARS) throw new HttpError(413, "Message is too long.");
    const text = cleanText(m.text, role === "user" ? LIMITS.chatMessage : MAX_VITA_TURN_CHARS, { multiline: true });
    if (text) turns.push({ role, text });
  }
  let total = turns.reduce((sum, t) => sum + t.text.length, 0);
  while (turns.length > 1 && total > MAX_TRANSCRIPT_CHARS) total -= turns.shift()!.text.length;
  return turns;
}

/** The app's health snapshot, bounded in depth/size and with every string sanitised. */
function snapshotJson(value: unknown): string {
  if (value !== undefined && value !== null && !isObject(value)) {
    throw new HttpError(400, "snapshot must be an object.");
  }
  if (value !== undefined && value !== null && JSON.stringify(value).length > MAX_RAW_SNAPSHOT_CHARS) {
    throw new HttpError(413, "Health summary is too large.");
  }
  const text = JSON.stringify(boundedJson(value ?? {}, SNAPSHOT_BOUNDS));
  return text.length <= MAX_SNAPSHOT_CHARS ? text : text.slice(0, MAX_SNAPSHOT_CHARS);
}

function chatPrompt(messages: Turn[], snapshot: string): string {
  const transcript = messages
    .map((m) => `${m.role === "user" ? "User" : "Vita"}: ${m.text}`)
    .join("\n");
  return `${PERSONA}

HEALTH SNAPSHOT (JSON):
${snapshot}

CONVERSATION:
${transcript}

Reply to the user's last message as Vita. Respond with ONLY valid JSON:
{
  "text": "string - main reply, plain text, may include at most one emoji",
  "bullets": ["optional short points, max 4, [] if none"],
  "action": "view_diet_plan" | "update_diet_plan" | "view_analysis" | "view_stress_guide" | null,
  "planInstructions": "string or null - only with update_diet_plan"
}
Use "action" only when it clearly helps:
- update_diet_plan: the user asked to change the diet plan in activeDietPlan
  (swap a dish, lighter dinner, more protein, no rice...) and the change is clear.
  In "text" briefly confirm what you will change. Set "planInstructions" to one
  concise instruction for the meal planner, e.g. "Replace paneer at lunch with
  chicken; keep other meals". Include relevant allergies/dietary preference from
  the profile. If the request is vague, ask one short clarifying question with
  action null instead. If there is no activeDietPlan, suggest creating one with
  view_diet_plan.
- view_diet_plan: other diet plan questions or creating a plan.
- view_analysis: overall health report.
- view_stress_guide: stress or relaxation.`;
}

function insightsPrompt(snapshot: string): string {
  return `${PERSONA}

HEALTH SNAPSHOT (JSON):
${snapshot}

Write today's personalised insights. Respond with ONLY valid JSON:
{
  "headline": "one sentence (max 140 chars) - the most useful observation across all the data",
  "stressTip": "1-2 sentences linking today's stress estimate/triggers to one concrete technique to try today",
  "dietNote": "1 sentence on why the active diet plan suits the user's current data (or a suggestion to create one if there is no plan)"
}`;
}

let serviceClient: ReturnType<typeof createClient> | null = null;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    requireMethod(req, "POST");

    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) {
      console.error("vita-chat: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
      return json({ error: "Vita is not available right now." }, 500);
    }
    // Service-role client, used both to validate the caller's JWT and for the
    // quota RPCs. Passing the token to getUser() explicitly (same as
    // scan-food) is reliable; relying on a global Authorization header with
    // an argument-less getUser() is not.
    serviceClient ??= createClient(url, serviceKey);
    const client = serviceClient;

    const token = bearerToken(req);
    if (!token) return json({ error: "Unauthorized", code: "missing_token" }, 401);

    const [authResult, bodyResult] = await Promise.allSettled([
      client.auth.getUser(token),
      readJsonBody(req, MAX_BODY_BYTES),
    ]);
    const user = authResult.status === "fulfilled" ? authResult.value.data.user : null;
    if (!user) {
      const reason = authResult.status === "fulfilled"
        ? authResult.value.error?.message
        : (authResult.reason as Error)?.message;
      console.warn(`vita-chat auth rejected: ${reason ?? "no user"}`);
      return json({ error: "Unauthorized", code: "invalid_session" }, 401);
    }
    if (bodyResult.status === "rejected") throw bodyResult.reason;
    const body = bodyResult.value;

    const mode = requireEnum(body.mode, "mode", ["chat", "insights"] as const);
    const snapshotText = snapshotJson(body.snapshot);
    const history = mode === "chat" ? parseHistory(body.messages) : [];
    if (mode === "chat" && (history.length === 0 || history[history.length - 1].role !== "user")) {
      return json({ error: "messages must end with a user message" }, 400);
    }

    // Per-user daily fair-use cap: all users share one free-tier LLM quota.
    const feature: AiFeature = mode === "chat" ? "vita_chat" : "vita_insights";
    const limit = mode === "chat"
      ? dailyLimit("VITA_CHAT_DAILY_LIMIT", 40)
      : dailyLimit("VITA_INSIGHTS_DAILY_LIMIT", 6);
    const quota = await consumeDailyQuota(client, user.id, feature, limit);
    if (!quota.allowed) return json({ error: "Daily Vita limit reached", code: "daily_limit", limit }, 429);
    const refund = () => refundDailyQuota(client, user.id, feature);

    const prompt = mode === "chat" ? chatPrompt(history, snapshotText) : insightsPrompt(snapshotText);
    const geminiKey = Deno.env.get("VITA_GEMINI_API_KEY") ?? Deno.env.get("FOOD_RECOMMEND_GEMINI_API_KEY");
    const groqKey = Deno.env.get("VITA_GROQ_API_KEY") ?? Deno.env.get("FOOD_RECOMMEND_GROQ_API_KEY");
    const geminiModels = envList("VITA_GEMINI_MODELS", GEMINI_DEFAULT_MODELS);
    const groqModels = envList("VITA_GROQ_MODELS", ["llama-3.3-70b-versatile", "openai/gpt-oss-120b"]);

    let raw = "";
    try {
      try {
        if (!geminiKey) throw new Error("Gemini key is not set");
        raw = await geminiGenerate(geminiKey, [{ text: prompt }], {
          models: geminiModels,
          signal: AbortSignal.timeout(20000),
          json: true,
          temperature: 0.6,
          maxOutputTokens: 1024,
        });
      } catch (geminiErr) {
        if (!groqKey) throw geminiErr;
        console.error("Gemini failed, falling back to Groq:", (geminiErr as Error).message);
        raw = await groqGenerate(groqKey, prompt, {
          models: groqModels,
          capability: "text",
          signal: AbortSignal.timeout(15000),
          json: true,
          temperature: 0.6,
          maxTokens: 1024,
        });
      }

      const parsed = extractJson(raw);
      if (!isObject(parsed)) throw new Error("Model output is not a JSON object");
      if (mode === "chat") {
        const text = cleanText(parsed.text, 1200, { multiline: true });
        if (!text) throw new Error("Empty reply");
        const bullets = Array.isArray(parsed.bullets)
          ? parsed.bullets.map((b: unknown) => cleanText(b, 200)).filter(Boolean).slice(0, 4)
          : [];
        let action = typeof parsed.action === "string" && ACTIONS.has(parsed.action) ? parsed.action : null;
        const planInstructions = action === "update_diet_plan" ? cleanText(parsed.planInstructions, LIMITS.note) : "";
        // An update without instructions would only regenerate at random.
        if (action === "update_diet_plan" && !planInstructions) action = "view_diet_plan";
        return json({ text, bullets, action, planInstructions: planInstructions || null });
      }

      const headline = cleanText(parsed.headline, 200);
      const stressTip = cleanText(parsed.stressTip, 400);
      const dietNote = cleanText(parsed.dietNote, 400);
      if (!headline && !stressTip && !dietNote) throw new Error("Empty insights");
      return json({ headline, stressTip, dietNote });
    } catch (e) {
      console.error(`vita-chat ${mode} failed:`, e, raw.slice(0, 300));
      await refund();
      return json({ error: "Vita couldn't respond right now." }, 502);
    }
  } catch (error) {
    return handleError(error, "vita-chat", corsHeaders);
  }
});

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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_HISTORY = 12;
const MAX_MESSAGE_CHARS = 1500;
const MAX_SNAPSHOT_CHARS = 12000;
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

function clip(text: unknown, max: number): string {
  return String(text ?? "").slice(0, max);
}

function chatPrompt(messages: { role: string; text: string }[], snapshot: string): string {
  const transcript = messages
    .map((m) => `${m.role === "user" ? "User" : "Vita"}: ${clip(m.text, MAX_MESSAGE_CHARS)}`)
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

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // Service-role client, used both to validate the caller's JWT and for the
    // quota RPCs. Passing the token to getUser() explicitly (same as
    // scan-food) is reliable; relying on a global Authorization header with
    // an argument-less getUser() is not.
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length) : "";
    if (!token) return json({ error: "Unauthorized", code: "missing_token" }, 401);

    const [authResult, bodyResult] = await Promise.allSettled([serviceClient.auth.getUser(token), req.json()]);
    const user = authResult.status === "fulfilled" ? authResult.value.data.user : null;
    if (!user) {
      const reason = authResult.status === "fulfilled"
        ? authResult.value.error?.message
        : (authResult.reason as Error)?.message;
      console.warn(`vita-chat auth rejected: ${reason ?? "no user"}`);
      return json({ error: "Unauthorized", code: "invalid_session" }, 401);
    }
    if (bodyResult.status === "rejected") return json({ error: "Invalid JSON body" }, 400);

    const { mode, messages, snapshot } = bodyResult.value ?? {};
    if (mode !== "chat" && mode !== "insights") return json({ error: "mode must be chat or insights" }, 400);

    const snapshotText = clip(JSON.stringify(snapshot ?? {}), MAX_SNAPSHOT_CHARS);
    const history: { role: string; text: string }[] = Array.isArray(messages)
      ? messages
        .filter((m) => m && typeof m.text === "string" && m.text.trim().length > 0)
        .slice(-MAX_HISTORY)
      : [];
    if (mode === "chat" && (history.length === 0 || history[history.length - 1].role !== "user")) {
      return json({ error: "messages must end with a user message" }, 400);
    }

    // Per-user daily fair-use cap: all users share one free-tier LLM quota.
    const feature: AiFeature = mode === "chat" ? "vita_chat" : "vita_insights";
    const limit = mode === "chat"
      ? dailyLimit("VITA_CHAT_DAILY_LIMIT", 40)
      : dailyLimit("VITA_INSIGHTS_DAILY_LIMIT", 6);
    const quota = await consumeDailyQuota(serviceClient, user.id, feature, limit);
    if (!quota.allowed) return json({ error: "Daily Vita limit reached", code: "daily_limit", limit }, 429);
    const refund = () => refundDailyQuota(serviceClient, user.id, feature);

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

      // deno-lint-ignore no-explicit-any
      const parsed = extractJson(raw) as any;
      if (mode === "chat") {
        const text = clip(parsed?.text, 1200).trim();
        if (!text) throw new Error("Empty reply");
        const bullets = Array.isArray(parsed?.bullets)
          ? parsed.bullets.map((b: unknown) => clip(b, 200).trim()).filter(Boolean).slice(0, 4)
          : [];
        let action = ACTIONS.has(parsed?.action) ? parsed.action : null;
        const planInstructions = action === "update_diet_plan" ? clip(parsed?.planInstructions, 600).trim() : "";
        // An update without instructions would only regenerate at random.
        if (action === "update_diet_plan" && !planInstructions) action = "view_diet_plan";
        return json({ text, bullets, action, planInstructions: planInstructions || null });
      }

      const headline = clip(parsed?.headline, 200).trim();
      const stressTip = clip(parsed?.stressTip, 400).trim();
      const dietNote = clip(parsed?.dietNote, 400).trim();
      if (!headline && !stressTip && !dietNote) throw new Error("Empty insights");
      return json({ headline, stressTip, dietNote });
    } catch (e) {
      console.error(`vita-chat ${mode} failed:`, e, raw.slice(0, 300));
      await refund();
      return json({ error: "Vita couldn't respond right now." }, 502);
    }
  } catch (error) {
    return json({ error: (error as Error).message }, 400);
  }
});

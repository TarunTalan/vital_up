// Generates a one-day Indian meal plan for a nutrition target.
//
// POST { target: { calories, protein, carbs, fat },
//        preferences: { dietaryType?, mealsPerDay?, region?, allergies?, avoid?, recentItems? },
//        instructions?, basePlan?: { meals: [{ name, items, calories }] } }
//   -> { meals: [{ name, items, calories, protein, carbs, fat }],
//        totalCalories, totalProtein, totalCarbs, totalFat, approximate? }
// Errors: 400 invalid input, 401 not signed in, 405, 413, 415,
//         422 no valid / safe plan, 429 daily limit (code: daily_limit), 500.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { envList, extractJson, GEMINI_DEFAULT_MODELS, geminiGenerate, groqGenerate } from "../_shared/llm.ts";
import { consumeDailyQuota, dailyLimit, refundDailyQuota } from "../_shared/quota.ts";
import {
  bearerToken,
  clampNumber,
  cleanText,
  handleError,
  HttpError,
  isObject,
  type JsonObject,
  KB,
  LIMITS,
  optionalArray,
  optionalEnum,
  optionalNumber,
  optionalObject,
  optionalText,
  RANGES,
  readJsonBody,
  requireMethod,
  requireNumber,
} from "../_shared/validate.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

const MAX_BODY_BYTES = 64 * KB;
const MAX_MEALS = 8;
const MAX_ITEMS_PER_MEAL = 10;
const MAX_RECENT_ITEMS = 40;
/** Options offered by the app's preferences page, plus the prompt's own wording. */
const DIETARY_TYPES = ["Any", "Vegetarian", "Vegan", "Eggetarian", "Pescatarian", "Non-Vegetarian"] as const;

interface Target {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

interface Preferences {
  dietaryType?: string;
  region?: string;
  allergies?: string;
  avoid?: string;
  mealsPerDay: number;
  recentItems: string[];
}

interface Meal {
  name: string;
  items: string[];
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

function parseTarget(value: unknown): Target {
  if (!isObject(value)) throw new HttpError(400, "target and preferences are required");
  const grams = { min: RANGES.grams.min, max: RANGES.grams.max };
  return {
    calories: requireNumber(value.calories, "target.calories", { min: 1, max: RANGES.calories.max }),
    protein: requireNumber(value.protein, "target.protein", grams),
    carbs: requireNumber(value.carbs, "target.carbs", grams),
    fat: requireNumber(value.fat, "target.fat", grams),
  };
}

function textList(value: unknown, field: string, maxItems: number, maxChars: number): string[] {
  const list = optionalArray(value, field, maxItems, "first") ?? [];
  return list.map((v) => cleanText(v, maxChars)).filter(Boolean);
}

function parsePreferences(value: unknown): Preferences {
  const p = optionalObject(value, "preferences");
  if (!p) throw new HttpError(400, "target and preferences are required");
  // Case-insensitive match onto the known options; anything else is refused.
  const dietLower = typeof p.dietaryType === "string" ? p.dietaryType.trim().toLowerCase() : null;
  const rawDiet = dietLower === null
    ? p.dietaryType
    : dietLower === ""
    ? undefined
    : DIETARY_TYPES.find((d) => d.toLowerCase() === dietLower) ?? p.dietaryType;
  return {
    dietaryType: optionalEnum(rawDiet, "preferences.dietaryType", DIETARY_TYPES),
    region: optionalText(p.region, "preferences.region", { max: LIMITS.city, clip: true }),
    allergies: optionalText(p.allergies, "preferences.allergies", { max: LIMITS.note, clip: true }),
    avoid: optionalText(p.avoid, "preferences.avoid", { max: LIMITS.note, clip: true }),
    mealsPerDay: optionalNumber(p.mealsPerDay, "preferences.mealsPerDay", { min: 1, max: MAX_MEALS, integer: true }) ?? 4,
    recentItems: textList(p.recentItems, "preferences.recentItems", MAX_RECENT_ITEMS, LIMITS.shortText),
  };
}

function parseBaseMeals(value: unknown): { name: string; items: string[]; calories: number }[] {
  if (!isObject(value)) return [];
  const meals = optionalArray(value.meals, "basePlan.meals", MAX_MEALS, "first") ?? [];
  return meals.filter(isObject).map((m: JsonObject) => ({
    name: cleanText(m.name, LIMITS.shortText) || "Meal",
    items: Array.isArray(m.items)
      ? m.items.slice(0, MAX_ITEMS_PER_MEAL).map((i) => cleanText(i, LIMITS.shortText)).filter(Boolean)
      : [],
    calories: Math.round(clampNumber(m.calories, 0, RANGES.calories.max)),
  }));
}

/**
 * Validates the model's plan: at least one meal, strings sanitised and
 * clipped, numbers clamped and rounded. Totals the model left out (or got
 * wrong type) are summed from the meals. Throws when there's nothing usable.
 */
function normalizePlan(raw: unknown): { meals: Meal[]; totalCalories: number; totalProtein: number; totalCarbs: number; totalFat: number } {
  if (!isObject(raw) || !Array.isArray(raw.meals)) throw new Error("Plan has no meals array");
  const cal = (v: unknown) => Math.round(clampNumber(v, 0, RANGES.calories.max));
  const g = (v: unknown) => Math.round(clampNumber(v, 0, RANGES.grams.max));
  const meals: Meal[] = raw.meals
    .filter(isObject)
    .slice(0, MAX_MEALS)
    .map((m: JsonObject, i: number) => ({
      name: cleanText(m.name, 40) || `Meal ${i + 1}`,
      items: Array.isArray(m.items)
        ? m.items.slice(0, MAX_ITEMS_PER_MEAL).map((it) => cleanText(it, LIMITS.shortText)).filter(Boolean)
        : [],
      calories: cal(m.calories),
      protein: g(m.protein),
      carbs: g(m.carbs),
      fat: g(m.fat),
    }))
    .filter((m) => m.items.length > 0);
  if (meals.length === 0) throw new Error("Plan has no usable meals");
  const sum = (key: "calories" | "protein" | "carbs" | "fat") => meals.reduce((s, m) => s + m[key], 0);
  const total = (v: unknown, key: "calories" | "protein" | "carbs" | "fat", max: number) =>
    typeof v === "number" && Number.isFinite(v) && v > 0 ? Math.round(Math.min(v, max)) : sum(key);
  return {
    meals,
    totalCalories: total(raw.totalCalories, "calories", RANGES.calories.max),
    totalProtein: total(raw.totalProtein, "protein", RANGES.grams.max),
    totalCarbs: total(raw.totalCarbs, "carbs", RANGES.grams.max),
    totalFat: total(raw.totalFat, "fat", RANGES.grams.max),
  };
}

let serviceClient: ReturnType<typeof createClient> | null = null;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    requireMethod(req, "POST");

    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) {
      console.error("generate-diet-plan: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
      return json({ error: "Diet plans are not available right now." }, 500);
    }
    // Service-role client, used both to validate the caller's JWT and for the
    // quota RPCs. Passing the token to getUser() explicitly (same as
    // scan-food) is reliable; relying on a global Authorization header with
    // an argument-less getUser() is not.
    serviceClient ??= createClient(url, serviceKey);
    const client = serviceClient;

    console.time("TotalExecution");

    const token = bearerToken(req);

    console.time("SetupAndAuth");
    const [authResult, bodyResult] = await Promise.allSettled([
      token ? client.auth.getUser(token) : Promise.reject(new Error("missing bearer token")),
      readJsonBody(req, MAX_BODY_BYTES),
    ]);
    console.timeEnd("SetupAndAuth");

    // Plans cost a paid-for / quota-limited LLM call, so only signed-in users
    // may generate them.
    const user = authResult.status === "fulfilled" ? authResult.value.data.user : null;
    if (!user) {
      const reason = authResult.status === "fulfilled"
        ? authResult.value.error?.message
        : (authResult.reason as Error)?.message;
      console.warn(`generate-diet-plan auth rejected: ${reason ?? "no user"}`);
      console.timeEnd("TotalExecution");
      return json({ error: "Unauthorized" }, 401);
    }

    if (bodyResult.status === "rejected") {
      console.timeEnd("TotalExecution");
      throw bodyResult.reason;
    }
    const body = bodyResult.value;

    const target = parseTarget(body.target);
    const preferences = parsePreferences(body.preferences);
    // Optional tweak request (from Vita or the plan screen): a free-text change
    // applied to the plan the user already has. Cut rather than refused: Vita
    // writes these, capped at the same length.
    const tweak = optionalText(body.instructions, "instructions", { max: LIMITS.note, clip: true }) ?? "";
    const baseMeals = tweak ? parseBaseMeals(body.basePlan) : [];

    // Per-user daily fair-use cap: all users share one free-tier LLM quota.
    const quota = await consumeDailyQuota(client, user.id, "diet_plan", dailyLimit("DIET_PLAN_DAILY_LIMIT", 15));
    if (!quota.allowed) {
      console.timeEnd("TotalExecution");
      return json({ error: "Daily diet plan limit reached", code: "daily_limit", limit: quota.limit }, 429);
    }
    const refundQuota = () => refundDailyQuota(client, user.id, "diet_plan");

    // Used to force divergence between calls with an otherwise-identical prompt.
    const varietySeed = crypto.randomUUID();

    const baseMealLines = baseMeals
      .map((m) => `- ${m.name} (${m.calories || "?"} kcal): ${m.items.join(", ")}`)
      .join("\n");
    const tweakSection = tweak
      ? `

    TWEAK REQUEST (highest priority after dietary type, allergies and avoid list):
    The user wants to change their current plan as follows: "${tweak}"
    ${baseMealLines ? `Current plan:\n${baseMealLines}\n    Keep meals and dishes the request does not mention as close to the current plan as possible; change only what is needed.` : ""}
    If the request asks for more/less calories or a macro, adjust the totals accordingly; otherwise match the target.
    The VARIETY rules below do not apply to dishes kept from the current plan.`
      : "";

    const prompt = `You are a meal-planning assistant specializing in Indian cuisine.
    Given a daily nutrition target and dietary constraints, generate a one-day
    meal plan using common Indian foods and meal patterns.

    Target: ${target.calories} kcal, ${target.protein}g protein, ${target.carbs}g carbs, ${target.fat}g fat
    Dietary type: ${preferences.dietaryType || "Any"}
    Cuisine region: ${preferences.region || "Any Indian (mix of North/South/West/East as appropriate)"}
    Allergies (strict exclude): ${preferences.allergies || "None"}
    Avoid: ${preferences.avoid || "None"}
    Number of meals: ${preferences.mealsPerDay || 4}

    Recently used items (do not reuse any of these dishes in this response): ${preferences.recentItems?.join(", ") || "None"}
    Variety seed (use this to intentionally pick a different combination of dishes than you would by default; do not mention it in the output): ${varietySeed}${tweakSection}

    Use realistic Indian dishes and meal structures appropriate to the time of day
    (e.g. poha/idli/paratha/upma for breakfast; dal/sabzi/roti/rice/curry for lunch
    and dinner; sprouts/fruit/nuts/chaas for snacks). Reflect regional variety
    based on the cuisine region if specified. Use standard Indian household
    portion sizes (e.g. "2 Roti", "1 Bowl Dal", "1 Cup Rice") rather than
    Western units like slices or cups of cereal.

    Respond with ONLY valid JSON, no markdown fences, no preamble, matching
    exactly this schema:

    {
      "meals": [
        {
          "name": "string (e.g. Breakfast)",
          "items": ["string (compact Indian food name with portion, max 3-4 words)", "string"],
          "calories": number,
          "protein": number,
          "carbs": number,
          "fat": number
        }
      ],
      "totalCalories": number,
      "totalProtein": number,
      "totalCarbs": number,
      "totalFat": number
    }

    Meal calories/macros must sum to within 5% of the target. Do not include
    any allergen from the exclude list under any circumstance. Provide extremely
    brief item names with portion size (e.g. "2 Roti", "1 Bowl Palak Dal",
    "1 Cup Curd") to reduce response size.

    IMPORTANT CONSTRAINTS:

    DIETARY TYPE ENFORCEMENT:
    - Vegan: absolutely no dairy products (milk, curd, paneer, cheese, butter, ghee, yogurt, lassi, buttermilk).
    - Vegetarian: no meat, fish, seafood, eggs.
    - Eggetarian: eggs allowed, meat/fish not allowed.
    - Non-Vegetarian: unrestricted unless otherwise excluded.

    VARIETY:
    - Avoid repetitive meal selections.
    - Do not default to Poha or Idli for breakfast unless the variety seed clearly favors it.
    - Prefer different breakfast categories whenever multiple valid options exist.
    - Generate regionally appropriate variety.

    VALIDATION:
    Before responding, verify every food item complies with dietary type, allergies, avoid list, and meal timing.
    If any item violates these rules, regenerate internally before producing JSON.`;

    const geminiKey = Deno.env.get("FOOD_RECOMMEND_GEMINI_API_KEY");
    const groqKey = Deno.env.get("FOOD_RECOMMEND_GROQ_API_KEY");
    // Model lists self-heal when a model is retired (see _shared/llm.ts) and
    // can be overridden without a deploy via these secrets.
    const geminiModels = envList("DIET_PLAN_GEMINI_MODELS", GEMINI_DEFAULT_MODELS);
    const groqModels = envList("DIET_PLAN_GROQ_MODELS", ["llama-3.3-70b-versatile", "openai/gpt-oss-120b"]);
    const allergiesList = (preferences.allergies ?? "")
      .split(",")
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean);
    let resultJson: (ReturnType<typeof normalizePlan> & { approximate?: boolean }) | null = null;

    for (let attempt = 1; attempt <= 2; attempt++) {
      let usedProvider = "gemini";
      try {
        let aiResponseText = "";

        const timeoutMs = attempt === 1 ? 20000 : 15000;
        const promptText = prompt + (attempt > 1 ? "\n\nCRITICAL: RETURN ONLY JSON, NO MARKDOWN." : "");

        console.time(`GeminiCall_Attempt${attempt}`);
        try {
          if (!geminiKey) throw new Error("FOOD_RECOMMEND_GEMINI_API_KEY is not set");
          aiResponseText = await geminiGenerate(geminiKey, [{ text: promptText }], {
            models: geminiModels,
            signal: AbortSignal.timeout(timeoutMs),
            json: true,
            temperature: 0.9,
            topP: 0.95,
            maxOutputTokens: 8192,
          });
        } catch (geminiErr) {
          if (!groqKey) throw geminiErr;
          usedProvider = "groq";
          console.error("Gemini failed, falling back to Groq:", (geminiErr as Error).message);
          aiResponseText = await groqGenerate(groqKey, promptText, {
            models: groqModels,
            capability: "text",
            signal: AbortSignal.timeout(timeoutMs),
            json: true,
            temperature: 0.9,
            maxTokens: 4096,
          });
        }
        console.timeEnd(`GeminiCall_Attempt${attempt}`);

        const plan: ReturnType<typeof normalizePlan> & { approximate?: boolean } = normalizePlan(
          extractJson(aiResponseText),
        );
        console.log(`generate-diet-plan served by ${usedProvider} (attempt ${attempt})`);

        const diffPercent = Math.abs(plan.totalCalories - target.calories) / target.calories;
        // A tweak may legitimately move calories ("lighter dinner").
        if (diffPercent > (tweak ? 0.25 : 0.1)) {
          if (attempt === 1) throw new Error("Macros off by more than 10%");
          else plan.approximate = true;
        }

        if (allergiesList.length > 0) {
          const containsAllergen = plan.meals.some((meal) =>
            meal.items.some((item) => {
              const itemLower = item.toLowerCase();
              return allergiesList.some((al) => itemLower.includes(al));
            })
          );
          if (containsAllergen) {
            if (attempt === 1) throw new Error("Contains allergen");
            await refundQuota();
            console.timeEnd("TotalExecution");
            return json({ error: "Could not generate a safe meal plan matching your allergies. Please try again." }, 422);
          }
        }

        resultJson = plan;
        break;
      } catch (e) {
        console.error(`Attempt ${attempt} failed:`, e);
        if (attempt === 2) {
          console.timeEnd("TotalExecution");
          await refundQuota();
          return json({ error: "Failed to generate valid plan." }, 422);
        }
      }
    }

    console.timeEnd("TotalExecution");
    return json(resultJson);
  } catch (error) {
    return handleError(error, "generate-diet-plan", corsHeaders);
  }
});

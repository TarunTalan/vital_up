import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { envList, extractJson, GEMINI_DEFAULT_MODELS, geminiGenerate, groqGenerate } from "../_shared/llm.ts";
import { consumeDailyQuota, dailyLimit, refundDailyQuota } from "../_shared/quota.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Service-role client, used both to validate the caller's JWT and for the
    // quota RPCs. Passing the token to getUser() explicitly (same as
    // scan-food) is reliable; relying on a global Authorization header with
    // an argument-less getUser() is not.
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    console.time("TotalExecution");

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length) : "";

    console.time("SetupAndAuth");
    const [authResult, bodyResult] = await Promise.allSettled([
      token ? serviceClient.auth.getUser(token) : Promise.reject(new Error("missing bearer token")),
      req.json()
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
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (bodyResult.status === "rejected") {
      console.timeEnd("TotalExecution");
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { target, preferences, instructions, basePlan } = bodyResult.value;
    // Optional tweak request (from Vita or the plan screen): a free-text change
    // applied to the plan the user already has.
    const tweak = typeof instructions === "string" ? instructions.trim().slice(0, 600) : "";
    const baseMeals: { name?: unknown; items?: unknown; calories?: unknown }[] =
      tweak && Array.isArray(basePlan?.meals) ? basePlan.meals.slice(0, 8) : [];
    if (!target?.calories || !preferences) {
      console.timeEnd("TotalExecution");
      return new Response(JSON.stringify({ error: "target and preferences are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Per-user daily fair-use cap: all users share one free-tier LLM quota.
    const quota = await consumeDailyQuota(serviceClient, user.id, "diet_plan", dailyLimit("DIET_PLAN_DAILY_LIMIT", 15));
    if (!quota.allowed) {
      console.timeEnd("TotalExecution");
      return new Response(JSON.stringify({ error: "Daily diet plan limit reached", code: "daily_limit", limit: quota.limit }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const refundQuota = () => refundDailyQuota(serviceClient, user.id, "diet_plan");

    // Used to force divergence between calls with an otherwise-identical prompt.
    const varietySeed = crypto.randomUUID();

    const baseMealLines = baseMeals
      .map((m) => `- ${String(m.name ?? "Meal")} (${Number(m.calories) || "?"} kcal): ${
        Array.isArray(m.items) ? m.items.map(String).join(", ") : ""
      }`)
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
    let resultJson = null;

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

        resultJson = extractJson(aiResponseText) as any;
        resultJson._debugProvider = usedProvider;

        const tCal = resultJson.totalCalories;
        const targetCal = target.calories;
        const diffPercent = Math.abs(tCal - targetCal) / targetCal;
        // A tweak may legitimately move calories ("lighter dinner").
        if (diffPercent > (tweak ? 0.25 : 0.1)) {
          if (attempt === 1) throw new Error("Macros off by more than 10%");
          else resultJson.approximate = true;
        }

        const allergiesStr = preferences.allergies || "";
        if (allergiesStr.length > 0) {
          const allergiesList = allergiesStr.split(",").map((s: string) => s.trim().toLowerCase());
          let containsAllergen = false;
          for (const meal of resultJson.meals || []) {
            for (const item of meal.items || []) {
              const itemLower = item.toLowerCase();
              if (allergiesList.some((al: string) => itemLower.includes(al))) {
                containsAllergen = true;
                break;
              }
            }
            if (containsAllergen) break;
          }
          if (containsAllergen) {
             if (attempt === 1) throw new Error("Contains allergen");
             await refundQuota();
             return new Response(JSON.stringify({ error: "Could not generate a safe meal plan matching your allergies. Please try again." }), { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } });
          }
        }

        break;
      } catch (e: any) {
        console.timeEnd(`GeminiCall_Attempt${attempt}`);
        console.error(`Attempt ${attempt} failed:`, e);
        if (attempt === 2) {
          console.timeEnd("TotalExecution");
          await refundQuota();
          return new Response(JSON.stringify({
            error: "Failed to generate valid plan.",
            details: e.message
          }), {
            status: 422,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }
    }

    console.timeEnd("TotalExecution");
    return new Response(JSON.stringify(resultJson), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.timeEnd("TotalExecution");
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
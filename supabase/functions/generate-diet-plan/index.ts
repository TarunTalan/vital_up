import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const authHeader = req.headers.get("Authorization") || "";
    console.log("--- DEBUG INFO START ---");
    console.time("TotalExecution");
    console.log("Auth Header (first 20 chars):", authHeader.substring(0, 20));
    console.log("Has SUPABASE_URL:", !!Deno.env.get("SUPABASE_URL"));
    console.log("Has SUPABASE_ANON_KEY:", !!Deno.env.get("SUPABASE_ANON_KEY"));
    console.log("--- DEBUG INFO END ---");

    console.time("SetupAndAuth");
    const [authResult, bodyResult] = await Promise.allSettled([
      supabaseClient.auth.getUser(),
      req.json()
    ]);
    console.timeEnd("SetupAndAuth");

    // BYPASS AUTHORIZATION FOR TESTING
    // if (authResult.status === "rejected" || (authResult.status === "fulfilled" && (authResult.value.error || !authResult.value.data.user))) {
    //   console.timeEnd("TotalExecution");
    //   return new Response(JSON.stringify({ error: "Unauthorized" }), {
    //     status: 401,
    //     headers: { ...corsHeaders, "Content-Type": "application/json" },
    //   });
    // }

    if (bodyResult.status === "rejected") {
      console.timeEnd("TotalExecution");
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { target, preferences } = bodyResult.value;

    // Used to force divergence between calls with an otherwise-identical prompt.
    const varietySeed = crypto.randomUUID();

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
    Variety seed (use this to intentionally pick a different combination of dishes than you would by default; do not mention it in the output): ${varietySeed}

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
    let resultJson = null;

    for (let attempt = 1; attempt <= 2; attempt++) {
      let usedProvider = "gemini";
      try {
        let aiResponseText = "";

        const timeoutMs = attempt === 1 ? 20000 : 15000;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

        console.time(`GeminiCall_Attempt${attempt}`);
        const geminiRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": geminiKey ?? "",
            },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt + (attempt > 1 ? "\n\nCRITICAL: RETURN ONLY JSON, NO MARKDOWN." : "") }] }],
              generationConfig: {
                responseMimeType: "application/json",
                temperature: 0.9,
                topP: 0.95
              }
            }),
            signal: controller.signal
          }
        );
        clearTimeout(timeoutId);

        console.log(`Gemini attempt ${attempt} status:`, geminiRes.status);

        const shouldFallback = (geminiRes.status === 429 || geminiRes.status === 404 || geminiRes.status >= 500) && !!groqKey;

        if (shouldFallback) {
          usedProvider = "groq";
          const geminiErrBody = await geminiRes.clone().json().catch(() => null);
          console.error(`Gemini failed (status ${geminiRes.status}), falling back to Groq. Error:`, geminiErrBody?.error?.message);

          const groqController = new AbortController();
          const groqTimeoutId = setTimeout(() => groqController.abort(), timeoutMs);
          const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${groqKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "llama-3.3-70b-versatile",
              messages: [{ role: "user", content: prompt + (attempt > 1 ? "\n\nCRITICAL: RETURN ONLY JSON, NO MARKDOWN." : "") }],
              temperature: 0.9,
            }),
            signal: groqController.signal
          });
          clearTimeout(groqTimeoutId);
          const groqData = await groqRes.json();
          if (!groqRes.ok) throw new Error(groqData.error?.message || "Groq Error");
          aiResponseText = groqData.choices?.[0]?.message?.content || "";
        } else {
          const geminiData = await geminiRes.json();
          if (!geminiRes.ok) throw new Error(geminiData.error?.message || "Gemini Error");
          aiResponseText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "";
        }
        console.timeEnd(`GeminiCall_Attempt${attempt}`);

        let cleanJsonStr = aiResponseText.trim();
        if (cleanJsonStr.startsWith("```json")) {
          cleanJsonStr = cleanJsonStr.replace(/^```json/, "").replace(/```$/, "").trim();
        } else if (cleanJsonStr.startsWith("```")) {
          cleanJsonStr = cleanJsonStr.replace(/^```/, "").replace(/```$/, "").trim();
        }

        resultJson = JSON.parse(cleanJsonStr);
        resultJson._debugProvider = usedProvider;

        const tCal = resultJson.totalCalories;
        const targetCal = target.calories;
        const diffPercent = Math.abs(tCal - targetCal) / targetCal;
        if (diffPercent > 0.1) {
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
             else return new Response(JSON.stringify({ error: "Could not generate a safe meal plan matching your allergies. Please try again." }), { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } });
          }
        }

        break;
      } catch (e: any) {
        console.timeEnd(`GeminiCall_Attempt${attempt}`);
        console.error(`Attempt ${attempt} failed:`, e);
        if (attempt === 2) {
          console.timeEnd("TotalExecution");
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
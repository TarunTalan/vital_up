import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface VisionResponse {
  candidateName: string;
  estimatedPortionDescription: string;
  confidenceHint: number;
}

interface VisionProvider {
  recognize(imageBase64: string): Promise<VisionResponse[]>;
}

// Every response from this function must be JSON, and clients (including the
// Supabase Dart SDK) only auto-decode the body into a Map when the
// Content-Type header says so. Without it, callers get a raw string and
// crash on `response.data as Map<String, dynamic>`. Route every response
// through this helper so that header is never missed.
function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

class GeminiVisionProvider implements VisionProvider {
  private apiKey: string;
  private model: string = 'gemini-2.0-flash';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async recognize(imageBase64: string): Promise<VisionResponse[]> {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: this.getPrompt(),
              inline_data: {
                mime_type: 'image/jpeg',
                data: imageBase64,
              },
            }],
          }],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 1024,
            responseMimeType: 'application/json',
          },
        }),
      }
    );

    if (!response.ok) {
      const error = await response.text();
      if (response.status === 429) {
        throw new Error('RATE_LIMIT_EXCEEDED');
      }
      throw new Error(`Gemini API error: ${error}`);
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      throw new Error('No response from Gemini');
    }

    try {
      const parsed = JSON.parse(text);
      return this.validateAndNormalize(parsed);
    } catch (e) {
      throw new Error('Invalid JSON response from Gemini');
    }
  }

  private getPrompt(): string {
    return `Analyze this food image and return ONLY a JSON array with this exact structure:
[
  {
    "candidateName": "specific food name (e.g., 'grilled chicken breast')",
    "estimatedPortionDescription": "portion description (e.g., '1 medium piece, ~150g')",
    "confidenceHint": 0.0-1.0
  }
]
Rules:
- Return 1-3 most likely food items
- Be specific about food type and preparation
- Estimate portion size visually
- Do NOT include calorie or macro numbers
- Return ONLY the JSON array, no other text`;
  }

  private validateAndNormalize(data: any): VisionResponse[] {
    if (!Array.isArray(data)) {
      throw new Error('Response must be an array');
    }

    return data.map(item => ({
      candidateName: item.candidateName || 'Unknown food',
      estimatedPortionDescription: item.estimatedPortionDescription || '1 serving',
      confidenceHint: Math.min(1, Math.max(0, item.confidenceHint || 0.5)),
    }));
  }
}

class GroqVisionProvider implements VisionProvider {
  private apiKey: string;
  private model: string = 'meta-llama/llama-4-scout-17b-16e-instruct';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async recognize(imageBase64: string): Promise<VisionResponse[]> {
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.model,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'text',
              text: this.getPrompt(),
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${imageBase64}`,
              },
            },
          ],
        }],
        temperature: 0.1,
        max_tokens: 1024,
        response_format: { type: 'json_object' },
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      if (response.status === 429) {
        throw new Error('RATE_LIMIT_EXCEEDED');
      }
      throw new Error(`Groq API error: ${error}`);
    }

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content;

    if (!text) {
      throw new Error('No response from Groq');
    }

    try {
      const parsed = JSON.parse(text);
      return this.validateAndNormalize(parsed);
    } catch (e) {
      throw new Error('Invalid JSON response from Groq');
    }
  }

  private getPrompt(): string {
    return `Analyze this food image and return ONLY a JSON object with this exact structure:
{
  "items": [
    {
      "candidateName": "specific food name (e.g., 'grilled chicken breast')",
      "estimatedPortionDescription": "portion description (e.g., '1 medium piece, ~150g')",
      "confidenceHint": 0.0-1.0
    }
  ]
}
Rules:
- Return 1-3 most likely food items
- Be specific about food type and preparation
- Estimate portion size visually
- Do NOT include calorie or macro numbers
- Return ONLY the JSON object, no other text`;
  }

  private validateAndNormalize(data: any): VisionResponse[] {
    const items = data.items || [];
    if (!Array.isArray(items)) {
      throw new Error('Response must contain an items array');
    }

    return items.map(item => ({
      candidateName: item.candidateName || 'Unknown food',
      estimatedPortionDescription: item.estimatedPortionDescription || '1 serving',
      confidenceHint: Math.min(1, Math.max(0, item.confidenceHint || 0.5)),
    }));
  }
}

class VisionProviderChain {
  private providers: VisionProvider[];

  constructor(geminiKey: string, groqKey: string) {
    this.providers = [
      new GeminiVisionProvider(geminiKey),
      new GroqVisionProvider(groqKey),
    ];
  }

  async recognize(imageBase64: string): Promise<{ results: VisionResponse[]; servedBy: string }> {
    const errors: string[] = [];

    for (const provider of this.providers) {
      try {
        const results = await provider.recognize(imageBase64);
        return {
          results,
          servedBy: provider instanceof GeminiVisionProvider ? 'gemini' : 'groq',
        };
      } catch (error) {
        const reason = `${provider.constructor.name}: ${(error as Error).message}`;
        errors.push(reason);
        console.error(reason);
        // Continue to next provider
      }
    }

    throw new Error(`All vision providers failed | ${errors.join(' || ')}`);
  }
}

async function searchUSDA(query: string, apiKey: string): Promise<any[]> {
  const response = await fetch(
    `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(query)}&api_key=${apiKey}&pageSize=5`
  );

  if (!response.ok) {
    throw new Error('USDA API error');
  }

  const data = await response.json();
  return data.foods || [];
}

async function getUSDANutrition(fdcId: string, apiKey: string): Promise<any> {
  const response = await fetch(
    `https://api.nal.usda.gov/fdc/v1/food/${fdcId}?api_key=${apiKey}`
  );

  if (!response.ok) {
    throw new Error('USDA API error');
  }

  return response.json();
}

async function logRecognition(
  supabase: any,
  userId: string,
  servedBy: string,
  latency: number,
  retryCount: number
): Promise<void> {
  await supabase
    .from('recognition_logs')
    .insert({
      user_id: userId,
      served_by: servedBy,
      latency_ms: latency,
      retry_count: retryCount,
      created_at: new Date().toISOString(),
    });
}

function parsePortionSize(description: string): number {
  // USDA data is per 100g, so we need to scale based on actual portion
  // Default to 1.0 (100g) if we can't parse
  let scaleFactor = 1.0;

  console.log(`Parsing portion size from: ${description}`);

  // Try to extract gram value from description (e.g., "~150g", "150 g", "150grams")
  // This must come BEFORE size hints to handle "1 medium banana, ~100g" correctly
  const gramMatch = description.match(/(\d+)\s*(?:g|grams?|gram)/i);
  if (gramMatch) {
    const grams = parseFloat(gramMatch[1]);
    scaleFactor = grams / 100; // Scale relative to 100g
    console.log(`Matched gram value: ${grams}g, scale factor: ${scaleFactor}`);
    return scaleFactor;
  }

  // Try to extract ounce value and convert to grams (1 oz ≈ 28.35g)
  const ozMatch = description.match(/(\d+)\s*(?:oz|ounces?|ounce)/i);
  if (ozMatch) {
    const ounces = parseFloat(ozMatch[1]);
    const grams = ounces * 28.35;
    scaleFactor = grams / 100;
    console.log(`Matched ounce value: ${ounces}oz (${grams}g), scale factor: ${scaleFactor}`);
    return scaleFactor;
  }

  // Try to extract cup value and approximate (1 cup ≈ 240g for most foods)
  const cupMatch = description.match(/(\d+)\s*(?:cup|cups)/i);
  if (cupMatch) {
    const cups = parseFloat(cupMatch[1]);
    const grams = cups * 240;
    scaleFactor = grams / 100;
    console.log(`Matched cup value: ${cups}cup (${grams}g), scale factor: ${scaleFactor}`);
    return scaleFactor;
  }

  // Try to extract piece/slice count with size hints
  const pieceMatch = description.match(/(\d+)\s*(?:piece|pieces|slice|slices)/i);
  if (pieceMatch) {
    const count = parseFloat(pieceMatch[1]);
    // Default approximation: 1 piece/slice ≈ 50g (adjustable)
    const grams = count * 50;
    scaleFactor = grams / 100;
    console.log(`Matched piece count: ${count} (${grams}g), scale factor: ${scaleFactor}`);
    return scaleFactor;
  }

  // Try to extract "medium", "large", "small" size hints
  // Only use these if no specific quantity was found
  if (description.toLowerCase().includes('large')) {
    scaleFactor = 1.5; // Large ≈ 150g
    console.log(`Matched 'large', scale factor: ${scaleFactor}`);
  } else if (description.toLowerCase().includes('medium')) {
    scaleFactor = 1.2; // Medium ≈ 120g
    console.log(`Matched 'medium', scale factor: ${scaleFactor}`);
  } else if (description.toLowerCase().includes('small')) {
    scaleFactor = 0.8; // Small ≈ 80g
    console.log(`Matched 'small', scale factor: ${scaleFactor}`);
  } else {
    console.log(`No pattern matched, using default scale factor: ${scaleFactor}`);
  }

  return scaleFactor;
}

Deno.serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')!;
    const groqApiKey = Deno.env.get('GROQ_API_KEY')!;
    const usdaApiKey = Deno.env.get('USDA_FDC_API_KEY')!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return jsonResponse({ error: 'Invalid token' }, 401);
    }

    const body = await req.json();
    const { image, search_query, get_nutrition, fdc_id } = body;

    // Handle search query (manual food search)
    if (search_query) {
      const foods = await searchUSDA(search_query, usdaApiKey);
      const items = foods.map((food: any) => ({
        id: food.fdcId?.toString() || food.description,
        name: food.description,
        fdc_id: food.fdcId?.toString(),
        confidence_score: 1.0,
        serving_description: '100g',
        quantity: 1.0,
        unit: 'serving',
      }));

      return jsonResponse({ items }, 200);
    }

    // Handle nutrition lookup by FDC ID
    if (get_nutrition && fdc_id) {
      const foodData = await getUSDANutrition(fdc_id, usdaApiKey);
      const nutrients = foodData.foodNutrients || [];
      
      // Get the serving size from USDA data
      // USDA data can be per 100g, per serving, per cup, etc.
      const servingSize = foodData.servingSize || 100;
      const servingSizeUnit = foodData.servingSizeUnit || 'g';
      
      console.log(`USDA serving size: ${servingSize} ${servingSizeUnit}`);
      
      // Convert USDA serving size to grams for consistent scaling
      let usdaServingSizeInGrams = 100; // Default to 100g
      if (servingSizeUnit.toLowerCase() === 'g' || servingSizeUnit.toLowerCase() === 'grams') {
        usdaServingSizeInGrams = servingSize;
      } else if (servingSizeUnit.toLowerCase() === 'mg' || servingSizeUnit.toLowerCase() === 'milligrams') {
        usdaServingSizeInGrams = servingSize / 1000;
      } else if (servingSizeUnit.toLowerCase() === 'kg' || servingSizeUnit.toLowerCase() === 'kilograms') {
        usdaServingSizeInGrams = servingSize * 1000;
      } else if (servingSizeUnit.toLowerCase() === 'oz' || servingSizeUnit.toLowerCase() === 'ounces') {
        usdaServingSizeInGrams = servingSize * 28.35;
      } else if (servingSizeUnit.toLowerCase() === 'lb' || servingSizeUnit.toLowerCase() === 'pounds') {
        usdaServingSizeInGrams = servingSize * 453.59;
      }

      console.log(`USDA serving size in grams: ${usdaServingSizeInGrams}`);

      // USDA nutrient IDs for accurate matching
      const nutrientIdMap: Record<number, string> = {
        1008: 'calories',           // Energy
        1003: 'protein_g',          // Protein
        1005: 'carbs_g',            // Carbohydrate, by difference
        1004: 'fat_g',              // Total lipid (fat)
        1079: 'fiber_g',            // Fiber, total dietary
        2000: 'sugar_g',            // Sugars, total
        1093: 'sodium_mg',          // Sodium
        1087: 'calcium_mg',         // Calcium
        1089: 'iron_mg',            // Iron
        1104: 'vitamin_a_iu',       // Vitamin A, IU
        1162: 'vitamin_c_mg',       // Vitamin C, total ascorbic acid
        1106: 'vitamin_d_iu',       // Vitamin D
        1114: 'vitamin_e_mg',       // Vitamin E
        1187: 'vitamin_k_mg',       // Vitamin K
        1124: 'thiamin_mg',         // Vitamin B1
        1126: 'riboflavin_mg',      // Vitamin B2
        1165: 'niacin_mg',          // Vitamin B3
        1176: 'vitamin_b6_mg',      // Vitamin B6
        1178: 'vitamin_b12_mcg',    // Vitamin B12
        1135: 'folate_mcg',         // Folate
        1092: 'potassium_mg',       // Potassium
        1091: 'phosphorus_mg',      // Phosphorus
        1090: 'magnesium_mg',       // Magnesium
        1098: 'zinc_mg',            // Zinc
        1100: 'copper_mg',          // Copper
        1101: 'manganese_mg',       // Manganese
        1109: 'selenium_mcg',       // Selenium
        1253: 'cholesterol_mg',     // Cholesterol
        1258: 'saturated_fat_g',    // Fatty acids, total saturated
        1292: 'trans_fat_g',        // Fatty acids, total trans
        1257: 'monounsaturated_fat_g', // Fatty acids, total monounsaturated
        1259: 'polyunsaturated_fat_g', // Fatty acids, total polyunsaturated
      };

      const nutritionData: any = {
        calories: 0,
        protein_g: 0,
        carbs_g: 0,
        fat_g: 0,
        fiber_g: 0,
        sugar_g: 0,
        sodium_mg: 0,
        additional_nutrients: [],
      };

      nutrients.forEach((n: any) => {
        const nutrientId = n.nutrient?.id ?? n.id;
        const nutrientName = n.nutrient?.name ?? n.name;
        const unitName = n.nutrient?.unitName ?? n.unitName;
        const value = n.amount ?? n.nutrient?.amount ?? 0;

        if (nutrientId && nutrientIdMap[nutrientId]) {
          const field = nutrientIdMap[nutrientId];
          nutritionData[field] = value;
          console.log(`Matched nutrient ${nutrientId} (${nutrientName}): ${value} ${unitName} -> ${field}`);
        } else {
          // Include all other nutrients as additional data
          nutritionData.additional_nutrients.push({
            id: nutrientId,
            name: nutrientName,
            unit: unitName,
            value: value,
          });
        }
      });
      
      // Log all energy-related nutrients for debugging
      const energyNutrients = nutrients.filter((n: any) => {
        const nutrientId = n.nutrient?.id ?? n.id;
        const nutrientName = (n.nutrient?.name ?? n.name).toLowerCase();
        return nutrientName.includes('energy') || nutrientName.includes('calorie') || nutrientName === 'Energy';
      });
      console.log(`Energy nutrients found: ${JSON.stringify(energyNutrients.map((n: any) => ({
        id: n.nutrient?.id ?? n.id,
        name: n.nutrient?.name ?? n.name,
        value: n.amount ?? n.nutrient?.amount,
        unit: n.nutrient?.unitName ?? n.unitName
      })))}`);

      console.log(`Raw USDA calories: ${nutritionData.calories}`);

      // Parse portion size from serving description to get user's desired portion in grams
      const servingDescription = body.serving_description || '100g';
      const userPortionInGrams = parsePortionSize(servingDescription) * 100; // parsePortionSize returns scale factor relative to 100g
      
      console.log(`Serving description: ${servingDescription}`);
      console.log(`User desired portion in grams: ${userPortionInGrams}`);

      // Calculate scale factor: user portion / USDA serving size
      // This handles cases where USDA data is not per 100g
      const scaleFactor = userPortionInGrams / usdaServingSizeInGrams;
      
      console.log(`Scale factor: ${scaleFactor} (user ${userPortionInGrams}g / USDA ${usdaServingSizeInGrams}g)`);

      // Scale all nutrition values by the portion size factor
      const scaleFields = [
        'calories', 'protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg',
        'calcium_mg', 'iron_mg', 'vitamin_a_iu', 'vitamin_c_mg', 'vitamin_d_iu',
        'vitamin_e_mg', 'vitamin_k_mg', 'thiamin_mg', 'riboflavin_mg', 'niacin_mg',
        'vitamin_b6_mg', 'vitamin_b12_mcg', 'folate_mcg', 'potassium_mg',
        'phosphorus_mg', 'magnesium_mg', 'zinc_mg', 'copper_mg', 'manganese_mg',
        'selenium_mcg', 'cholesterol_mg', 'saturated_fat_g', 'trans_fat_g',
        'monounsaturated_fat_g', 'polyunsaturated_fat_g'
      ];

      scaleFields.forEach(field => {
        if (nutritionData[field] !== undefined) {
          nutritionData[field] = nutritionData[field] * scaleFactor;
        }
      });

      console.log(`Scaled calories: ${nutritionData.calories}`);

      // Scale additional nutrients too
      nutritionData.additional_nutrients = nutritionData.additional_nutrients.map((n: any) => ({
        ...n,
        value: n.value * scaleFactor
      }));

      return jsonResponse(nutritionData, 200);
    }

    // Handle image recognition
    if (!image) {
      return jsonResponse({ error: 'Image required' }, 400);
    }

    const startTime = Date.now();
    const chain = new VisionProviderChain(geminiApiKey, groqApiKey);
    const { results, servedBy } = await chain.recognize(image);
    const latency = Date.now() - startTime;

    // Log recognition
    await logRecognition(supabase, user.id, servedBy, latency, 0);

    // Match with USDA
    const items = [];
    for (const result of results) {
      const usdaFoods = await searchUSDA(result.candidateName, usdaApiKey);
      const bestMatch = usdaFoods[0];

      if (bestMatch) {
        items.push({
          id: bestMatch.fdcId?.toString() || result.candidateName,
          name: result.candidateName,
          fdc_id: bestMatch.fdcId?.toString(),
          confidence_score: result.confidenceHint,
          serving_description: result.estimatedPortionDescription,
          quantity: 1.0,
          unit: 'serving',
        });
      } else {
        items.push({
          id: result.candidateName,
          name: result.candidateName,
          fdc_id: null,
          confidence_score: result.confidenceHint,
          serving_description: result.estimatedPortionDescription,
          quantity: 1.0,
          unit: 'serving',
        });
      }
    }

    return jsonResponse({ items }, 200);

  } catch (error) {
    console.error('Error in scan-food function:', error);

    if (typeof error?.message === 'string' && error.message.startsWith('All vision providers failed')) {
      return jsonResponse(
        { error: 'Recognition temporarily unavailable', details: error.message },
        503
      );
    }

    return jsonResponse({ error: 'Internal server error' }, 500);
  }
});
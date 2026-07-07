import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface VisionResponse {
  candidateName: string;
  estimatedPortionDescription: string;
  confidenceHint: number;
}

interface VisionProvider {
  recognize(imageBase64: string): Promise<VisionResponse[]>;
}

class GeminiVisionProvider implements VisionProvider {
  private apiKey: string;
  private model: string = 'gemini-2.0-flash-exp';

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
    let lastError: Error | null = null;

    for (const provider of this.providers) {
      try {
        const results = await provider.recognize(imageBase64);
        return {
          results,
          servedBy: provider instanceof GeminiVisionProvider ? 'gemini' : 'groq',
        };
      } catch (error) {
        lastError = error as Error;
        console.error(`${provider.constructor.name} failed:`, error);
        // Continue to next provider
      }
    }

    throw new Error('All vision providers failed');
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
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 });
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

      return new Response(JSON.stringify({ items }), { status: 200 });
    }

    // Handle nutrition lookup by FDC ID
    if (get_nutrition && fdc_id) {
      const foodData = await getUSDANutrition(fdc_id, usdaApiKey);
      const nutrients = foodData.foodNutrients || [];

      const nutritionData: any = {
        calories: 0,
        protein_g: 0,
        carbs_g: 0,
        fat_g: 0,
        fiber_g: 0,
        sugar_g: 0,
        sodium_mg: 0,
      };

      nutrients.forEach((n: any) => {
        const name = n.name?.toLowerCase() || '';
        const value = n.amount || 0;

        if (name.includes('energy')) nutritionData.calories = value;
        else if (name.includes('protein')) nutritionData.protein_g = value;
        else if (name.includes('carbohydrate')) nutritionData.carbs_g = value;
        else if (name.includes('total lipid')) nutritionData.fat_g = value;
        else if (name.includes('fiber')) nutritionData.fiber_g = value;
        else if (name.includes('sugars')) nutritionData.sugar_g = value;
        else if (name.includes('sodium')) nutritionData.sodium_mg = value;
      });

      return new Response(JSON.stringify(nutritionData), { status: 200 });
    }

    // Handle image recognition
    if (!image) {
      return new Response(JSON.stringify({ error: 'Image required' }), { status: 400 });
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

    return new Response(JSON.stringify({ items }), { status: 200 });

  } catch (error) {
    console.error('Error in scan-food function:', error);
    
    if (error.message === 'All vision providers failed') {
      return new Response(
        JSON.stringify({ error: 'Recognition temporarily unavailable' }),
        { status: 503 }
      );
    }

    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500 }
    );
  }
});

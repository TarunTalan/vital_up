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
            parts: [
              {
                text: this.getPrompt(),
              },
              {
                inline_data: {
                  mime_type: 'image/jpeg',
                  data: imageBase64,
                },
              },
            ],
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
- If the food belongs to a specific regional cuisine (e.g., Indian), use its native/common name (e.g., 'Paneer Butter Masala' instead of 'Indian cheese curry')
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
  private model: string = 'qwen/qwen3.6-27b';

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

  private providerName(provider: VisionProvider): string {
    return provider instanceof GeminiVisionProvider ? 'gemini' : 'groq';
  }

  // Retries a single provider once on rate-limit errors (with a short backoff)
  // before giving up on it, since 429s are often transient.
  private async recognizeWithRetry(provider: VisionProvider, imageBase64: string): Promise<VisionResponse[]> {
    try {
      return await provider.recognize(imageBase64);
    } catch (error) {
      if ((error as Error).message === 'RATE_LIMIT_EXCEEDED') {
        await new Promise(resolve => setTimeout(resolve, 1500));
        return provider.recognize(imageBase64);
      }
      throw error;
    }
  }

  private normalizeName(name: string): string {
    return name.toLowerCase().trim().replace(/[^a-z0-9 ]/g, '');
  }

  // Calls providers sequentially (Gemini first, then falling back to Groq)
  // to avoid consuming free-tier API quotas from both providers on every request.
  async recognize(imageBase64: string): Promise<{ results: VisionResponse[]; servedBy: string }> {
    const errors: string[] = [];
    
    for (const provider of this.providers) {
      try {
        console.log(`Trying vision provider: ${provider.constructor.name}...`);
        const results = await this.recognizeWithRetry(provider, imageBase64);
        return {
          results,
          servedBy: this.providerName(provider),
        };
      } catch (error) {
        const errorMsg = (error as Error).message;
        errors.push(`${provider.constructor.name}: ${errorMsg}`);
        console.warn(`${provider.constructor.name} failed: ${errorMsg}. Falling back...`);
      }
    }

    throw new Error(`All vision providers failed | ${errors.join(' || ')}`);
  }
}

async function searchUSDA(query: string, apiKey: string, supabase?: any): Promise<any[]> {
  const queryNormalized = query.trim().toLowerCase();
  
  if (supabase) {
    try {
      const { data, error } = await supabase
        .from('food_search_cache')
        .select('search_results, expires_at')
        .eq('query_normalized', queryNormalized)
        .single();
        
      if (!error && data && new Date(data.expires_at) > new Date()) {
        console.log(`Cache hit for USDA search: "${queryNormalized}"`);
        return data.search_results;
      }
    } catch (e) {
      console.error('Error reading search cache:', e);
    }
  }

  const response = await fetch(
    `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(query)}&api_key=${apiKey}&pageSize=10&dataType=Foundation,SR%20Legacy,Branded`
  );

  if (!response.ok) {
    throw new Error('USDA API error');
  }

  const responseData = await response.json();
  const foods = responseData.foods || [];

  // Filter and score foods to get the best match
  // Prefer Foundation and SR Legacy data over Branded
  // Prefer exact name matches
  // Processed/derivative forms that should only outrank the plain/raw food
  // when the user actually asked for that form. Without this, a search for
  // "potato" was matching "Flour, potato" (a USDA Foundation entry) ahead of
  // any plain potato entry, because Foundation data type + substring match
  // outscored everything else regardless of how transformed the food was.
  const PROCESSED_FORM_WORDS = [
    'flour', 'starch', 'powder', 'bread', 'chips', 'crisps', 'dried',
    'dehydrated', 'canned', 'juice', 'extract', 'flakes', 'granules',
    'concentrate', 'syrup', 'paste', 'puree',
  ];

  const DESCRIPTOR_WORDS = new Set([
    'whole', 'raw', 'fresh', 'cooked', 'canned', 'boiled', 'baked', 'grilled',
    'roasted', 'fried', 'steamed', 'large', 'medium', 'small', 'slice', 'slices',
    'piece', 'pieces', 'bag', 'pack', 'bottle', 'can', 'cup', 'bowl', 'organic',
    'natural', 'pure', 'generic', 'wild', 'farmed', 'cultivated'
  ]);

  const scoredFoods = foods.map((food: any) => {
    let score = 0;
    const foodNameLower = food.description.toLowerCase();
    const queryLower = query.toLowerCase();

    // 1. Base DataType Boosts (small tie-breakers only)
    if (food.dataType === 'Foundation') {
      score += 3;
    } else if (food.dataType === 'SR Legacy') {
      score += 2;
    } else if (food.dataType === 'Survey (FNDDS)') {
      score += 1;
    }

    // 2. Exact or Substring Matches on full query
    if (foodNameLower === queryLower) {
      score += 100;
    } else if (foodNameLower.startsWith(queryLower)) {
      score += 60;
    } else if (foodNameLower.includes(queryLower)) {
      score += 40;
    }

    // 3. Word-by-Word Matching
    const queryWords = queryLower.split(/[^a-z0-9]+/i).filter(Boolean);
    let matchedCoreWords = 0;

    queryWords.forEach((word) => {
      // Match word boundary and support plural 's'
      const wordRegex = new RegExp(`\\b${word}s?\\b`, 'i');
      if (wordRegex.test(foodNameLower)) {
        if (DESCRIPTOR_WORDS.has(word)) {
          score += 2; // Descriptors get minor weight
        } else {
          score += 25; // Core food words get major weight
          matchedCoreWords++;
        }
      }
    });

    // 4. Boost USDA standard naming conventions (e.g. "<Food>, raw")
    queryWords.forEach((word) => {
      if (!DESCRIPTOR_WORDS.has(word)) {
        const rawConventionRegex = new RegExp(`^${word}s?,\\s*raw\\b`, 'i');
        if (rawConventionRegex.test(foodNameLower)) {
          score += 15;
        }
      }
    });

    // 5. Penalize processed/derivative forms UNLESS the user's query mentioned them
    for (const word of PROCESSED_FORM_WORDS) {
      if (foodNameLower.includes(word) && !queryLower.includes(word)) {
        score -= 15;
      }
    }

    // 6. Penalize foods with very long descriptions (likely complex items)
    if (food.description.length > 60) {
      score -= 5;
    }

    return { ...food, score };
  });

  // Sort by score and return top results
  scoredFoods.sort((a: any, b: any) => b.score - a.score);

  console.log(`USDA search for "${query}": found ${foods.length} results, top scored: ${scoredFoods.slice(0, 3).map((f: any) => `${f.description} (${f.dataType}, score: ${f.score})`).join(', ')}`);

  const results = scoredFoods.slice(0, 5);

  // Save to cache
  if (supabase) {
    try {
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7); // Cache for 7 days
      await supabase
        .from('food_search_cache')
        .insert({
          query_normalized: queryNormalized,
          search_results: results,
          expires_at: expiresAt.toISOString(),
        });
    } catch (e) {
      console.error('Error writing to search cache:', e);
    }
  }

  return results;
}

async function getUSDANutrition(fdcId: string, apiKey: string): Promise<any> {
  const url = `https://api.nal.usda.gov/fdc/v1/food/${fdcId}?api_key=${apiKey}`;
  const response = await fetch(url);

  if (!response.ok) {
    const errorText = await response.text().catch(() => '');
    throw new Error(`USDA API error: Status ${response.status}. Response: ${errorText}`);
  }

  return response.json();
}

async function getIndianOrFallbackNutrition(foodName: string, geminiApiKey: string): Promise<any> {
  const prompt = `Provide the standard nutritional values per 100g for "${foodName}" (focusing on Indian Food Composition Tables (IFCT) or standard USDA/generic equivalents). Return the response in this exact JSON structure:
{
  "calories": 150.0,
  "protein": 5.0,
  "carbs": 12.0,
  "fat": 8.0,
  "fiber": 2.0,
  "sugar": 4.0,
  "sodium": 200.0
}`;

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          tools: [{ googleSearch: {} }],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: 'application/json',
          },
        }),
      }
    );

    if (response.ok) {
      const data = await response.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (text) {
        return JSON.parse(text);
      }
    }
  } catch (e) {
    console.error(`Gemini grounding fallback failed for ${foodName}:`, e);
  }
  return null;
}

async function saveRecipeToProprietary(supabase: any, productName: string, nutriments: any, source: string) {
  try {
    const { data } = await supabase
      .from('proprietary_products')
      .select('id')
      .eq('product_name', productName)
      .maybeSingle();

    if (!data) {
      const { error } = await supabase
        .from('proprietary_products')
        .insert({
          product_name: productName,
          serving_size: '100g',
          calories: Number(nutriments.calories ?? 0),
          protein_g: Number(nutriments.protein ?? 0),
          carbs_g: Number(nutriments.carbs ?? 0),
          fat_g: Number(nutriments.fat ?? 0),
          fiber_g: Number(nutriments.fiber ?? 0),
          sugar_g: Number(nutriments.sugar ?? 0),
          sodium_mg: Number(nutriments.sodium ?? 0),
          source: source,
          updated_at: new Date().toISOString(),
        });
      if (error) {
        console.error(`Failed to insert into proprietary_products: ${error.message}`);
      } else {
        console.log(`Saved fallback recipe "${productName}" to proprietary_products cache.`);
      }
    }
  } catch (e) {
    console.error(`Error saving to proprietary_products cache:`, e);
  }
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
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY_FOOD_SCANNER')!;
    const groqApiKey = Deno.env.get('GROQ_API_KEY_FOOD_SCANNER')!;
    const usdaApiKey = Deno.env.get('USDA_FDC_API_KEY') || 'DEMO_KEY';

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
    const { image, search_query, get_nutrition, fdc_id, barcode } = body;

    // Handle barcode lookup
    if (barcode) {
      const barcodeStr = barcode.toString().trim();
      console.log(`Processing barcode lookup request for: "${barcodeStr}"`);
      
      // 1. Try our own proprietary database first
      try {
        const { data: propProduct, error: propError } = await supabase
          .from('proprietary_products')
          .select('*')
          .eq('barcode', barcodeStr)
          .maybeSingle();

        if (!propError && propProduct) {
          console.log(`Proprietary database hit for barcode: "${barcodeStr}" -> "${propProduct.product_name}"`);
          return jsonResponse({
            productName: propProduct.product_name,
            servingSize: propProduct.serving_size || '100g',
            nutriments: {
              calories: Number(propProduct.calories ?? 0),
              protein: Number(propProduct.protein_g ?? 0),
              carbs: Number(propProduct.carbs_g ?? 0),
              fat: Number(propProduct.fat_g ?? 0),
              fiber: Number(propProduct.fiber_g ?? 0),
              sugar: Number(propProduct.sugar_g ?? 0),
              sodium: Number(propProduct.sodium_mg ?? 0),
            }
          }, 200);
        }
      } catch (err) {
        console.error('Error reading from proprietary_products table:', err);
      }

      // Helper function to cache results in the proprietary database in the background
      const saveToProprietary = async (productName: string, servingSize: string, nutriments: any, source: string) => {
        try {
          const { error } = await supabase
            .from('proprietary_products')
            .upsert({
              barcode: barcodeStr,
              product_name: productName,
              serving_size: servingSize,
              calories: Number(nutriments.calories ?? 0),
              protein_g: Number(nutriments.protein ?? 0),
              carbs_g: Number(nutriments.carbs ?? 0),
              fat_g: Number(nutriments.fat ?? 0),
              fiber_g: Number(nutriments.fiber ?? 0),
              sugar_g: Number(nutriments.sugar ?? 0),
              sodium_mg: Number(nutriments.sodium ?? 0),
              source: source,
              updated_at: new Date().toISOString(),
            });
          if (error) {
            console.error(`Failed to write to proprietary_products: ${error.message}`);
          }
        } catch (e) {
          console.error(`Error saving to proprietary_products:`, e);
        }
      };

      // 2. Try Open Food Facts next (Indian subdomain / India filtered)
      try {
        const offResponse = await fetch(`https://in.openfoodfacts.org/api/v0/product/${barcodeStr}.json`);
        if (offResponse.ok) {
          const offData = await offResponse.json();
          const product = offData.product;
          if (offData.status === 1 && product && typeof product === 'object') {
            const productName = product.product_name || product.product_name_en;
            const nutriments = product.nutriments || {};
            
            const hasCalories = nutriments['energy-kcal_serving'] || nutriments['energy-kcal_100g'] || nutriments['energy-kcal'];
            const hasMacros = nutriments['proteins_100g'] || nutriments['carbohydrates_100g'] || nutriments['fat_100g'];
            
            if (productName && (hasCalories || hasMacros)) {
              console.log(`Open Food Facts success for barcode: "${barcodeStr}" -> "${productName}"`);
              const responsePayload = {
                productName,
                servingSize: product.serving_size || '100g',
                nutriments: {
                  calories: Number(nutriments['energy-kcal_serving'] ?? nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] ?? 0),
                  protein: Number(nutriments['proteins_serving'] ?? nutriments['proteins_100g'] ?? nutriments['proteins'] ?? 0),
                  carbs: Number(nutriments['carbohydrates_serving'] ?? nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates'] ?? 0),
                  fat: Number(nutriments['fat_serving'] ?? nutriments['fat_100g'] ?? nutriments['fat'] ?? 0),
                  fiber: Number(nutriments['fiber_serving'] ?? nutriments['fiber_100g'] ?? nutriments['fiber'] ?? 0),
                  sugar: Number(nutriments['sugars_serving'] ?? nutriments['sugars_100g'] ?? nutriments['sugars'] ?? 0),
                  sodium: Number(nutriments['sodium_serving'] ?? nutriments['sodium_100g'] ?? nutriments['sodium'] ?? 0) * 1000.0,
                }
              };
              
              // Cache in proprietary DB in the background
              await saveToProprietary(
                responsePayload.productName,
                responsePayload.servingSize,
                responsePayload.nutriments,
                'off'
              );

              return jsonResponse(responsePayload, 200);
            }
          }
        }
      } catch (e) {
        console.error('Error fetching from Open Food Facts:', e);
      }
      
      // 3. Fallback to Gemini with Google Search Grounding to find product name and nutrition!
      console.log(`Open Food Facts incomplete or missing for barcode: "${barcodeStr}". Invoking Gemini Search Grounding fallback...`);
      try {
        const prompt = `Identify the product name, brand, serving size description, and nutrition information (calories in kcal, protein in g, carbs in g, fat in g, fiber in g, sugar in g, sodium in mg) for the product with barcode "${barcodeStr}". Focus on Indian databases/grocery stores (like Blinkit, BigBasket, Zepto) if it starts with 890. Return the response in this exact JSON structure:
{
  "productName": "Product Name",
  "servingSize": "serving size (e.g. '100g' or '1 pack (90g)')",
  "calories": 150.0,
  "protein": 5.0,
  "carbs": 12.0,
  "fat": 8.0,
  "fiber": 2.0,
  "sugar": 4.0,
  "sodium": 200.0
}`;

        const geminiResponse = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              tools: [{ googleSearch: {} }],
              generationConfig: {
                temperature: 0.1,
                responseMimeType: 'application/json',
              },
            }),
          }
        );
        
        if (geminiResponse.ok) {
          const resData = await geminiResponse.json();
          const text = resData.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) {
            const parsed = JSON.parse(text);
            console.log(`Gemini Search Grounding fallback success for barcode: "${barcodeStr}" -> "${parsed.productName}"`);
            const responsePayload = {
              productName: parsed.productName || 'Unknown Product',
              servingSize: parsed.servingSize || '100g',
              nutriments: {
                calories: parsed.calories ?? 0,
                protein: parsed.protein ?? 0,
                carbs: parsed.carbs ?? 0,
                fat: parsed.fat ?? 0,
                fiber: parsed.fiber ?? 0,
                sugar: parsed.sugar ?? 0,
                sodium: parsed.sodium ?? 0,
              }
            };
            
            // Cache in proprietary DB in the background
            await saveToProprietary(
              responsePayload.productName,
              responsePayload.servingSize,
              responsePayload.nutriments,
              'gemini_grounding'
            );

            return jsonResponse(responsePayload, 200);
          }
        }
      } catch (geminiErr) {
        console.error('Gemini Search Grounding fallback failed:', geminiErr);
      }
      
      return jsonResponse({ error: 'Barcode not found' }, 404);
    }

    // Handle search query (manual food search) — fuzzy proprietary + USDA merge
    if (search_query) {
      const queryStr = search_query.toString().trim();
      console.log(`Processing search_query: "${queryStr}"`);

      // Run proprietary fuzzy search and USDA search in parallel
      const [proprietaryResults, usdaFoods] = await Promise.allSettled([
        supabase.rpc('search_products_fuzzy', { p_query: queryStr, p_limit: 8 }),
        searchUSDA(queryStr, usdaApiKey, supabase),
      ]);

      const items: any[] = [];
      const seenNames = new Set<string>();

      // 1. Add proprietary results first (highest trust — user-contributed, FSSAI-sourced)
      if (proprietaryResults.status === 'fulfilled' && !proprietaryResults.value.error) {
        const propRows: any[] = proprietaryResults.value.data ?? [];
        for (const row of propRows) {
          const nameLower = row.product_name.toLowerCase();
          if (!seenNames.has(nameLower)) {
            seenNames.add(nameLower);
            items.push({
              id: row.barcode || row.product_name,
              name: row.product_name,
              fdc_id: null,
              source: 'proprietary',
              serving_description: row.serving_size ?? '100g',
              quantity: 1.0,
              unit: 'serving',
              // Full nutrition payload so client can prefill the dialog immediately
              nutrition: {
                calories: Number(row.calories ?? 0),
                protein: Number(row.protein_g ?? 0),
                carbs: Number(row.carbs_g ?? 0),
                fat: Number(row.fat_g ?? 0),
                fiber: Number(row.fiber_g ?? 0),
                sugar: Number(row.sugar_g ?? 0),
                sodium: Number(row.sodium_mg ?? 0),
              },
            });
          }
        }
        console.log(`Proprietary fuzzy search returned ${propRows.length} results.`);
      } else if (proprietaryResults.status === 'rejected') {
        console.error('Proprietary fuzzy search RPC failed:', proprietaryResults.reason);
      }

      // 2. Append USDA results that aren't already covered by proprietary results
      if (usdaFoods.status === 'fulfilled') {
        for (const food of usdaFoods.value) {
          const nameLower = (food.description ?? '').toLowerCase();
          if (!seenNames.has(nameLower)) {
            seenNames.add(nameLower);
            items.push({
              id: food.fdcId?.toString() || food.description,
              name: food.description,
              fdc_id: food.fdcId?.toString(),
              source: 'usda',
              serving_description: '100g',
              quantity: 1.0,
              unit: 'serving',
              // USDA requires a separate get_nutrition call to get full macros
              nutrition: null,
            });
          }
        }
      }

      return jsonResponse({ items }, 200);
    }

    // Handle nutrition lookup by FDC ID or Proprietary Name/Barcode
    if (get_nutrition && fdc_id) {
      const idStr = fdc_id.toString().trim();
      
      // 1. Check proprietary DB first (exact match by barcode or name)
      try {
        const { data: propData, error: propError } = await supabase
          .from('proprietary_products')
          .select('*')
          .or(`barcode.eq."${idStr}",product_name.eq."${idStr}"`)
          .maybeSingle();
          
        if (!propError && propData) {
          console.log(`Proprietary DB hit in get_nutrition for: "${idStr}"`);
          
          const servingDescription = body.serving_description || propData.serving_size || '100g';
          const userPortionInGrams = parsePortionSize(servingDescription) * 100;
          
          let propServingSizeGrams = 100;
          if (propData.serving_size) {
            propServingSizeGrams = parsePortionSize(propData.serving_size) * 100;
          }
          const scaleFactor = userPortionInGrams / propServingSizeGrams;
          
          return jsonResponse({
            calories: Number(propData.calories ?? 0) * scaleFactor,
            protein_g: Number(propData.protein_g ?? 0) * scaleFactor,
            carbs_g: Number(propData.carbs_g ?? 0) * scaleFactor,
            fat_g: Number(propData.fat_g ?? 0) * scaleFactor,
            fiber_g: Number(propData.fiber_g ?? 0) * scaleFactor,
            sugar_g: Number(propData.sugar_g ?? 0) * scaleFactor,
            sodium_mg: Number(propData.sodium_mg ?? 0) * scaleFactor,
            additional_nutrients: [],
          }, 200);
        }
      } catch (e) {
        console.error('Proprietary DB lookup error in get_nutrition:', e);
      }

      // 2. Fall back to USDA FDC lookup
      let numericId = idStr;
      const isNumeric = /^\d+$/.test(numericId);
      
      if (!isNumeric) {
        console.log(`Non-numeric fdc_id provided: "${fdc_id}". Searching USDA by name first.`);
        const searchResults = await searchUSDA(fdc_id.toString(), usdaApiKey, supabase);
        if (searchResults.length > 0 && searchResults[0].fdcId) {
          numericId = searchResults[0].fdcId.toString();
          console.log(`Found matching FDC ID: ${numericId} for "${fdc_id}"`);
        } else {
          console.log(`No USDA match found for non-numeric fdc_id: "${fdc_id}". Returning placeholder nutrition.`);
          return jsonResponse({
            calories: 0,
            protein_g: 0,
            carbs_g: 0,
            fat_g: 0,
            fiber_g: 0,
            sugar_g: 0,
            sodium_mg: 0,
            additional_nutrients: [],
          }, 200);
        }
      }

      let foodData;
      let nutrients = [];
      let usdaServingSizeInGrams = 100;
      const cacheKey = `usda_raw:${numericId}`;

      // Check database cache first
      let cachedData = null;
      try {
        const { data, error } = await supabase
          .from('food_search_cache')
          .select('search_results')
          .eq('query_normalized', cacheKey)
          .single();
        if (!error && data) {
          console.log(`Cache hit for USDA raw nutrition: "${cacheKey}"`);
          cachedData = data.search_results;
        }
      } catch (e) {
        console.error('Error reading raw nutrition cache:', e);
      }

      if (cachedData) {
        foodData = cachedData;
        nutrients = foodData.foodNutrients || [];
        const servingSize = foodData.servingSize || 100;
        const servingSizeUnit = foodData.servingSizeUnit || 'g';
        
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
      } else {
        // Cache miss, call USDA
        try {
          foodData = await getUSDANutrition(numericId, usdaApiKey);
          nutrients = foodData.foodNutrients || [];
          
          const servingSize = foodData.servingSize || 100;
          const servingSizeUnit = foodData.servingSizeUnit || 'g';
          
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

          // Save to database cache
          try {
            const expiresAt = new Date();
            expiresAt.setDate(expiresAt.getDate() + 7); // Cache for 7 days
            await supabase
              .from('food_search_cache')
              .insert({
                query_normalized: cacheKey,
                search_results: foodData,
                expires_at: expiresAt.toISOString(),
              });
          } catch (e) {
            console.error('Error writing raw nutrition to cache:', e);
          }
        } catch (error) {
          console.error(`Failed to fetch FDC ID ${numericId} from detail endpoint:`, error);
          
          // Fallback: Search for the FDC ID on the foods search API
          console.log(`Trying search endpoint fallback for FDC ID ${numericId}...`);
          try {
            const searchResults = await searchUSDA(numericId, usdaApiKey, supabase);
            const matchedFood = searchResults.find((f: any) => f.fdcId?.toString() === numericId) ?? searchResults[0];
            
            if (matchedFood) {
              console.log(`Found fallback food: ${matchedFood.description}`);
              nutrients = matchedFood.foodNutrients || [];
              
              const servingSizeUnit = matchedFood.servingSizeUnit || 'g';
              const servingSize = matchedFood.servingSize || 100;
              
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
            } else {
              throw new Error('No food item matched the FDC ID in search fallback.');
            }
          } catch (fallbackError) {
            console.error('Fallback search also failed:', fallbackError);
            return jsonResponse({
              calories: 0,
              protein_g: 0,
              carbs_g: 0,
              fat_g: 0,
              fiber_g: 0,
              sugar_g: 0,
              sodium_mg: 0,
              additional_nutrients: [],
            }, 200);
          }
        }
      }

      // IMPORTANT: matching is done primarily by NUTRIENT NAME (which the
      // USDA API always returns correctly alongside each value), not by a
      // hardcoded ID table. A previous version of this map had several IDs
      // transposed (e.g. it read Thiamin's id (1165) but wrote it into
      // niacin_mg; it read Biotin's id (1176) but wrote it into
      // vitamin_b6_mg; it read Copper's id (1098) but wrote it into
      // zinc_mg). Matching by name is immune to that whole class of bug —
      // it doesn't matter what ID USDA assigned, only what the entry is
      // actually called. Order matters: more specific patterns are listed
      // before more general ones.
      const nutrientNameRules: Array<{ test: RegExp; field: string }> = [
        { test: /^protein$/i, field: 'protein_g' },
        { test: /^carbohydrate/i, field: 'carbs_g' },
        { test: /^total lipid \(fat\)$/i, field: 'fat_g' },
        { test: /^fiber, total dietary$/i, field: 'fiber_g' },
        { test: /^sugars,? total/i, field: 'sugar_g' },
        { test: /^sodium/i, field: 'sodium_mg' },
        { test: /^calcium/i, field: 'calcium_mg' },
        { test: /^iron/i, field: 'iron_mg' },
        { test: /^potassium/i, field: 'potassium_mg' },
        { test: /^phosphorus/i, field: 'phosphorus_mg' },
        { test: /^magnesium/i, field: 'magnesium_mg' },
        { test: /^zinc/i, field: 'zinc_mg' },
        { test: /^copper/i, field: 'copper_mg' },
        { test: /^manganese/i, field: 'manganese_mg' },
        { test: /^selenium/i, field: 'selenium_mcg' },
        { test: /^vitamin a, rae/i, field: 'vitamin_a_mcg' },
        { test: /^vitamin a, iu/i, field: 'vitamin_a_iu' },
        { test: /^vitamin d \(d2 ?\+ ?d3\)/i, field: 'vitamin_d_mcg' },
        { test: /^vitamin d/i, field: 'vitamin_d_iu' },
        { test: /^vitamin e/i, field: 'vitamin_e_mg' },
        { test: /^vitamin k/i, field: 'vitamin_k_mg' },
        { test: /^vitamin c/i, field: 'vitamin_c_mg' },
        { test: /^thiamin/i, field: 'thiamin_mg' },
        { test: /^riboflavin/i, field: 'riboflavin_mg' },
        { test: /^niacin/i, field: 'niacin_mg' },
        { test: /^vitamin b-?6/i, field: 'vitamin_b6_mg' },
        { test: /^vitamin b-?12/i, field: 'vitamin_b12_mcg' },
        { test: /^biotin/i, field: 'biotin_ug' },
        { test: /^folate,? total/i, field: 'folate_mcg' },
        { test: /^cholesterol/i, field: 'cholesterol_mg' },
        { test: /^fatty acids, total saturated/i, field: 'saturated_fat_g' },
        { test: /^fatty acids, total trans/i, field: 'trans_fat_g' },
        { test: /^fatty acids, total monounsaturated/i, field: 'monounsaturated_fat_g' },
        { test: /^fatty acids, total polyunsaturated/i, field: 'polyunsaturated_fat_g' },
      ];

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
        const nutrientId = n.nutrient?.id ?? n.id ?? n.nutrientId;
        const nutrientName: string = n.nutrient?.name ?? n.name ?? n.nutrientName ?? '';
        const unitName = n.nutrient?.unitName ?? n.unitName;
        const value = n.amount ?? n.nutrient?.amount ?? n.value ?? 0;

        const rule = nutrientNameRules.find(r => r.test.test(nutrientName.trim()));

        if (rule) {
          nutritionData[rule.field] = value;
          console.log(`Matched nutrient ${nutrientId} (${nutrientName}): ${value} ${unitName} -> ${rule.field}`);
        } else {
          // Include all other nutrients (including Energy, handled separately
          // below) as additional data.
          nutritionData.additional_nutrients.push({
            id: nutrientId,
            name: nutrientName,
            unit: unitName,
            value: value,
          });
        }
      });

      // --- Calories ---
      // Prefer the standard "Energy" value in kcal (USDA id 1008). Some
      // Foundation Foods entries don't include id 1008 at all and only
      // provide the Atwater-factor-derived energy values — without a
      // fallback this silently produced 0 calories for those foods.
      const energyNutrients = nutrients.filter((n: any) => {
        const name = (n.nutrient?.name ?? n.name ?? n.nutrientName ?? '').toLowerCase();
        return name.includes('energy');
      });

      const findEnergy = (predicate: (name: string) => boolean) =>
        energyNutrients.find((n: any) => predicate((n.nutrient?.name ?? n.name ?? n.nutrientName ?? '').toLowerCase()));

      const standardEnergy = findEnergy(name => name === 'energy');
      const atwaterGeneral = findEnergy(name => name.includes('atwater general'));
      const atwaterSpecific = findEnergy(name => name.includes('atwater specific'));

      const chosenEnergy = standardEnergy ?? atwaterGeneral ?? atwaterSpecific;

      if (chosenEnergy) {
        nutritionData.calories = chosenEnergy.amount ?? chosenEnergy.nutrient?.amount ?? chosenEnergy.value ?? 0;
        console.log(`Calories source: ${chosenEnergy.nutrient?.name ?? chosenEnergy.name ?? chosenEnergy.nutrientName} = ${nutritionData.calories} kcal`);
      } else {
        console.log('No energy nutrient (standard or Atwater) found in USDA response');
      }

      console.log(`Energy nutrients found: ${JSON.stringify(energyNutrients.map((n: any) => ({
        id: n.nutrient?.id ?? n.id ?? n.nutrientId,
        name: n.nutrient?.name ?? n.name ?? n.nutrientName,
        value: n.amount ?? n.nutrient?.amount ?? n.value,
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

    // Match with proprietary database and USDA in parallel for all candidates
    const matchPromises = results.map(async (result) => {
      const queryStr = result.candidateName;

      // Run proprietary fuzzy search and USDA search in parallel
      const [proprietaryResults, usdaFoods] = await Promise.allSettled([
        supabase.rpc('search_products_fuzzy', { p_query: queryStr, p_limit: 1 }),
        searchUSDA(queryStr, usdaApiKey, supabase),
      ]);

      let bestProprietaryMatch = null;
      if (proprietaryResults.status === 'fulfilled' && !proprietaryResults.value.error && proprietaryResults.value.data?.length > 0) {
        bestProprietaryMatch = proprietaryResults.value.data[0];
      }

      const bestUsdaMatch = usdaFoods.status === 'fulfilled' ? usdaFoods.value[0] : null;

      // If matches are missing or poor (e.g. score < 20 in USDA and no proprietary match),
      // we invoke the Gemini Search Grounding fallback to fetch accurate nutritional values
      // for Indian recipes/dishes (like Roti, Samosa, Paneer Tikka, Dosa).
      const isPoorMatch = !bestProprietaryMatch && (!bestUsdaMatch || bestUsdaMatch.score < 20);

      if (isPoorMatch) {
        console.log(`Poor match for candidate "${queryStr}" (USDA score: ${bestUsdaMatch?.score ?? 'none'}). Running Gemini Grounding fallback...`);
        const fallbackNutrients = await getIndianOrFallbackNutrition(queryStr, geminiApiKey);
        
        if (fallbackNutrients) {
          // Cache in the proprietary database so future get_nutrition lookups (by name) succeed instantly
          await saveRecipeToProprietary(supabase, queryStr, fallbackNutrients, 'gemini_grounding_fallback');
          
          return {
            id: queryStr,
            name: queryStr,
            fdc_id: queryStr, // Pass name as fdc_id so get_nutrition matches it in proprietary table
            source: 'proprietary',
            confidence_score: result.confidenceHint,
            serving_description: result.estimatedPortionDescription,
            quantity: 1.0,
            unit: 'serving',
          };
        }
      }

      if (bestProprietaryMatch) {
        return {
          id: bestProprietaryMatch.barcode || bestProprietaryMatch.product_name,
          name: result.candidateName, // Keep the AI's label for display
          fdc_id: null,
          source: 'proprietary',
          confidence_score: result.confidenceHint,
          serving_description: bestProprietaryMatch.serving_size ?? result.estimatedPortionDescription,
          quantity: 1.0,
          unit: 'serving',
        };
      } else if (bestUsdaMatch) {
        return {
          id: bestUsdaMatch.fdcId?.toString() || result.candidateName,
          name: result.candidateName,
          fdc_id: bestUsdaMatch.fdcId?.toString(),
          source: 'usda',
          confidence_score: result.confidenceHint,
          serving_description: result.estimatedPortionDescription,
          quantity: 1.0,
          unit: 'serving',
        };
      } else {
        return {
          id: result.candidateName,
          name: result.candidateName,
          fdc_id: null,
          confidence_score: result.confidenceHint,
          serving_description: result.estimatedPortionDescription,
          quantity: 1.0,
          unit: 'serving',
        };
      }
    });

    const items = await Promise.all(matchPromises);

    return jsonResponse({ items }, 200);

  } catch (error) {
    console.error('Error in scan-food function:', error);

    const errorMessage = error instanceof Error ? error.message : String(error);

    if (errorMessage.startsWith('All vision providers failed')) {
      return jsonResponse(
        { error: 'Recognition temporarily unavailable', details: errorMessage },
        503
      );
    }

    if (errorMessage.includes('USDA API error')) {
      return jsonResponse(
        { error: 'USDA API lookup failed', details: errorMessage },
        500
      );
    }

    return jsonResponse({ error: 'Internal server error', details: errorMessage }, 500);
  }
});
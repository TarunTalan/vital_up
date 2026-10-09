import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  caloriesAgree,
  extractJson,
  nameSimilarity,
  parsePortionGrams,
  sanitizePer100g,
  type Per100g,
  type VisionItem,
} from './nutrition.ts';
import { geminiGenerate } from '../_shared/llm.ts';
import { consumeDailyQuota, dailyLimit, refundDailyQuota } from '../_shared/quota.ts';
import {
  bearerToken,
  clampNumber,
  cleanText,
  HttpError,
  KB,
  LIMITS,
  MB,
  optionalText,
  RANGES,
  readJsonBody,
  requireMethod,
  requireText,
} from '../_shared/validate.ts';
import {
  estimateNutritionPer100g,
  GeminiVisionProvider,
  GroqVisionProvider,
  recognizeHedged,
  type VisionProvider,
} from './vision.ts';

/** Lookup names can be USDA descriptions the app got from a search, which run long. */
const LOOKUP_NAME_MAX = 200;

// Request modes (all POST, JSON body, authenticated):
//   { image, mime_type? }                       -> photo recognition with inline nutrition
//   { search_query }                            -> manual food search
//   { get_nutrition, fdc_id, serving_description, food_name? } -> nutrition for one item
//   { barcode }                                 -> packaged product lookup

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

/** Lets cache writes / logging finish after the response is sent. */
function background(task: PromiseLike<unknown>): void {
  const guarded = Promise.resolve(task).catch((e) => console.error('Background task failed:', e));
  // deno-lint-ignore no-explicit-any
  (globalThis as any).EdgeRuntime?.waitUntil?.(guarded);
}

function withTimeout<T>(promise: Promise<T>, ms: number, fallback: T): Promise<T> {
  return Promise.race([promise, new Promise<T>((resolve) => setTimeout(() => resolve(fallback), ms))]);
}

const ZERO_NUTRITION = {
  calories: 0,
  protein_g: 0,
  carbs_g: 0,
  fat_g: 0,
  fiber_g: 0,
  sugar_g: 0,
  sodium_mg: 0,
  additional_nutrients: [],
};

// ---------------------------------------------------------------------------
// USDA FoodData Central
// ---------------------------------------------------------------------------

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
  'natural', 'pure', 'generic', 'wild', 'farmed', 'cultivated',
]);

const escapeRegex = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function scoreUsdaFoods(query: string, foods: any[]): any[] {
  const queryLower = query.toLowerCase();
  const queryWords = queryLower.split(/[^a-z0-9]+/i).filter(Boolean);

  return foods
    .map((food: any) => {
      let score = 0;
      const foodNameLower = String(food.description ?? '').toLowerCase();

      // 1. Base DataType Boosts (small tie-breakers only)
      if (food.dataType === 'Foundation') score += 3;
      else if (food.dataType === 'SR Legacy') score += 2;
      else if (food.dataType === 'Survey (FNDDS)') score += 1;

      // 2. Exact or Substring Matches on full query
      if (foodNameLower === queryLower) score += 100;
      else if (foodNameLower.startsWith(queryLower)) score += 60;
      else if (foodNameLower.includes(queryLower)) score += 40;

      // 3. Word-by-Word Matching (supports plural 's')
      for (const word of queryWords) {
        if (new RegExp(`\\b${escapeRegex(word)}s?\\b`, 'i').test(foodNameLower)) {
          score += DESCRIPTOR_WORDS.has(word) ? 2 : 25;
        }
      }

      // 4. Boost USDA standard naming conventions (e.g. "<Food>, raw")
      for (const word of queryWords) {
        if (!DESCRIPTOR_WORDS.has(word) && new RegExp(`^${escapeRegex(word)}s?,\\s*raw\\b`, 'i').test(foodNameLower)) {
          score += 15;
        }
      }

      // 5. Penalize processed/derivative forms UNLESS the query mentioned them
      for (const word of PROCESSED_FORM_WORDS) {
        if (foodNameLower.includes(word) && !queryLower.includes(word)) score -= 15;
      }

      // 6. Penalize very long descriptions (likely complex items)
      if (foodNameLower.length > 60) score -= 5;

      return { ...food, score };
    })
    .sort((a: any, b: any) => b.score - a.score);
}

async function readCache(supabase: SupabaseClient, key: string): Promise<any | null> {
  try {
    const { data } = await supabase
      .from('food_search_cache')
      .select('search_results, expires_at')
      .eq('query_normalized', key)
      .maybeSingle();
    if (data && new Date(data.expires_at) > new Date()) return data.search_results;
  } catch (e) {
    console.error(`Cache read failed for "${key}":`, e);
  }
  return null;
}

function writeCache(supabase: SupabaseClient, key: string, value: unknown, days = 7): void {
  const expiresAt = new Date(Date.now() + days * 86400000).toISOString();
  // Upsert: the key is UNIQUE, so a plain insert could never refresh an
  // expired row and the cache would go permanently stale.
  background(
    supabase
      .from('food_search_cache')
      .upsert({ query_normalized: key, search_results: value, expires_at: expiresAt }, { onConflict: 'query_normalized' })
      .then(({ error }) => error && console.error(`Cache write failed for "${key}": ${error.message}`)),
  );
}

async function searchUSDA(query: string, apiKey: string, supabase: SupabaseClient): Promise<any[]> {
  const key = query.trim().toLowerCase();
  const cached = await readCache(supabase, key);
  if (cached) return cached;

  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(query)}` +
    `&api_key=${apiKey}&pageSize=15&dataType=Foundation,SR%20Legacy,Survey%20(FNDDS),Branded`;
  const response = await fetch(url, { signal: AbortSignal.timeout(6000) });
  if (!response.ok) throw new Error(`USDA API error: search ${response.status}`);

  const foods = (await response.json()).foods ?? [];
  const results = scoreUsdaFoods(query, foods).slice(0, 5);
  console.log(`USDA "${query}": ${results.slice(0, 3).map((f: any) => `${f.description} (${f.dataType}, ${f.score})`).join(', ')}`);

  writeCache(supabase, key, results);
  return results;
}

async function getUSDAFood(fdcId: string, apiKey: string, supabase: SupabaseClient): Promise<any> {
  const key = `usda_raw:${fdcId}`;
  const cached = await readCache(supabase, key);
  if (cached) return cached;

  const response = await fetch(`https://api.nal.usda.gov/fdc/v1/food/${fdcId}?api_key=${apiKey}`, {
    signal: AbortSignal.timeout(6000),
  });
  if (!response.ok) throw new Error(`USDA API error: food ${fdcId} ${response.status}`);
  const food = await response.json();
  writeCache(supabase, key, food);
  return food;
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
const NUTRIENT_NAME_RULES: Array<{ test: RegExp; field: string }> = [
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

// deno-lint-ignore no-explicit-any
type NutritionData = Record<string, any>;

/**
 * Maps USDA foodNutrients (detail endpoint `{nutrient:{name}, amount}` or
 * search endpoint `{nutrientName, value}` shape) to our per-100g fields.
 * FDC reports foodNutrients per 100 g for every data type, Branded included
 * (label-per-serving values live in `labelNutrients`, which we don't use).
 */
function mapUsdaNutrients(nutrients: any[]): NutritionData {
  const data: NutritionData = { ...ZERO_NUTRITION, additional_nutrients: [] };
  const nameOf = (n: any): string => String(n.nutrient?.name ?? n.name ?? n.nutrientName ?? '').trim();
  const unitOf = (n: any): string => String(n.nutrient?.unitName ?? n.unitName ?? '').toLowerCase();
  const valueOf = (n: any): number => Number(n.amount ?? n.nutrient?.amount ?? n.value ?? 0) || 0;

  for (const n of nutrients) {
    const name = nameOf(n);
    const rule = NUTRIENT_NAME_RULES.find((r) => r.test.test(name));
    if (rule) {
      data[rule.field] = valueOf(n);
    } else if (!/energy/i.test(name)) {
      data.additional_nutrients.push({
        id: n.nutrient?.id ?? n.id ?? n.nutrientId,
        name,
        unit: n.nutrient?.unitName ?? n.unitName,
        value: valueOf(n),
      });
    }
  }

  // Calories: prefer "Energy" in kcal; some Foundation entries only carry the
  // Atwater-derived energies; convert kJ-only entries.
  const energies = nutrients.filter((n) => /energy/i.test(nameOf(n)));
  const find = (pred: (name: string, unit: string) => boolean) =>
    energies.find((n) => pred(nameOf(n).toLowerCase(), unitOf(n)));
  const chosen =
    find((name, unit) => name === 'energy' && unit.includes('kcal')) ??
    find((name, unit) => name.includes('atwater general') && unit.includes('kcal')) ??
    find((name, unit) => name.includes('atwater specific') && unit.includes('kcal')) ??
    find((_, unit) => !unit.includes('kj')) ??
    energies[0];
  if (chosen) {
    const raw = valueOf(chosen);
    data.calories = unitOf(chosen).includes('kj') ? raw / 4.184 : raw;
  }
  return data;
}

function scaleNutritionData(per100g: NutritionData, grams: number): NutritionData {
  const factor = grams / 100;
  const scaled: NutritionData = {};
  for (const [key, value] of Object.entries(per100g)) {
    scaled[key] = typeof value === 'number' ? value * factor : value;
  }
  scaled.additional_nutrients = (per100g.additional_nutrients ?? []).map((n: any) => ({
    ...n,
    value: (Number(n.value) || 0) * factor,
  }));
  return scaled;
}

function nutritionDataFromPer100g(p: Per100g): NutritionData {
  return {
    calories: p.calories,
    protein_g: p.protein,
    carbs_g: p.carbs,
    fat_g: p.fat,
    fiber_g: p.fiber,
    sugar_g: p.sugar,
    sodium_mg: p.sodium,
    additional_nutrients: [],
  };
}

function per100gFromNutritionData(d: NutritionData): Per100g | null {
  return sanitizePer100g({
    calories: d.calories,
    protein: d.protein_g,
    carbs: d.carbs_g,
    fat: d.fat_g,
    fiber: d.fiber_g,
    sugar: d.sugar_g,
    sodium: d.sodium_mg,
  });
}

interface UsdaMatch {
  fdcId: string;
  description: string;
  data: NutritionData; // per 100 g
  per100g: Per100g;
}

/** Best USDA entry for [name], only when it's genuinely the same food. */
async function bestUsdaMatch(name: string, apiKey: string, supabase: SupabaseClient): Promise<UsdaMatch | null> {
  try {
    const results = await searchUSDA(name, apiKey, supabase);
    for (const food of results.slice(0, 3)) {
      if (food.score < 50 || nameSimilarity(name, food.description ?? '') < 0.5) continue;
      const data = mapUsdaNutrients(food.foodNutrients ?? []);
      const per100g = per100gFromNutritionData(data);
      if (per100g) return { fdcId: String(food.fdcId), description: food.description, data, per100g };
    }
  } catch (e) {
    console.warn(`USDA match for "${name}" failed: ${(e as Error).message}`);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Proprietary products (our own DB: Indian dishes, FSSAI/OFF barcodes, user entries)
// ---------------------------------------------------------------------------

function proprietaryPer100g(row: any): Per100g | null {
  const servingGrams = parsePortionGrams(row.serving_size) ?? 100;
  const k = 100 / servingGrams;
  return sanitizePer100g({
    calories: Number(row.calories ?? 0) * k,
    protein: Number(row.protein_g ?? 0) * k,
    carbs: Number(row.carbs_g ?? 0) * k,
    fat: Number(row.fat_g ?? 0) * k,
    fiber: Number(row.fiber_g ?? 0) * k,
    sugar: Number(row.sugar_g ?? 0) * k,
    sodium: Number(row.sodium_mg ?? 0) * k,
  });
}

async function bestProprietaryMatch(
  name: string,
  supabase: SupabaseClient,
): Promise<{ name: string; per100g: Per100g } | null> {
  try {
    const { data, error } = await supabase.rpc('search_products_fuzzy', { p_query: name, p_limit: 5 });
    if (error || !data?.length) return null;
    // The RPC's fuzzy ranking alone would happily map "Paneer Tikka" to
    // "Paneer Paratha"; require real token overlap before trusting a row.
    let best: { row: any; sim: number } | null = null;
    for (const row of data) {
      const sim = nameSimilarity(name, row.product_name ?? '');
      if (!best || sim > best.sim) best = { row, sim };
    }
    if (!best || best.sim < 0.75) return null;
    const per100g = proprietaryPer100g(best.row);
    return per100g ? { name: best.row.product_name, per100g } : null;
  } catch (e) {
    console.warn(`Proprietary match for "${name}" failed: ${(e as Error).message}`);
    return null;
  }
}

function saveEstimateToProprietary(supabase: SupabaseClient, productName: string, p: Per100g, source: string): void {
  background((async () => {
    const { data } = await supabase
      .from('proprietary_products')
      .select('id')
      .eq('product_name', productName)
      .limit(1);
    if (data?.length) return;
    const { error } = await supabase.from('proprietary_products').insert({
      product_name: productName,
      serving_size: '100g',
      calories: p.calories,
      protein_g: p.protein,
      carbs_g: p.carbs,
      fat_g: p.fat,
      fiber_g: p.fiber,
      sugar_g: p.sugar,
      sodium_mg: p.sodium,
      source,
      updated_at: new Date().toISOString(),
    });
    if (error) console.error(`Failed to cache "${productName}" in proprietary_products: ${error.message}`);
  })());
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

interface Env {
  supabase: SupabaseClient;
  geminiKey?: string;
  groqKey?: string;
  usdaKey: string;
}

async function handleImage(env: Env, userId: string, image: string, mimeType: string): Promise<Response> {
  const providers: VisionProvider[] = [];
  if (env.geminiKey) providers.push(new GeminiVisionProvider(env.geminiKey));
  if (env.groqKey) providers.push(new GroqVisionProvider(env.groqKey));

  // Reserve one photo scan up front so concurrent requests can't overshoot
  // the cap; refunded below if recognition fails or finds no food.
  const quota = await consumeDailyQuota(env.supabase, userId, 'photo_scan', dailyLimit('FREE_DAILY_SCANS', 25));
  if (!quota.allowed) {
    console.log(`Daily scan limit (${quota.limit}) reached for ${userId}`);
    return jsonResponse({ error: 'Daily scan limit reached', code: 'daily_limit', limit: quota.limit }, 429);
  }

  const startTime = Date.now();
  let recognition: Awaited<ReturnType<typeof recognizeHedged>>;
  try {
    recognition = await recognizeHedged(providers, image, mimeType);
  } catch (e) {
    background(refundDailyQuota(env.supabase, userId, 'photo_scan'));
    throw e;
  }
  const { items: visionItems, servedBy } = recognition;
  const latency = Date.now() - startTime;
  if (visionItems.length === 0) background(refundDailyQuota(env.supabase, userId, 'photo_scan'));
  console.log(`Vision (${servedBy}, ${latency}ms): ${visionItems.map((v) => `${v.name} ${v.grams}g`).join(', ')}`);

  background(
    env.supabase.from('recognition_logs').insert({
      user_id: userId,
      served_by: servedBy,
      latency_ms: latency,
      retry_count: 0,
      created_at: new Date().toISOString(),
    }).then(({ error }) => error && console.error(`recognition_logs insert failed: ${error.message}`)),
  );

  const items = await Promise.all(visionItems.map((v) => enrichVisionItem(env, v)));
  return jsonResponse({ items: items.filter(Boolean), served_by: servedBy, scans_remaining: quota.remaining }, 200);
}

/**
 * Picks the most trustworthy nutrition source for one recognised item:
 *   1. our proprietary DB, on a close name match (curated Indian values)
 *   2. USDA, for whole foods only (USDA is poor at Indian prepared dishes and
 *      tends to surface raw-ingredient entries, e.g. raw rice at 365 kcal)
 *   3. the vision model's own per-100g estimate (IFCT-guided prompt)
 * Database values are cross-checked against the model's estimate: if they
 * disagree wildly the match is almost certainly the wrong food/form.
 */
async function enrichVisionItem(env: Env, v: VisionItem) {
  const model = v.per100g;
  const wantUsda = v.category === 'whole_food' || !model;

  const [prop, usda] = await Promise.all([
    withTimeout(bestProprietaryMatch(v.name, env.supabase), 2500, null),
    wantUsda ? withTimeout(bestUsdaMatch(v.name, env.usdaKey, env.supabase), 3500, null) : Promise.resolve(null),
  ]);

  let per100gData: NutritionData | null = null;
  let source = 'ai_estimate';
  let fdcId: string | null = null;

  if (prop && (!model || caloriesAgree(prop.per100g.calories, model.calories, 2))) {
    per100gData = nutritionDataFromPer100g(prop.per100g);
    source = 'proprietary';
  } else if (usda && (!model || caloriesAgree(usda.per100g.calories, model.calories, 1.5))) {
    per100gData = usda.data;
    source = 'usda';
    fdcId = usda.fdcId;
  } else if (model) {
    per100gData = nutritionDataFromPer100g(model);
  } else {
    const estimate = await estimateNutritionPer100g(v.name, { gemini: env.geminiKey, groq: env.groqKey });
    if (estimate) per100gData = nutritionDataFromPer100g(estimate);
  }

  return {
    id: crypto.randomUUID(),
    name: v.name,
    // Used by the client for follow-up get_nutrition calls.
    fdc_id: fdcId ?? v.name,
    source,
    category: v.category,
    confidence_score: v.confidence,
    serving_description: v.portion,
    quantity: Math.round(v.grams),
    unit: 'g',
    grams: Math.round(v.grams),
    nutrition: per100gData ? scaleNutritionData(per100gData, v.grams) : null,
    nutrition_per_100g: per100gData,
  };
}

async function handleSearch(env: Env, query: string): Promise<Response> {
  const [proprietaryResults, usdaFoods] = await Promise.allSettled([
    env.supabase.rpc('search_products_fuzzy', { p_query: query, p_limit: 8 }),
    searchUSDA(query, env.usdaKey, env.supabase),
  ]);

  const items: any[] = [];
  const seenNames = new Set<string>();

  // 1. Proprietary results first (highest trust — curated, FSSAI-sourced)
  if (proprietaryResults.status === 'fulfilled' && !proprietaryResults.value.error) {
    for (const row of proprietaryResults.value.data ?? []) {
      const nameLower = String(row.product_name).toLowerCase();
      if (seenNames.has(nameLower)) continue;
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
  } else if (proprietaryResults.status === 'rejected') {
    console.error('Proprietary fuzzy search RPC failed:', proprietaryResults.reason);
  }

  // 2. USDA results not already covered
  if (usdaFoods.status === 'fulfilled') {
    for (const food of usdaFoods.value) {
      const nameLower = String(food.description ?? '').toLowerCase();
      if (seenNames.has(nameLower)) continue;
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

  return jsonResponse({ items }, 200);
}

interface NutritionRequest {
  fdcId: string;
  foodName: string;
  servingDescription: string;
}

async function handleGetNutrition(env: Env, request: NutritionRequest): Promise<Response> {
  const idStr = request.fdcId;
  const foodName = request.foodName || idStr;
  const grams = clampNumber(parsePortionGrams(request.servingDescription) ?? 100, 1, RANGES.grams.max, 100);
  const respond = (per100g: NutritionData) => jsonResponse(scaleNutritionData(per100g, grams), 200);

  // 1. Proprietary DB exact hit by barcode or name. Two eq() filters rather
  //    than one or(): names contain commas/quotes that break PostgREST's
  //    or-filter syntax.
  try {
    const [byBarcode, byName] = await Promise.all([
      env.supabase.from('proprietary_products').select('*').eq('barcode', idStr).limit(1),
      env.supabase.from('proprietary_products').select('*').eq('product_name', idStr).limit(1),
    ]);
    const row = byBarcode.data?.[0] ?? byName.data?.[0];
    const per100g = row ? proprietaryPer100g(row) : null;
    if (per100g) {
      console.log(`Proprietary hit in get_nutrition for "${idStr}"`);
      return respond(nutritionDataFromPer100g(per100g));
    }
  } catch (e) {
    console.error('Proprietary lookup error in get_nutrition:', e);
  }

  // 2. USDA by FDC id.
  if (/^\d+$/.test(idStr)) {
    try {
      const food = await getUSDAFood(idStr, env.usdaKey, env.supabase);
      const data = mapUsdaNutrients(food.foodNutrients ?? []);
      // The app auto-picks the first search hit for a typed name; if that
      // entry is clearly a different food ("Rajma Chawal" -> "Beans, kidney,
      // raw"), resolve by name below instead.
      const relevant = foodName === idStr || nameSimilarity(foodName, food.description ?? '') >= 0.34;
      if (relevant && per100gFromNutritionData(data)) return respond(data);
    } catch (e) {
      console.warn(`USDA detail for ${idStr} failed: ${(e as Error).message}`);
    }
    if (foodName === idStr) return jsonResponse(ZERO_NUTRITION, 200);
  }

  // 3. By name: close proprietary match, then close USDA match, then an AI
  //    estimate (cached so the next lookup of this name is instant).
  const prop = await bestProprietaryMatch(foodName, env.supabase);
  if (prop) return respond(nutritionDataFromPer100g(prop.per100g));

  const usda = await bestUsdaMatch(foodName, env.usdaKey, env.supabase);
  if (usda) return respond(usda.data);

  const estimate = await estimateNutritionPer100g(foodName, { gemini: env.geminiKey, groq: env.groqKey });
  if (estimate) {
    saveEstimateToProprietary(env.supabase, foodName, estimate, 'ai_estimate');
    return respond(nutritionDataFromPer100g(estimate));
  }

  // Zeros tell the client to fall back to its offline estimate.
  return jsonResponse(ZERO_NUTRITION, 200);
}

/** Sanitised barcode response from upstream / model data; null without a name. */
function barcodePayload(productName: unknown, servingSize: unknown, n: Record<string, unknown>) {
  const name = cleanText(productName, 120);
  if (!name) return null;
  const grams = (v: unknown) => clampNumber(v, 0, RANGES.grams.max);
  return {
    productName: name,
    servingSize: cleanText(servingSize, 60) || '100g',
    nutriments: {
      calories: clampNumber(n.calories, 0, RANGES.calories.max),
      protein: grams(n.protein),
      carbs: grams(n.carbs),
      fat: grams(n.fat),
      fiber: grams(n.fiber),
      sugar: grams(n.sugar),
      sodium: clampNumber(n.sodium, 0, 100000),
    },
  };
}

async function handleBarcode(env: Env, barcodeStr: string): Promise<Response> {
  const saveToProprietary = (productName: string, servingSize: string, n: any, source: string) =>
    background(
      env.supabase.from('proprietary_products').upsert({
        barcode: barcodeStr,
        product_name: productName,
        serving_size: servingSize,
        calories: Number(n.calories ?? 0),
        protein_g: Number(n.protein ?? 0),
        carbs_g: Number(n.carbs ?? 0),
        fat_g: Number(n.fat ?? 0),
        fiber_g: Number(n.fiber ?? 0),
        sugar_g: Number(n.sugar ?? 0),
        sodium_mg: Number(n.sodium ?? 0),
        source,
        updated_at: new Date().toISOString(),
      }).then(({ error }) => error && console.error(`Failed to write to proprietary_products: ${error.message}`)),
    );

  // 1. Our proprietary database
  try {
    const { data } = await env.supabase.from('proprietary_products').select('*').eq('barcode', barcodeStr).limit(1);
    const row = data?.[0];
    if (row) {
      console.log(`Proprietary hit for barcode "${barcodeStr}" -> "${row.product_name}"`);
      return jsonResponse({
        productName: row.product_name,
        servingSize: row.serving_size || '100g',
        nutriments: {
          calories: Number(row.calories ?? 0),
          protein: Number(row.protein_g ?? 0),
          carbs: Number(row.carbs_g ?? 0),
          fat: Number(row.fat_g ?? 0),
          fiber: Number(row.fiber_g ?? 0),
          sugar: Number(row.sugar_g ?? 0),
          sodium: Number(row.sodium_mg ?? 0),
        },
      }, 200);
    }
  } catch (err) {
    console.error('Error reading proprietary_products:', err);
  }

  // 2. Open Food Facts (Indian mirror)
  try {
    const offResponse = await fetch(`https://in.openfoodfacts.org/api/v0/product/${barcodeStr}.json`, {
      signal: AbortSignal.timeout(6000),
    });
    if (offResponse.ok) {
      const offData = await offResponse.json();
      const product = offData.product;
      if (offData.status === 1 && product && typeof product === 'object') {
        const productName = product.product_name || product.product_name_en;
        const n = product.nutriments || {};
        // Use one basis for every nutrient: mixing per-serving calories with
        // per-100g macros (whichever happened to be present) produced
        // internally inconsistent labels.
        const perServing = n['energy-kcal_serving'] != null && !!product.serving_size;
        const suffix = perServing ? '_serving' : '_100g';
        const val = (k: string) => Number(n[k + suffix] ?? 0) || 0;
        const calories = val('energy-kcal') || val('energy') / 4.184;
        const sodiumG = val('sodium') || val('salt') / 2.5;

        const payload = barcodePayload(productName, perServing ? product.serving_size : '100g', {
          calories,
          protein: val('proteins'),
          carbs: val('carbohydrates'),
          fat: val('fat'),
          fiber: val('fiber'),
          sugar: val('sugars'),
          sodium: sodiumG * 1000,
        });
        if (payload && (calories || val('proteins') || val('carbohydrates') || val('fat'))) {
          console.log(`Open Food Facts hit for barcode "${barcodeStr}" -> "${payload.productName}"`);
          saveToProprietary(payload.productName, payload.servingSize, payload.nutriments, 'off');
          return jsonResponse(payload, 200);
        }
      }
    }
  } catch (e) {
    console.error('Error fetching from Open Food Facts:', e);
  }

  // 3. Gemini with Google Search grounding. Grounding is a paid-tier-only
  //    feature (free-tier keys are refused), so it is opt-in via
  //    GEMINI_SEARCH_GROUNDING=true. We deliberately don't fall back to an
  //    ungrounded model here: it would invent a plausible product for an
  //    unknown barcode. A 404 sends the user to manual entry instead.
  if (env.geminiKey && Deno.env.get('GEMINI_SEARCH_GROUNDING') === 'true') {
    try {
      const prompt = `Identify the product with barcode "${barcodeStr}" and its nutrition facts. ` +
        `${barcodeStr.startsWith('890') ? 'It is an Indian product; check Indian grocery listings (Blinkit, BigBasket, Zepto, Amazon.in) and the brand site. ' : ''}` +
        `If you cannot find this exact barcode, return {"productName": null}. Otherwise return ONLY JSON:\n` +
        `{"productName":"Brand Product","servingSize":"1 pack (90g)","calories":0,"protein":0,"carbs":0,"fat":0,"fiber":0,"sugar":0,"sodium":0}\n` +
        `Values are per the stated servingSize; calories in kcal, sodium in mg, others in g.`;
      const text = await geminiGenerate(env.geminiKey, [{ text: prompt }], {
        googleSearch: true,
        json: true,
        signal: AbortSignal.timeout(20000),
      });
      const parsed = extractJson(text);
      const payload = parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? barcodePayload((parsed as any).productName, (parsed as any).servingSize, parsed as Record<string, unknown>)
        : null;
      if (payload) {
        console.log(`Gemini grounding hit for barcode "${barcodeStr}" -> "${payload.productName}"`);
        saveToProprietary(payload.productName, payload.servingSize, payload.nutriments, 'gemini_grounding');
        return jsonResponse(payload, 200);
      }
    } catch (e) {
      console.error('Gemini grounding fallback failed:', e);
    }
  }

  return jsonResponse({ error: 'Barcode not found' }, 404);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/** Largest photo accepted, decoded. The app sends JPEGs well under this. */
const MAX_IMAGE_BYTES = 6 * MB;
/** Base64 inflates by 4/3; leave room for the other JSON fields. */
const MAX_BODY_BYTES = Math.ceil((MAX_IMAGE_BYTES * 4) / 3) + 16 * KB;
const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];
const BASE64_RE = /^[A-Za-z0-9+/]+={0,2}$/;
const BARCODE_RE = /^[0-9A-Za-z]{4,32}$/;

/** Validates the photo payload; returns clean base64 or throws 400/413. */
function validateImage(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0) throw new HttpError(400, 'Image required');
  const base64 = value.replace(/^data:image\/[a-z0-9.+-]+;base64,/i, '').replace(/\s+/g, '');
  const padding = base64.endsWith('==') ? 2 : base64.endsWith('=') ? 1 : 0;
  const decodedBytes = Math.floor((base64.length * 3) / 4) - padding;
  if (decodedBytes > MAX_IMAGE_BYTES) throw new HttpError(413, 'Image is too large.');
  if (base64.length % 4 !== 0 || !BASE64_RE.test(base64)) throw new HttpError(400, 'Image is not valid base64.');
  if (decodedBytes < 100) throw new HttpError(400, 'Image is too small.');
  return base64;
}

/** fdc_id is a USDA id, a barcode, a product name or a client UUID. */
function validateLookupId(value: unknown): string {
  if (typeof value === 'number' && Number.isSafeInteger(value) && value >= 0) return String(value);
  return requireText(value, 'fdc_id', { max: LOOKUP_NAME_MAX });
}

let serviceClient: SupabaseClient | null = null;

Deno.serve(async (req) => {
  try {
    requireMethod(req, 'POST');

    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !serviceKey) {
      console.error('scan-food: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set');
      return jsonResponse({ error: 'Service is not configured.' }, 500);
    }
    serviceClient ??= createClient(url, serviceKey);
    const supabase = serviceClient;
    const env: Env = {
      supabase,
      geminiKey: Deno.env.get('GEMINI_API_KEY_FOOD_SCANNER') || undefined,
      groqKey: Deno.env.get('GROQ_API_KEY_FOOD_SCANNER') || undefined,
      usdaKey: Deno.env.get('USDA_FDC_API_KEY') || 'DEMO_KEY',
    };

    const token = bearerToken(req);
    if (!token) return jsonResponse({ error: 'Unauthorized' }, 401);

    // Verify the user while the (possibly multi-MB) body is being read.
    const [authResult, bodyResult] = await Promise.allSettled([
      supabase.auth.getUser(token),
      readJsonBody(req, MAX_BODY_BYTES),
    ]);
    const user = authResult.status === 'fulfilled' ? authResult.value.data.user : null;
    if (!user) {
      console.error(
        'JWT verification failed:',
        authResult.status === 'fulfilled' ? authResult.value.error?.message : authResult.reason,
      );
      return jsonResponse({ error: 'Invalid token' }, 401);
    }
    if (bodyResult.status === 'rejected') throw bodyResult.reason;
    const body = bodyResult.value;

    if (body.barcode !== undefined && body.barcode !== null && body.barcode !== '') {
      const barcode = typeof body.barcode === 'number' ? String(body.barcode) : body.barcode;
      if (typeof barcode !== 'string' || !BARCODE_RE.test(barcode.trim())) {
        return jsonResponse({ error: 'Barcode is not valid.' }, 400);
      }
      return await handleBarcode(env, barcode.trim());
    }
    if (body.search_query !== undefined && body.search_query !== null && body.search_query !== '') {
      // Over-long queries are cut rather than refused: only the start matters.
      const query = requireText(body.search_query, 'search_query', { max: LIMITS.search, clip: true });
      return await handleSearch(env, query);
    }
    if (body.get_nutrition && body.fdc_id !== undefined && body.fdc_id !== null && body.fdc_id !== '') {
      return await handleGetNutrition(env, {
        fdcId: validateLookupId(body.fdc_id),
        foodName: optionalText(body.food_name, 'food_name', { max: LOOKUP_NAME_MAX, clip: true }) ?? '',
        servingDescription: optionalText(body.serving_description, 'serving_description', {
          max: LIMITS.shortText,
          clip: true,
        }) ?? '',
      });
    }

    const image = validateImage(body.image);
    const mimeType = typeof body.mime_type === 'string' && IMAGE_MIME_TYPES.includes(body.mime_type.toLowerCase())
      ? body.mime_type.toLowerCase()
      : 'image/jpeg';
    return await handleImage(env, user.id, image, mimeType);
  } catch (error) {
    if (error instanceof HttpError) return jsonResponse({ error: error.message }, error.status);
    console.error('Error in scan-food function:', error);
    const errorMessage = error instanceof Error ? error.message : String(error);

    // Details stay in the logs; clients only see `error` (and match on status).
    if (errorMessage.startsWith('All vision providers failed')) {
      return jsonResponse({ error: 'Recognition temporarily unavailable' }, 503);
    }
    if (errorMessage.includes('USDA API error')) {
      return jsonResponse({ error: 'Food lookup failed' }, 502);
    }
    return jsonResponse({ error: 'Internal server error' }, 500);
  }
});

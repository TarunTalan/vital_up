// Pure helpers shared by the scan-food handler. No Deno / network APIs here so
// this module can be unit-tested with plain Node (`nutrition.test.ts`).

export interface Per100g {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number;
  sugar: number;
  sodium: number; // mg
}

export type FoodCategory = 'whole_food' | 'prepared_dish' | 'packaged' | 'beverage';

export interface VisionItem {
  name: string;
  category: FoodCategory;
  portion: string;
  grams: number;
  confidence: number;
  per100g: Per100g | null;
}

const CATEGORIES: FoodCategory[] = ['whole_food', 'prepared_dish', 'packaged', 'beverage'];

// JSON extraction lives with the LLM clients; re-exported for callers/tests.
export { extractJson } from '../_shared/llm.ts';

// ---------------------------------------------------------------------------
// Numbers & nutrition sanity
// ---------------------------------------------------------------------------

export function toNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const match = value.replace(/,/g, '').match(/-?\d+(?:\.\d+)?/);
    if (match) return parseFloat(match[0]);
  }
  return null;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

export function atwaterCalories(p: { protein: number; carbs: number; fat: number; fiber?: number }): number {
  // Carbs from models/USDA include fiber; fiber yields ~2 kcal/g, not 4.
  const fiber = Math.min(p.fiber ?? 0, p.carbs);
  return 4 * p.protein + 4 * (p.carbs - fiber) + 2 * fiber + 9 * p.fat;
}

/**
 * Validates a per-100g nutrition block. Returns null when it's unusable.
 * Fixes the two most common model mistakes: macros that exceed 100 g per
 * 100 g, and a calorie figure that disagrees with the macros.
 */
export function sanitizePer100g(raw: unknown): Per100g | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  const pick = (...keys: string[]) => {
    for (const k of keys) {
      const n = toNumber(r[k]);
      if (n !== null) return Math.max(0, n);
    }
    return 0;
  };

  let protein = pick('protein', 'protein_g', 'proteins');
  let carbs = pick('carbs', 'carbs_g', 'carbohydrates', 'carbohydrate');
  let fat = pick('fat', 'fat_g', 'fats', 'total_fat');
  let fiber = pick('fiber', 'fiber_g', 'fibre', 'dietary_fiber');
  let sugar = pick('sugar', 'sugar_g', 'sugars');
  const sodium = clamp(pick('sodium', 'sodium_mg'), 0, 40000);
  let calories = pick('calories', 'kcal', 'energy', 'energy_kcal');

  const macroMass = protein + carbs + fat;
  if (macroMass > 100) {
    const k = 100 / macroMass;
    protein *= k;
    carbs *= k;
    fat *= k;
  }
  fiber = Math.min(fiber, carbs);
  sugar = Math.min(sugar, carbs);

  const derived = atwaterCalories({ protein, carbs, fat, fiber });
  if (calories <= 0 && derived <= 0) return null;
  if (calories <= 0 || (derived > 0 && Math.abs(calories - derived) / derived > 0.35)) {
    calories = derived;
  }
  calories = clamp(calories, 0, 900);

  return { calories, protein, carbs, fat, fiber, sugar, sodium };
}

/** True when two calorie densities are within [ratio] of each other. */
export function caloriesAgree(a: number, b: number, ratio = 1.5): boolean {
  if (a <= 0 || b <= 0) return a === b;
  return Math.max(a, b) / Math.min(a, b) <= ratio;
}

// ---------------------------------------------------------------------------
// Portions
// ---------------------------------------------------------------------------

// Household measures, in grams of cooked/served food. Indian measures included
// because models and users describe portions in them.
const UNIT_GRAMS: Array<{ re: RegExp; grams: number }> = [
  { re: /\b(?:kg|kgs|kilograms?)\b/i, grams: 1000 },
  { re: /\b(?:g|gm|gms|gr|grams?|grammes?)\b/i, grams: 1 },
  { re: /\b(?:ml|millilit(?:er|re)s?)\b/i, grams: 1 },
  { re: /\b(?:l|lit(?:er|re)s?)\b/i, grams: 1000 },
  { re: /\b(?:oz|ounces?)\b/i, grams: 28.35 },
  { re: /\b(?:lb|lbs|pounds?)\b/i, grams: 453.6 },
  { re: /\b(?:tbsp|tablespoons?)\b/i, grams: 15 },
  { re: /\b(?:tsp|teaspoons?)\b/i, grams: 5 },
  { re: /\b(?:cups?)\b/i, grams: 240 },
  { re: /\b(?:katoris?|bowls?)\b/i, grams: 150 },
  { re: /\b(?:glass(?:es)?|tumblers?)\b/i, grams: 250 },
  { re: /\b(?:plates?|thalis?)\b/i, grams: 350 },
  { re: /\b(?:pieces?|pcs?|slices?|nos?|units?)\b/i, grams: 50 },
];

/**
 * Extracts a gram weight from a free-text portion ("2 rotis (~80 g)",
 * "1 katori", "250ml", "1.5 cups"). Explicit weights win over household
 * measures. Returns null if nothing recognisable is present.
 */
export function parsePortionGrams(description: string | null | undefined): number | null {
  if (!description) return null;
  const text = description.toLowerCase();

  // 1. Explicit mass/volume anywhere in the string, e.g. "(~150 g)".
  for (const unit of UNIT_GRAMS.slice(0, 6)) {
    // Drop the leading \b: "118g" has no word boundary between digit and unit.
    const re = new RegExp(`(\\d+(?:\\.\\d+)?)\\s*${unit.re.source.replace(/^\\b/, '')}`, 'i');
    const m = text.match(re);
    if (m) return parseFloat(m[1]) * unit.grams;
  }

  // 2. Household measures with an optional leading count ("2 cups", "cup").
  for (const unit of UNIT_GRAMS.slice(6)) {
    const re = new RegExp(`(?:(\\d+(?:\\.\\d+)?|½|half)\\s*)?${unit.re.source}`, 'i');
    const m = text.match(re);
    if (m) {
      const qty = m[1] === undefined ? 1 : m[1] === '½' || m[1] === 'half' ? 0.5 : parseFloat(m[1]);
      return qty * unit.grams;
    }
  }

  // 3. Bare size words.
  if (/\blarge\b/.test(text)) return 150;
  if (/\bmedium\b/.test(text)) return 120;
  if (/\bsmall\b/.test(text)) return 80;
  if (/\b(?:serving|portion)\b/.test(text)) return 100;
  return null;
}

// ---------------------------------------------------------------------------
// Names
// ---------------------------------------------------------------------------

// Transliteration variants commonly seen for Indian dishes, folded to one
// canonical spelling so fuzzy matching isn't defeated by spelling.
const SPELLING_VARIANTS: Record<string, string> = {
  daal: 'dal', dhal: 'dal', dhall: 'dal',
  sambhar: 'sambar', saambar: 'sambar',
  chapati: 'roti', chapathi: 'roti', chappati: 'roti', chapatti: 'roti', phulka: 'roti', rotis: 'roti',
  chapatis: 'roti', parathas: 'paratha', porotta: 'parotta',
  biriyani: 'biryani', briyani: 'biryani', biriani: 'biryani',
  pulav: 'pulao', pilaf: 'pulao', pullao: 'pulao',
  alu: 'aloo', aaloo: 'aloo', gobhi: 'gobi', bindi: 'bhindi',
  channa: 'chana', chickpea: 'chana', chickpeas: 'chana', chholey: 'chole', chhole: 'chole', cholay: 'chole',
  panir: 'paneer',
  idly: 'idli', idlis: 'idli', idlies: 'idli', dosai: 'dosa', dosas: 'dosa', thosai: 'dosa',
  vadai: 'vada', wada: 'vada',
  kichdi: 'khichdi', khichri: 'khichdi', khichadi: 'khichdi',
  raitha: 'raita', dahi: 'curd', yogurt: 'curd', yoghurt: 'curd',
  puris: 'puri', poori: 'puri', pooris: 'puri',
  samosas: 'samosa', pakoras: 'pakora', pakodas: 'pakora', pakoda: 'pakora', bhajji: 'bhaji', bajji: 'bhaji',
  rajmah: 'rajma', kadi: 'kadhi', upittu: 'upma', uppuma: 'upma',
  chawal: 'rice', bhaat: 'rice', bhat: 'rice', annam: 'rice',
};

const STOP_WORDS = new Set([
  'a', 'an', 'the', 'of', 'with', 'and', 'in', 'on', 'style', 'homemade', 'home', 'made',
  'indian', 'fresh', 'plain', 'serving', 'portion', 'piece', 'pieces', 'bowl', 'plate',
  'prepared', 'dish',
]);

export function nameTokens(name: string): string[] {
  return name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .split(/[^a-z0-9]+/)
    .filter(Boolean)
    .map((t) => SPELLING_VARIANTS[t] ?? (t.length > 3 && t.endsWith('s') ? t.slice(0, -1) : t))
    .filter((t) => !STOP_WORDS.has(t));
}

/** Dice coefficient over meaningful tokens: 1 = same food, 0 = unrelated. */
export function nameSimilarity(a: string, b: string): number {
  const ta = new Set(nameTokens(a));
  const tb = new Set(nameTokens(b));
  if (ta.size === 0 || tb.size === 0) return 0;
  let shared = 0;
  for (const t of ta) if (tb.has(t)) shared++;
  return (2 * shared) / (ta.size + tb.size);
}

// ---------------------------------------------------------------------------
// Vision output normalisation
// ---------------------------------------------------------------------------

export function normalizeVisionItems(parsed: unknown): VisionItem[] {
  let list: unknown = parsed;
  if (list && !Array.isArray(list) && typeof list === 'object') {
    const obj = list as Record<string, unknown>;
    list = obj.items ?? obj.foods ?? obj.food_items ?? obj.results ?? [];
  }
  if (!Array.isArray(list)) throw new Error('Model output has no items array');

  const items: VisionItem[] = [];
  for (const entry of list) {
    if (!entry || typeof entry !== 'object') continue;
    const e = entry as Record<string, unknown>;
    const name = String(e.name ?? e.candidateName ?? e.food ?? '').trim();
    if (!name) continue;

    const portion = String(e.portion ?? e.estimatedPortionDescription ?? e.serving ?? '').trim();
    const grams = toNumber(e.grams ?? e.estimatedGrams ?? e.weight_g) ?? parsePortionGrams(portion) ?? 100;
    const category = CATEGORIES.includes(e.category as FoodCategory)
      ? (e.category as FoodCategory)
      : 'prepared_dish';

    items.push({
      name: name.slice(0, 120),
      category,
      portion: portion || `~${Math.round(grams)} g`,
      grams: clamp(grams, 1, 2000),
      confidence: clamp(toNumber(e.confidence ?? e.confidenceHint) ?? 0.5, 0, 1),
      per100g: sanitizePer100g(e.per100g ?? e.nutrition_per_100g ?? e.nutrition),
    });
  }
  return items.slice(0, 8);
}

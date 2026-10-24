// Validation of the model's meal plan, kept apart from the handler so it
// can be unit-tested (`node --test supabase/functions/generate-diet-plan/plan.test.ts`).
// No Deno APIs here.

import { clampNumber, cleanText, isObject, type JsonObject, LIMITS, RANGES } from "../_shared/validate.ts";

export const MAX_MEALS = 8;
export const MAX_ITEMS_PER_MEAL = 10;

/** Other dishes offered for each meal; the user can swap one in on the phone. */
export const ALTERNATIVES_PER_MEAL = 2;

/**
 * Most an alternative's calories may differ from its meal's (share of the
 * meal), so a swap keeps the day near its target. The prompt asks for 10%.
 */
export const ALTERNATIVE_CALORIE_TOLERANCE = 0.25;

export interface MealOption {
  items: string[];
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface Meal extends MealOption {
  name: string;
  alternatives: MealOption[];
}

export interface Plan {
  meals: Meal[];
  totalCalories: number;
  totalProtein: number;
  totalCarbs: number;
  totalFat: number;
}

const cal = (v: unknown) => Math.round(clampNumber(v, 0, RANGES.calories.max));
const grams = (v: unknown) => Math.round(clampNumber(v, 0, RANGES.grams.max));

function itemList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.slice(0, MAX_ITEMS_PER_MEAL).map((it) => cleanText(it, LIMITS.shortText)).filter(Boolean)
    : [];
}

function option(m: JsonObject): MealOption {
  return {
    items: itemList(m.items),
    calories: cal(m.calories),
    protein: grams(m.protein),
    carbs: grams(m.carbs),
    fat: grams(m.fat),
  };
}

/** Allergies from the preferences text ("peanuts, shellfish"), lower case. */
export function allergyList(allergies: string | undefined): string[] {
  return (allergies ?? "")
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

/** Whether any item names one of [allergies] (already lower case). */
export function containsAllergen(items: string[], allergies: string[]): boolean {
  return items.some((item) => {
    const lower = item.toLowerCase();
    return allergies.some((al) => lower.includes(al));
  });
}

const dishKey = (items: string[]) => items.map((i) => i.toLowerCase()).sort().join("|");

/**
 * Up to [ALTERNATIVES_PER_MEAL] usable alternatives for [main]: items
 * present, a different dish from the main one and from each other, no
 * allergen, and calories close enough to swap without moving the day off
 * target. Unusable ones are dropped rather than failing the plan: the
 * meal itself is fine, it just offers fewer options.
 */
function alternativesFor(raw: unknown, main: MealOption, allergies: string[]): MealOption[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set([dishKey(main.items)]);
  const out: MealOption[] = [];
  for (const entry of raw.filter(isObject)) {
    const alt = option(entry);
    if (alt.items.length === 0) continue;
    const key = dishKey(alt.items);
    if (seen.has(key)) continue;
    if (containsAllergen(alt.items, allergies)) continue;
    if (main.calories > 0 && Math.abs(alt.calories - main.calories) > main.calories * ALTERNATIVE_CALORIE_TOLERANCE) {
      continue;
    }
    seen.add(key);
    out.push(alt);
    if (out.length === ALTERNATIVES_PER_MEAL) break;
  }
  return out;
}

/**
 * Validates the model's plan: at least one meal, strings sanitised and
 * clipped, numbers clamped and rounded, alternatives checked (see
 * [alternativesFor]). Totals the model left out (or got the wrong type)
 * are summed from the meals' main dishes. Throws when there's nothing
 * usable.
 */
export function normalizePlan(raw: unknown, allergies: string[] = []): Plan {
  if (!isObject(raw) || !Array.isArray(raw.meals)) throw new Error("Plan has no meals array");
  const meals: Meal[] = raw.meals
    .filter(isObject)
    .slice(0, MAX_MEALS)
    .map((m: JsonObject, i: number) => {
      const main = option(m);
      return {
        name: cleanText(m.name, 40) || `Meal ${i + 1}`,
        ...main,
        alternatives: alternativesFor(m.alternatives, main, allergies),
      };
    })
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

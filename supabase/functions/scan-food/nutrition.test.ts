// Run with: node --test supabase/functions/scan-food/nutrition.test.ts
// (or `deno test supabase/functions/scan-food/nutrition.test.ts`)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  caloriesAgree,
  extractJson,
  nameSimilarity,
  normalizeVisionItems,
  parsePortionGrams,
  sanitizePer100g,
} from './nutrition.ts';

test('extractJson handles fences, think tags and surrounding prose', () => {
  assert.deepEqual(extractJson('```json\n{"items":[]}\n```'), { items: [] });
  assert.deepEqual(extractJson('<think>plate with {rice}</think>{"items":[{"name":"Idli"}]}'), {
    items: [{ name: 'Idli' }],
  });
  assert.deepEqual(extractJson('Here you go: {"a":"b}"} hope that helps'), { a: 'b}' });
  assert.throws(() => extractJson('no json'));
});

test('parsePortionGrams prefers explicit weights and knows Indian measures', () => {
  assert.equal(parsePortionGrams('2 rotis (~80 g)'), 80);
  assert.equal(parsePortionGrams('1 medium banana, ~118g'), 118);
  assert.equal(parsePortionGrams('250ml'), 250);
  assert.equal(parsePortionGrams('1 katori'), 150);
  assert.equal(parsePortionGrams('2 katoris of dal'), 300);
  assert.equal(parsePortionGrams('1.5 cups'), 360);
  assert.equal(parsePortionGrams('80.0 g'), 80);
  assert.equal(parsePortionGrams('1 pack (90g)'), 90);
  assert.equal(parsePortionGrams('something vague'), null);
});

test('parsePortionGrams does not read "2 glasses" as 2 grams', () => {
  assert.equal(parsePortionGrams('2 glasses of lassi'), 500);
  assert.equal(parsePortionGrams('3 gulab jamuns'), null);
});

test('sanitizePer100g repairs inconsistent calories and impossible macros', () => {
  const fixed = sanitizePer100g({ calories: 900, protein: 5, carbs: 15, fat: 4, fiber: 3, sodium: 300 })!;
  assert.ok(fixed.calories > 100 && fixed.calories < 120, `got ${fixed.calories}`);

  const scaled = sanitizePer100g({ calories: 400, protein: 60, carbs: 60, fat: 30 })!;
  assert.ok(scaled.protein + scaled.carbs + scaled.fat <= 100.0001);

  assert.equal(sanitizePer100g({ calories: 0, protein: 0, carbs: 0, fat: 0 }), null);
  assert.equal(sanitizePer100g(null), null);
  assert.equal(sanitizePer100g({ calories: '130 kcal', protein: '2.7g', carbs: 28, fat: 0.3 })!.calories, 130);
});

test('nameSimilarity folds Indian spelling variants', () => {
  assert.equal(nameSimilarity('Sambhar', 'Sambar'), 1);
  assert.equal(nameSimilarity('Chapati', 'Roti'), 1);
  assert.equal(nameSimilarity('Daal Tadka', 'Dal Tadka'), 1);
  assert.ok(nameSimilarity('Chicken Biriyani', 'Chicken Biryani') === 1);
  assert.ok(nameSimilarity('Paneer Tikka', 'Paneer Paratha') < 0.75);
  assert.ok(nameSimilarity('Dal Tadka', 'Dal Tadka (Yellow Dal)') >= 0.75);
  assert.ok(nameSimilarity('Chicken Curry', 'Chicken') < 0.75);
});

test('caloriesAgree catches raw-vs-cooked mismatches', () => {
  assert.equal(caloriesAgree(365, 130), false); // raw rice vs cooked rice
  assert.equal(caloriesAgree(89, 96), true);
});

test('normalizeVisionItems accepts both new and legacy shapes', () => {
  const items = normalizeVisionItems({
    items: [
      {
        name: 'Masala Dosa',
        category: 'prepared_dish',
        portion: '1 dosa (~170 g)',
        grams: 170,
        confidence: 0.9,
        per100g: { calories: 200, protein: 4, carbs: 30, fat: 7, fiber: 2, sugar: 1, sodium: 280 },
      },
      { name: '', grams: 10 },
    ],
  });
  assert.equal(items.length, 1);
  assert.equal(items[0].grams, 170);
  assert.ok(items[0].per100g);

  const legacy = normalizeVisionItems([
    { candidateName: 'Banana', estimatedPortionDescription: '1 medium, ~118g', confidenceHint: 0.95 },
  ]);
  assert.equal(legacy[0].name, 'Banana');
  assert.equal(legacy[0].grams, 118);
  assert.equal(legacy[0].category, 'prepared_dish');
  assert.equal(legacy[0].per100g, null);
});

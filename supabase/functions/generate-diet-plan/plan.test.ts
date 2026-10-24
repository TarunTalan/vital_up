// Run with: node --test supabase/functions/generate-diet-plan/plan.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { allergyList, containsAllergen, normalizePlan } from './plan.ts';

const meal = (extra: Record<string, unknown> = {}) => ({
  name: 'Breakfast',
  items: ['2 Besan Chilla', '1 Cup Curd'],
  calories: 400,
  protein: 20,
  carbs: 45,
  fat: 12,
  ...extra,
});

const alt = (items: string[], calories: number, protein = 18) => ({ items, calories, protein, carbs: 40, fat: 10 });

test('keeps two good alternatives per meal, cleaned and rounded', () => {
  const plan = normalizePlan({
    meals: [
      meal({
        alternatives: [
          alt(['1 Bowl Upma', ' 1 Glass Chaas '], 380.6),
          alt(['2 Moong Dal Dosa'], 420),
          alt(['1 Bowl Oats'], 400),
        ],
      }),
    ],
  });
  const alts = plan.meals[0].alternatives;
  assert.equal(alts.length, 2);
  assert.deepEqual(alts[0].items, ['1 Bowl Upma', '1 Glass Chaas']);
  assert.equal(alts[0].calories, 381);
  assert.deepEqual(alts[1].items, ['2 Moong Dal Dosa']);
});

test('drops alternatives that repeat a dish, have no items or are far off in calories', () => {
  const plan = normalizePlan({
    meals: [
      meal({
        alternatives: [
          alt(['1 cup curd', '2 besan chilla'], 400), // the main dish again
          alt([], 400),
          alt(['1 Plate Chole Bhature'], 900), // way over 400 kcal
          alt(['1 Bowl Poha'], 390),
          alt(['1 Bowl Poha'], 395), // repeats the one above
          'not an object',
        ],
      }),
    ],
  });
  assert.deepEqual(plan.meals[0].alternatives.map((a) => a.items), [['1 Bowl Poha']]);
});

test('alternatives naming an allergen are dropped, the meal stays', () => {
  const allergies = allergyList('Peanut, Cashew ');
  assert.deepEqual(allergies, ['peanut', 'cashew']);
  const plan = normalizePlan(
    {
      meals: [
        meal({
          alternatives: [alt(['1 Bowl Peanut Poha'], 400), alt(['Cashew Upma'], 410), alt(['2 Idli'], 380)],
        }),
      ],
    },
    allergies,
  );
  assert.deepEqual(plan.meals[0].alternatives.map((a) => a.items), [['2 Idli']]);
  assert.ok(containsAllergen(['Roasted PEANUTS'], allergies));
  assert.ok(!containsAllergen(['2 Idli'], allergies));
});

test('a meal without alternatives is still a meal; totals count main dishes only', () => {
  const plan = normalizePlan({
    meals: [meal(), meal({ name: 'Lunch', calories: 600, alternatives: [alt(['Rajma Rice'], 650)] })],
  });
  assert.deepEqual(plan.meals[0].alternatives, []);
  assert.equal(plan.totalCalories, 1000);
  assert.equal(plan.meals[1].alternatives.length, 1);
});

test('no usable meals still throws', () => {
  assert.throws(() => normalizePlan({ meals: [{ name: 'x', items: [] }] }));
  assert.throws(() => normalizePlan({}));
});

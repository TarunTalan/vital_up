// Vision + nutrition-estimate calls for scan-food, built on the shared
// self-healing LLM clients (see ../_shared/llm.ts for model fallback and
// discovery). Model lists are overridable with the GEMINI_MODELS and
// GROQ_VISION_MODELS secrets.

import { envList, extractJson, geminiGenerate, groqGenerate, ProviderError } from '../_shared/llm.ts';
import { normalizeVisionItems, sanitizePer100g, type Per100g, type VisionItem } from './nutrition.ts';

export type ProviderName = 'gemini' | 'groq';

const GROQ_DEFAULT_VISION_MODELS = ['qwen/qwen3.8-27b'];
const groqVisionModels = () => envList('GROQ_VISION_MODELS', GROQ_DEFAULT_VISION_MODELS);

// ---------------------------------------------------------------------------
// Prompts
// ---------------------------------------------------------------------------

export const VISION_PROMPT = `You are a registered dietitian and food-recognition expert with deep knowledge of every regional Indian cuisine (North, South, East, West, Northeast, street food, sweets) as well as global food.

Identify every distinct food or drink in the photo and estimate its nutrition.

Identification rules:
- One entry per distinct component. For a thali, combo or mixed plate, list each component separately (rice, each dal/curry/sabzi, roti, raita, salad, papad, pickle, sweet). Skip trivial garnishes (coriander, a lemon wedge, a few onion rings).
- Use the specific common name. For Indian food use the Indian name with the most specific variant visible, e.g. "Masala Dosa", "Rava Idli", "Dal Tadka", "Dal Makhani", "Rajma", "Chole", "Palak Paneer", "Aloo Gobi", "Bhindi Masala", "Jeera Rice", "Veg Pulao", "Hyderabadi Chicken Biryani", "Sambar", "Rasam", "Kadhi", "Poha", "Upma", "Pav Bhaji", "Gulab Jamun".
- Separate look-alikes carefully by texture, shape, colour and sheen: roti/chapati vs phulka vs paratha vs naan vs kulcha vs puri vs bhatura; dosa vs uttapam vs appam vs chilla; idli vs dhokla; dal vs sambar vs rasam vs kadhi; paneer vs tofu vs egg white; pulao vs biryani vs fried rice; chole vs rajma vs lobia; gulab jamun vs kala jamun; curd vs raita vs lassi.
- If the photo shows a packaged product, name the product and brand if readable.

Portion rules:
- Count countable items (rotis, idlis, puris, vadas, samosas, pieces) and include the count in "portion".
- Estimate edible weight in grams using visual references: dinner plate 25-28 cm, steel thali 30 cm, katori 150 ml, steel tumbler 250 ml, tea cup 120 ml, spoon/hand size.
- Typical weights: roti/chapati 35-40 g, phulka 25 g, plain paratha 60-80 g, stuffed paratha 100-130 g, naan 90-110 g, puri 25 g, bhatura 70 g, idli 40 g, medium vada 50 g, plain dosa 90 g, masala dosa 170 g, samosa 80 g, cooked rice 1 cup 160 g, katori of dal/curry 150 g, gulab jamun 40 g.

Nutrition rules:
- Give values per 100 g of the food AS SERVED (cooked, including its oil, ghee, butter, cream, sugar), NOT raw ingredients.
- For Indian dishes base values on IFCT 2017 / NIN recipe data for typical home or restaurant preparation; for others use USDA-style values.
- Adjust for what you see: visible oil pooling, glossy tadka, butter/cream topping, or deep-frying mean higher fat.
- sodium is in milligrams. calories should be consistent with 4/4/9 kcal per g of protein/carbs/fat.

confidence (0-1) is how sure you are of the identity. If there is no food or drink, return {"items": []}.

Return ONLY this JSON, no prose:
{"items":[{"name":"Dal Tadka","category":"prepared_dish","portion":"1 katori (~150 g)","grams":150,"confidence":0.86,"per100g":{"calories":110,"protein":5.5,"carbs":14,"fat":3.8,"fiber":3.2,"sugar":1,"sodium":300}}]}
category is one of: whole_food (single raw/simple item such as fruit, boiled egg, plain nuts), prepared_dish, packaged, beverage.`;

export function nutritionEstimatePrompt(foodName: string): string {
  return `You are a dietitian. Give typical nutrition per 100 g AS SERVED for "${foodName}".
If it is an Indian dish use IFCT 2017 / NIN values for typical home preparation (including cooking oil/ghee); otherwise use USDA-style values.
sodium is in mg. Return ONLY JSON: {"calories":0,"protein":0,"carbs":0,"fat":0,"fiber":0,"sugar":0,"sodium":0}`;
}

// ---------------------------------------------------------------------------
// Vision providers + hedged fallback chain
// ---------------------------------------------------------------------------

export interface VisionProvider {
  readonly name: ProviderName;
  recognize(imageBase64: string, mimeType: string, signal: AbortSignal): Promise<VisionItem[]>;
}

export class GeminiVisionProvider implements VisionProvider {
  readonly name = 'gemini' as const;
  constructor(private apiKey: string) {}

  async recognize(imageBase64: string, mimeType: string, signal: AbortSignal): Promise<VisionItem[]> {
    const text = await geminiGenerate(
      this.apiKey,
      [{ text: VISION_PROMPT }, { inline_data: { mime_type: mimeType, data: imageBase64 } }],
      { signal, json: true },
    );
    try {
      return normalizeVisionItems(extractJson(text));
    } catch (e) {
      throw new ProviderError('parse', `Gemini output unparseable: ${(e as Error).message}`);
    }
  }
}

export class GroqVisionProvider implements VisionProvider {
  readonly name = 'groq' as const;
  constructor(private apiKey: string) {}

  async recognize(imageBase64: string, mimeType: string, signal: AbortSignal): Promise<VisionItem[]> {
    const text = await groqGenerate(
      this.apiKey,
      [
        { type: 'text', text: VISION_PROMPT },
        { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
      ],
      { models: groqVisionModels(), capability: 'vision', signal, json: true },
    );
    try {
      return normalizeVisionItems(extractJson(text));
    } catch (e) {
      throw new ProviderError('parse', `Groq output unparseable: ${(e as Error).message}`);
    }
  }
}

/**
 * Starts the first provider and only brings in the next one if the current
 * one fails or is still running after [hedgeAfterMs]. This keeps free-tier
 * usage to one provider per scan in the common case while capping tail
 * latency when a provider is slow. First success wins; losers are aborted.
 */
export function recognizeHedged(
  providers: VisionProvider[],
  imageBase64: string,
  mimeType: string,
  { hedgeAfterMs = 9000, timeoutMs = 30000 } = {},
): Promise<{ items: VisionItem[]; servedBy: ProviderName }> {
  return new Promise((resolve, reject) => {
    if (providers.length === 0) {
      reject(new Error('All vision providers failed | no providers configured'));
      return;
    }
    const errors: string[] = [];
    const controllers: AbortController[] = [];
    let next = 0;
    let pending = 0;
    let settled = false;
    let hedgeTimer: ReturnType<typeof setTimeout> | undefined;

    const finish = () => {
      settled = true;
      clearTimeout(hedgeTimer);
      controllers.forEach((c) => c.abort());
    };

    const launch = () => {
      if (settled || next >= providers.length) return;
      const provider = providers[next++];
      const controller = new AbortController();
      controllers.push(controller);
      const timeout = setTimeout(() => controller.abort(), timeoutMs);
      pending++;
      clearTimeout(hedgeTimer);
      if (next < providers.length) hedgeTimer = setTimeout(launch, hedgeAfterMs);
      console.log(`Vision: starting ${provider.name}`);

      provider
        .recognize(imageBase64, mimeType, controller.signal)
        .then((items) => {
          if (settled) return;
          finish();
          resolve({ items, servedBy: provider.name });
        })
        .catch((e) => {
          errors.push(`${provider.name}: ${(e as Error).message}`);
          console.warn(`Vision: ${provider.name} failed: ${(e as Error).message}`);
        })
        .finally(() => {
          clearTimeout(timeout);
          pending--;
          if (settled) return;
          if (next < providers.length) {
            launch();
          } else if (pending === 0) {
            finish();
            reject(new Error(`All vision providers failed | ${errors.join(' || ')}`));
          }
        });
    };

    launch();
  });
}

// ---------------------------------------------------------------------------
// Text-only nutrition estimate (manual entries / poor database matches)
// ---------------------------------------------------------------------------

export async function estimateNutritionPer100g(
  foodName: string,
  keys: { gemini?: string; groq?: string },
  timeoutMs = 12000,
): Promise<Per100g | null> {
  const prompt = nutritionEstimatePrompt(foodName);
  const signal = AbortSignal.timeout(timeoutMs);
  const attempts: Array<() => Promise<string>> = [];
  if (keys.gemini) attempts.push(() => geminiGenerate(keys.gemini!, [{ text: prompt }], { signal, json: true, maxOutputTokens: 1024 }));
  if (keys.groq) {
    attempts.push(() =>
      groqGenerate(keys.groq!, prompt, { models: groqVisionModels(), capability: 'vision', signal, json: true })
    );
  }

  for (const run of attempts) {
    try {
      const per100g = sanitizePer100g(extractJson(await run()));
      if (per100g) return per100g;
    } catch (e) {
      console.warn(`Nutrition estimate for "${foodName}" failed: ${(e as Error).message}`);
    }
  }
  return null;
}

# VitalUp — Food Scan Feature: Implementation Prompt (v4, free-stack + Groq fallback + Supabase + premium tier)

Paste this whole document as your instruction to Claude Code (or a fresh Claude session with repo access). It is written to be self-contained.

---

## 0. Scope note — most of the feature already exists

Domain layer, BLoC (events/states), presentation widgets, and use cases for `food_scan` are **already built** in the repo. Do not regenerate them from scratch. Your job on this pass is narrower:

1. **Verify** the existing domain contracts (`FoodRecognitionRepository`, `NutritionRepository`, entities) are compatible with the free data sources below. If a method signature assumes FatSecret-specific fields, flag it and propose the minimal signature change — don't rewrite the interface wholesale.
2. **Implement the data layer** against the free stack (this is the main deliverable of this pass).
3. **Build the backend proxy as a Supabase Edge Function**, including a **first-class Gemini→Groq fallback chain**, not a bolted-on afterthought.
4. **Wire DI** for the new/changed data sources only.
5. Leave BLoC, presentation, and use cases untouched unless a data-layer change forces a signature update — if so, make the smallest possible edit and say explicitly what changed and why.
6. **Gate the premium-only parts of the flow** per §11, using the existing failure-type convention rather than ad-hoc booleans scattered through the UI, and using Supabase Postgres + RLS as the source of truth for entitlement.

**Note on existing Supabase usage:** since Supabase is already the backend for this project, this pass should reuse the existing Supabase project, existing Auth setup, and existing Postgres conventions (migrations folder, RLS patterns already in use elsewhere in the repo) rather than introducing a second backend. If the repo already has a `supabase/functions` directory with a naming/deployment convention, match it exactly — don't invent a new one.

If anything below conflicts with what's already in the repo, stop and show me the conflict before proceeding — don't silently pick one.

---

## 1. Context

VitalUp is a Flutter fitness app using **clean architecture** (domain / data / presentation layers) and the **BLoC pattern**, with a **feature-based directory structure**. `activity_tracking` and `activity_history` already follow these conventions — match their structure, naming, and DI registration pattern exactly.

## 2. Backend choice — free stack, no paid recognition API

The original plan (FatSecret Image Recognition) requires a paid/gated Platform API. Replace it with a **fully free** combination:

| Purpose | Service | Cost | Notes |
|---|---|---|---|
| Food identification from photo (primary) | **Google Gemini API** (`gemini-2.5-flash` or `gemini-3-flash`, whichever is current in AI Studio) | Free tier, no card required | Vision-capable — send the image, get back a structured list of *candidate food names + rough portion guess*, nothing more |
| Food identification from photo (fallback) | **Groq API**, vision-capable Llama model (currently `meta-llama/llama-4-maverick-17b-128e-instruct`) | Free tier, no card required | Same constrained JSON-only prompt as Gemini. Used only when Gemini returns a quota/429 error, so the feature doesn't go down when Google trims free-tier limits again |
| Nutrition numbers | **USDA FoodData Central API** | Free, free API key, ~1,000 req/hour/IP | Authoritative nutrient database (300k+ foods), public domain data |
| Barcode → packaged food | **Open Food Facts** | Free, no auth | Unchanged from original plan |
| Proxy hosting | **Supabase Edge Functions** (Deno runtime) | Free tier included with existing Supabase project | Same project you already use for Auth/Postgres — no second backend to provision or pay for |
| Auth for the proxy | **Supabase Auth** | Already in use | JWT issued by Supabase Auth is verified inside the Edge Function; no separate identity system |
| Entitlement/quota storage | **Supabase Postgres** (with RLS) | Already in use | Source of truth for premium status and scan counts — see §11 |

**Why a fallback matters here specifically:** Gemini's free-tier request limits have been cut significantly more than once in the past several months, without much notice. Neither provider's free tier is contractually guaranteed, so the proxy should not have a single point of failure. Groq's free tier has recently run steadier and its vision-capable Llama models are a reasonable same-shape substitute for the identification step only — it never touches nutrition numbers, same as Gemini.

**Why this still needs a thin proxy, even without OAuth signing:**
- The Gemini API key, Groq API key, and USDA API key must not be embedded in the compiled app (extractable from APK/IPA).
- A proxy lets you cache identical-image lookups, apply your own rate limiting so one abusive client can't burn your daily Gemini/Groq/USDA quota, and normalize responses before they hit Dio in the Flutter app.
- The proxy is simpler than the original FatSecret version: no request-signing, just "hold the keys server-side and forward."
- Running it as a **Supabase Edge Function** means it shares auth (Supabase Auth JWTs), shares the database (Postgres) for quota/entitlement checks, and shares deployment tooling (`supabase functions deploy`) with the rest of the project — no separate cloud project, no separate IAM model, no separate secrets manager to keep in sync.

**Critical accuracy rule — unchanged from the original spec, and more important now:** Gemini (or Groq, when serving as fallback) is used **only** to identify *what* the food probably is (a name + optional portion guess), never to state calorie/macro numbers. All numeric nutrition must come from a **matched USDA FDC record** (or Open Food Facts for barcodes). If the model's suggested name doesn't match anything in USDA's search results with reasonable confidence, surface it as a low-confidence match requiring user correction — never fall back to letting either model estimate numbers.

### 2.1 Recognition flow (provider-chain, explicit)

1. Flutter app uploads the compressed image to the Supabase Edge Function, authenticated with the user's existing Supabase session JWT (standard `Authorization: Bearer <token>` header — same pattern already used for other authenticated calls in the app).
2. The Edge Function calls a **`VisionProviderChain`** — a small chain-of-responsibility abstraction with two concrete providers (`GeminiVisionProvider`, `GroqVisionProvider`) that share one interface:
   ```
   interface VisionProvider {
     recognize(imageBytes): Promise<{ candidateName, estimatedPortionDescription, confidenceHint }[]>
   }
   ```
   Both implementations are prompted with the **identical constrained JSON-only prompt template** and must return the **identical response shape** — no nutrition fields at all, so there's no temptation to consume model-generated numbers downstream.
3. The chain calls Gemini first. **On a 429/quota error (or Gemini-specific equivalent), it immediately retries the same request against Groq**, using the same prompt template. The caller (Flutter app) never needs to know which provider actually served the request — the chain returns a normalized result plus an internal `servedBy: "gemini" | "groq"` tag used only for logging/metrics, never surfaced to the client.
4. If **both** providers are rate-limited or fail, the chain throws/returns a distinct `RecognitionUnavailableFailure` (not a generic `ServerFailure`) so the UI can show "recognition is temporarily busy, try again shortly" rather than a scary error.
5. The Edge Function takes each `candidateName` and queries **USDA FDC `/foods/search`** to find the closest matching food record.
6. If USDA has no good match, mark that item `NoFoodDetectedFailure`/low-confidence for that item specifically (per the partial-recognition rule in §8) rather than failing the whole scan.
7. Nutrition numbers returned to the domain layer always come from the matched FDC record's nutrients, scaled to the user-adjusted portion — never from Gemini's or Groq's output, regardless of which one served the request.

### 2.2 Proxy responsibilities (Supabase Edge Function)

- Implement as a Supabase Edge Function (Deno/TypeScript), e.g. `supabase/functions/scan-food/index.ts`, deployed via the Supabase CLI alongside any other Edge Functions already in the repo.
- Verify the caller's Supabase Auth JWT on every request (`supabase.auth.getUser(token)` inside the function, using the service-role or anon client as appropriate) — reject unauthenticated requests before doing any recognition work.
- Accept image (multipart or base64) over HTTPS from the Flutter app.
- Implement `VisionProviderChain` as described in §2.1 — one shared parsing/validation code path for both providers, not two parallel implementations.
- Call Gemini vision with the constrained JSON-only prompt; validate the response is well-formed JSON before returning it (reject/retry once on malformed output, same rule for whichever provider is currently serving the request — see §8).
- On a Gemini quota/429 error, fall back to the Groq vision model with the same prompt template and expected JSON shape.
- **Log `servedBy` (Gemini vs Groq) plus latency and any retry count for every recognition request.** Write this to a Postgres table (e.g. `recognition_logs`) rather than only console logs — cheap to add now, useful later for noticing when Gemini's free tier has quietly gotten stingier, and useful for the premium-tier quota enforcement in §11.
- Call USDA FDC search server-side (keeps the USDA key off the client too), and cache repeated searches for common foods (e.g. "banana", "grilled chicken breast") in a small Postgres cache table (`food_search_cache`) keyed by normalized query string, with a TTL check done in application code (Edge Functions don't have a built-in cache layer, so a table is simplest given Postgres is already there).
- Store `GEMINI_API_KEY_FOOD_SCANNER`, `GROQ_API_KEY_FOOD_SCANNER`, and `USDA_FDC_API_KEY` as **Supabase Edge Function secrets** (`supabase secrets set ...`), never in client code or committed config.
- Return normalized JSON to the app: candidate items with FDC IDs attached where matched, so the app never has to re-search. **Do not include `servedBy` in the client-facing payload** — it's a server-side log field only.
- Before doing any recognition work, check the caller's scan quota (see §11.2) via a Postgres query/RPC — reject over-quota requests with HTTP 402/403 before spending a Gemini/Groq call.

Do not call Gemini, Groq, or USDA directly from Dio in the Flutter client — flag this explicitly if asked to skip the proxy.

## 3. Domain layer — verify only, don't rebuild

Confirm these still match, adjusting only if the free-stack swap requires it:

- `FoodItem { id, name, confidenceScore, servingDescription, quantity, unit }`
- `NutritionInfo { calories, proteinG, carbsG, fatG, fiberG, sugarG, sodiumMg, per: FoodItem }`
- `MealLogEntry { id, capturedAt, imagePath, items, nutrition, totalCalories, mealType, userConfirmed }`
- `MealRecommendation { message, reasonTags }`
- Repository interfaces: `FoodRecognitionRepository.recognizeFood(File image)`, `NutritionRepository.getNutrition(FoodItem)` / `lookupBarcode(String)`, `MealLogRepository`, `MealRecommendationRepository`
- Use cases: `ScanFoodImage`, `ScanBarcode`, `SaveMealLog`, `GetMealLogHistory`, `DeleteMealLog`, `GetMealRecommendation`

**The domain layer should never know which vision provider served a request.** `servedBy` is a data-layer/proxy logging concern only — don't add it to `FoodItem` or any domain entity.

If `NutritionRepository` needs a new method like `searchByName(String query)` for the autocomplete-correction flow (§6.2) and it isn't already there, add just that method — don't touch anything else in the interface.

Keep using the project's existing `Either<Failure, T>` convention (check `activity_history` use cases) — don't introduce a second error-handling style.

## 4. Data layer (`lib/features/food_scan/data`) — main implementation target

- **DTOs**: map the proxy's response shape (recognition candidates + attached FDC IDs) and raw USDA FDC nutrient records to domain entities. Never let raw Gemini/Groq or FDC JSON leak past the repository boundary. The candidate DTO should be provider-agnostic in shape — `RecognitionCandidateDto { candidateName, estimatedPortionDescription, confidenceHint, fdcIdIfMatched }` — since Gemini and Groq are normalized to the same shape upstream in the Edge Function; the Flutter data layer should not need a `provider` field at all.
- **`FoodRecognitionRepositoryImpl`**: calls the Supabase Edge Function via Dio (image upload) or the `supabase_flutter` client's `functions.invoke(...)` if the repo already standardizes on that for other Edge Functions — match whichever pattern `activity_history` or other features already use for Supabase calls. Maps HTTP/timeout/parse errors to typed `Failure` subclasses (`NetworkFailure`, `NoFoodDetectedFailure`, `LowConfidenceFailure`, `RecognitionUnavailableFailure`, `ServerFailure`).
- **`NutritionRepositoryImpl`**:
  - `getNutrition(FoodItem)` → looks up the attached FDC ID (from recognition) via USDA `/food/{fdcId}`, or if missing, searches `/foods/search` by name; maps the nutrient array to `NutritionInfo`.
  - `searchByName(String query)` → USDA `/foods/search`, used for the manual-correction autocomplete.
  - `lookupBarcode(String barcode)` → Open Food Facts product lookup, unchanged from original plan.
- **`MealLogLocalDataSource`**: reuse whatever local DB `activity_history` already uses (Hive/sqflite/Isar) for on-device caching, and — if `activity_history` already syncs to Supabase Postgres — follow that same sync pattern for meal logs (e.g. a `meal_logs` table with a foreign key to `auth.users`, RLS policies scoping rows to `auth.uid()`). Don't introduce a second local DB dependency, and don't introduce a second sync strategy if one already exists.
- Cache recent scans in memory for the session to avoid duplicate network calls on repeated "retry" taps with the same image.

## 5–7. Presentation, accuracy safeguards, recommendation logic

Unchanged from the original spec — these layers are already built and don't need modification for the backend swap, since the domain contract (`FoodItem`, `NutritionInfo`, confidence scores) stays the same shape regardless of which recognition service (Gemini or Groq) produced it, and regardless of the proxy hosting change from Firebase to Supabase. Specifically still required and already assumed in place:

- Confidence badge + "please confirm" flag below ~70%.
- Editable food name with autocomplete (now backed by `NutritionRepository.searchByName` against USDA).
- Portion/quantity adjustment before saving.
- Multiple detected items per photo.
- Pre-capture image quality tip.
- Rule-based `MealRecommendation` logic, pure function, no I/O, swappable behind its interface.

If you find the presentation layer currently expects fields FatSecret would have provided that USDA/Gemini/Groq don't (e.g. a branded-product name, a FatSecret-specific ID), flag those specifically rather than silently stubbing them.

## 8. Error handling checklist — add four new cases (Gemini + Groq specific)

Everything from the original checklist still applies (no-internet at capture, proxy timeout, non-food image, partial recognition, duplicate save debounce, backgrounded upload, barcode-not-found fallback, client-side image compression, `emit.isDone`/`emit.forEach` correctness, full test coverage). Add:

- **Gemini returns malformed/non-JSON output** → Edge-Function-side retry once against Gemini, then fall through to Groq (treat it like a quota failure for chain purposes) rather than surfacing an error immediately.
- **Groq (as fallback) also returns malformed/non-JSON output**, after Gemini already failed → Edge-Function-side retry once against Groq, then surface `ServerFailure` (both providers exhausted) rather than crashing the parse step.
- **Both Gemini and Groq are quota-exceeded/erroring in the same request** → `RecognitionUnavailableFailure`, distinct from `ServerFailure`, so the UI copy can say "try again shortly" instead of a generic error.
- **Gemini/Groq candidate name has no USDA match at all** (regardless of which provider produced the candidate) → treat as `NoFoodDetectedFailure` for that specific item (not the whole scan), and let the user manually search/select via `searchByName`.

**Test coverage to add specifically for the fallback chain:**
- Mock Gemini returning 429 → assert Groq is called next with the identical prompt/image payload, and that the normalized DTO shape is indistinguishable from a Gemini-served response.
- Mock both Gemini and Groq failing → assert `RecognitionUnavailableFailure` propagates to the BLoc/UI, not a raw HTTP exception.
- Mock Gemini malformed JSON → assert single retry against Gemini before falling through to Groq.
- Mock an unauthenticated request (missing/invalid Supabase JWT) → assert the Edge Function rejects it before any Gemini/Groq call is made.
- Mock a caller who is over their free-tier quota → assert the Edge Function rejects with 402/403 before any Gemini/Groq call is made (see §11.2).

## 9. Dependency injection

Register the new/changed data sources following the exact pattern already used for `ActivityHistoryBloc` and its dependencies in `injection_container.dart`. Only the data-layer bindings should change; leave existing bloc/use case registrations alone unless a signature changed in §3.

Note: `GeminiVisionProvider` and `GroqVisionProvider` live in the **Supabase Edge Function**, not in the Flutter DI container — the Flutter app only ever registers a Dio client (or the existing `supabase_flutter` client, matching however other Edge Function calls are wired in the repo) pointed at the Edge Function's single recognition endpoint. Don't add Gemini/Groq SDK dependencies to `pubspec.yaml`.

## 10. Deliverable format

Implement file-by-file, in full, in the conversation (not as a zip/archive):
1. Any domain-layer diffs from §3 (should be minimal or none) — show these first so I can approve before you build on top of them.
2. Data layer in full (§4).
3. Supabase Edge Function proxy in full (`supabase/functions/scan-food/index.ts` or matching repo convention), including the `VisionProviderChain`, both provider implementations, the shared prompt template, USDA search/match logic, JWT verification, and quota check.
4. SQL migrations for any new Postgres tables (`recognition_logs`, `food_search_cache`, `subscriptions`/`scan_quota` — see §11) including RLS policies, in full.
5. DI wiring diff.
6. Premium-gating diff from §11.2 (use case + failure type + Postgres/RLS + RevenueCat webhook Edge Function — see §11.2 for exactly what's expected here).

Do not re-emit unchanged BLoC/presentation files — reference them by path only if relevant.

---

## 11. Premium tier — feature gating, enforcement, tech stack, and pricing

This section is a product/monetization addendum. §11.1–11.2 are implementation guidance for this coding pass; §11.3 is a business recommendation, not something Claude Code needs to build.

### 11.1 What to gate (and what not to)

Photo-based recognition is the only part of this feature with real marginal cost risk (API rate limits, potential future paid tiers if you outgrow Gemini/Groq/USDA free quotas) and the only part that feels like a "wow" feature users will pay for. Barcode lookup and manual entry are free, unlimited, and should stay that way — Open Food Facts has no meaningful cost ceiling, and a generous free tier is what gets people using VitalUp daily long enough to convert.

Recommended split:

| Free | Premium |
|---|---|
| Unlimited barcode scanning (Open Food Facts) | Everything in Free |
| Unlimited manual food entry + search | Unlimited photo scans (no monthly cap) |
| Photo scanning capped (e.g. 5–10 scans/month) | Multi-item detection per photo (free tier: single best-guess item only) |
| Single best-guess item per photo | Full meal-log history & trends (weekly/monthly nutrition analytics) |
| Meal log history capped (e.g. last 30 days) | Rule-based `MealRecommendation` insights |
| Basic `MealRecommendation` message | Data export (CSV/PDF) |

This mirrors how MyFitnessPal, Cronometer, and Lose It all structure their free/paid split — the AI-assisted logging convenience (photo scan, faster entry) is the thing behind the paywall, not the underlying nutrition data itself.

### 11.2 Premium tech stack and enforcement — client check is UX, server check is the real gate

**Full tech stack for the premium tier:**

| Layer | Tech | Role |
|---|---|---|
| Subscription purchase & receipt validation | **RevenueCat** (wrapping StoreKit on iOS, Play Billing on Android) | Handles the actual purchase flow and cross-platform receipt validation — don't build custom receipt validation |
| Entitlement source of truth | **Supabase Postgres** table, e.g. `subscriptions(user_id, is_premium, product_id, expires_at, updated_at)` with RLS scoping rows to `auth.uid()` for reads, service-role only for writes | The proxy and the app both check this table/RPC, not RevenueCat's API directly, so there's a single fast local source of truth |
| Sync between RevenueCat and Supabase | **RevenueCat webhook → Supabase Edge Function** (e.g. `supabase/functions/revenuecat-webhook/index.ts`) | RevenueCat calls this Edge Function on purchase/renewal/cancellation/expiration events; the function verifies RevenueCat's webhook signature, then upserts the `subscriptions` row for that user |
| Quota tracking (free tier) | **Supabase Postgres** table, e.g. `scan_usage(user_id, month, scan_count)`, incremented via an RPC (`increment_scan_count`) called from inside the `scan-food` Edge Function, guarded by a `SECURITY DEFINER` function so the client can't tamper with its own count | Server-side counting is the enforcement point — the client only ever reads a remaining-count number for UX |
| Client-side subscription state | `SubscriptionRepository` in Flutter, backed by the RevenueCat SDK (`purchases_flutter`) for purchase UI/restore, and a Supabase query/RPC for the authoritative `isPremium()`/`remainingFreeScans()` read | RevenueCat SDK is for the purchase flow only; entitlement checks read from Supabase so there's one source of truth the whole app agrees on |

**Enforcement flow:**

- Add a `ScanQuotaExceededFailure` (or `PremiumRequiredFailure`) to the existing `Failure` hierarchy, distinct from `NetworkFailure`/`ServerFailure`, so the BLoC can emit a state the presentation layer turns into an upsell sheet rather than a generic error toast.
- `ScanFoodImage` use case should check remaining quota (via `SubscriptionRepository.remainingFreeScans()` or `isPremium()`, both backed by a Supabase query/RPC) **before** invoking `FoodRecognitionRepository`, to avoid burning a Gemini/Groq call for a request you're going to reject anyway.
- **Do the real enforcement inside the `scan-food` Edge Function, keyed to the authenticated Supabase user ID (`auth.uid()` from the verified JWT), not just client-side.** A client-only check is trivially bypassed by anyone who patches the APK or replays the request directly against your Edge Function URL. The Edge Function queries `subscriptions`/`scan_usage` before calling Gemini/Groq and rejects over-quota, non-premium requests with a 402/403 independent of what the Flutter client believes its own state is.
- Because both the free-scan quota check and the premium-status check live in the same Postgres database as the rest of the app's data, there is no separate identity/billing backend to keep in sync beyond the single RevenueCat webhook — this is the main practical advantage over a split Firebase/RevenueCat setup.
- Use RevenueCat rather than building your own receipt validation — App Store/Play Store policy requires digital subscriptions to go through their billing, and RevenueCat's webhook is what keeps the Supabase `subscriptions` table current without your Edge Function needing to talk to Apple/Google directly.

**Minimal SQL to include in the migration deliverable (§10.4):**
- `subscriptions` table + RLS (owner can `select` own row; only service role can `insert`/`update`).
- `scan_usage` table + a `SECURITY DEFINER` RPC to increment/check count, so client code can never directly write its own usage row.
- Indexes on `user_id` for both tables (lookups happen on every scan request).

### 11.3 Pricing recommendation

Since Gemini, Groq, and USDA are all free-tier at low-to-moderate scale, your actual per-scan cost is close to $0 until you have enough users to blow through those free quotas — so price should be set by competitive positioning and perceived value, not by cost-recovery math. Current 2026 pricing for comparable nutrition-tracking apps:

- **MyFitnessPal Premium**: $79.99/year ($19.99/month) — the largest food database and the most recognized brand, but has been pushing prices up while trimming free-tier features.
- **Cronometer Gold**: roughly $49.99/year (~$4.99/month on the annual plan) — positioned as the mid-tier, micronutrient-focused option.
- **Lose It! Premium**: $39.99/year — generally the cheapest of the well-known mainstream trackers, focused on fast logging rather than nutrient depth.

Given VitalUp doesn't yet have MyFitnessPal's brand weight or Cronometer's micronutrient-depth differentiator, pricing at the very top of that range would be hard to justify on day one. A reasonable launch position:

- **$4.99/month or $39.99–$44.99/year** — undercuts MyFitnessPal noticeably, sits right around Cronometer/Lose It, and is low-friction enough that the "unlimited AI photo scans" pitch alone can justify it without needing a huge feature list to back it up.
- Keep a monthly option even though annual is where the margin is — most competitors researched above lead with monthly pricing and only reveal the annual discount on the pricing page, which is standard practice for this category.
- Consider a 7-day free trial gated behind "first time using Premium" (also standard across MyFitnessPal/Cronometer/Lose It) rather than a discount code, since trials convert better than promo pricing for this kind of feature-unlock (not a raw discount) purchase.

As you get usage data, revisit the free-tier scan cap and the `scan_usage` reset logic (a scheduled Supabase cron job or Edge Function running monthly is the simplest way to roll the counter over, rather than computing "this month" on every request).

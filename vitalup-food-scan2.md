# Food Scan Feature - Free Version Implementation Summary

This document summarizes the implementation of the free version of the food scan feature using Gemini, Groq, USDA FDC, and Supabase Edge Functions.

## What Was Implemented

### 1. Domain Layer Changes
- **File**: `lib/core/error/failures.dart`
    - Added `RecognitionUnavailableFailure` - for when both Gemini and Groq are unavailable
    - Added `ScanQuotaExceededFailure` - for when free tier quota is exceeded

- **File**: `lib/features/food_scan/domain/repositories/nutrition_repository.dart`
    - Added `searchByName(String query)` method for manual food search autocomplete

- **File**: `lib/features/food_scan/domain/repositories/subscription_repository.dart` (NEW)
    - Created interface for subscription management
    - Methods: `isPremium()`, `remainingFreeScans()`, `refreshSubscriptionStatus()`

- **File**: `lib/features/food_scan/domain/usecases/scan_food_image.dart`
    - Added quota check before making API calls
    - Integrated `SubscriptionRepository` dependency

### 2. Data Layer Changes
- **File**: `lib/features/food_scan/data/models/food_item_dto.dart`
    - Added `fdcId` field to store USDA FoodData Central ID
    - Updated JSON serialization to handle the new field

- **File**: `lib/features/food_scan/data/repositories/food_recognition_repository_impl.dart`
    - Replaced direct Dio calls with Supabase Edge Function calls
    - Removed `DioClient` dependency, uses `SupabaseClient` instead
    - Sends base64-encoded images to `scan-food` Edge Function
    - Handles 402/403 status codes for quota exceeded
    - Handles 503 status code for recognition unavailable

- **File**: `lib/features/food_scan/data/repositories/nutrition_repository_impl.dart`
    - Updated to use Supabase Edge Function for USDA API calls
    - Added `searchByName()` implementation using Edge Function
    - Kept Open Food Facts barcode lookup (direct API call)

- **File**: `lib/features/food_scan/data/repositories/subscription_repository_impl.dart` (NEW)
    - Implements subscription status checks via Supabase RPC functions
    - Calls `is_premium_user()` and `get_remaining_scans()` PostgreSQL functions

### 3. Dependency Injection
- **File**: `lib/core/di/injection_container.dart`
    - Registered `SubscriptionRepository` and `SubscriptionRepositoryImpl`
    - Updated `FoodRecognitionRepository` to use `SupabaseClient` instead of `DioClient`
    - Updated `NutritionRepository` to use `Dio` directly and `SupabaseClient`
    - Updated `ScanFoodImage` use case to include `SubscriptionRepository`

### 4. Supabase Edge Functions

#### scan-food Function
- **Location**: `supabase/functions/scan-food/index.ts`
- **Features**:
    - VisionProviderChain with Gemini (primary) and Groq (fallback)
    - JWT authentication verification
    - Quota checking before processing
    - USDA FDC API integration for nutrition data
    - Food search cache in Postgres
    - Recognition logging for analytics
    - Handles image recognition, manual search, and nutrition lookup

#### revenuecat-webhook Function
- **Location**: `supabase/functions/revenuecat-webhook/index.ts`
- **Features**:
    - Webhook signature verification
    - Handles RevenueCat subscription events (purchase, renewal, cancellation, etc.)
    - Updates `subscriptions` table in Postgres
    - Maps RevenueCat user IDs to Supabase user IDs

### 5. Database Schema
- **File**: `supabase/migrations/20240706_food_scan_tables.sql`
- **Tables**:
    - `recognition_logs` - Tracks which vision provider served each request
    - `food_search_cache` - Caches USDA search results
    - `subscriptions` - Stores premium subscription status
    - `scan_usage` - Tracks monthly scan quota usage
- **Functions**:
    - `increment_scan_count(p_user_id, p_month)` - SECURITY DEFINER function to increment scan count
    - `get_remaining_scans(p_user_id)` - Returns remaining free scans (-1 for unlimited)
    - `is_premium_user(p_user_id)` - Checks if user has active premium subscription
    - `cleanup_expired_cache()` - Cleans up expired cache entries
- **RLS Policies**: All tables have appropriate Row Level Security policies

## Deployment Steps

### 1. Run Database Migration
```bash
supabase db push
```

### 2. Set Edge Function Secrets
```bash
# For scan-food function
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
supabase secrets set GROQ_API_KEY=your_groq_api_key
supabase secrets set USDA_FDC_API_KEY=your_usda_api_key

# For revenuecat-webhook function
supabase secrets set REVENUECAT_WEBHOOK_SECRET=your_webhook_secret
```

### 3. Deploy Edge Functions
```bash
supabase functions deploy scan-food
supabase functions deploy revenuecat-webhook
```

### 4. Configure RevenueCat
1. Set up RevenueCat project in RevenueCat dashboard
2. Configure products (monthly/yearly subscriptions)
3. Set webhook URL to: `https://your-project.supabase.co/functions/v1/revenuecat-webhook`
4. Add webhook secret to Supabase secrets

### 5. Update Flutter Dependencies
No new dependencies required - existing packages are sufficient:
- `supabase_flutter` - Already in pubspec.yaml
- `dio` - Already in pubspec.yaml

## API Keys Required

### Gemini API Key
- Get from: https://aistudio.google.com/app/apikey
- Free tier available
- Used for primary food recognition

### Groq API Key
- Get from: https://console.groq.com/keys
- Free tier available
- Used as fallback when Gemini is rate-limited

### USDA FDC API Key
- Get from: https://api.data.gov/signup/
- Free, ~1,000 requests/hour per IP
- Used for nutrition data

### RevenueCat Webhook Secret
- Get from RevenueCat dashboard
- Used to verify webhook signatures

## Free Tier Limits

### Current Configuration
- **Free tier scans**: 10 per month per user
- **Premium**: Unlimited scans
- **Multi-item detection**: Available for premium only (not yet implemented in UI)
- **Meal log history**: 30 days for free (not yet implemented in UI)

## Testing Checklist

### Unit Tests Needed
- [ ] Test `SubscriptionRepositoryImpl` methods
- [ ] Test quota checking logic in `ScanFoodImage`
- [ ] Test new failure types
- [ ] Test `FoodItemDto` with `fdcId` field

### Integration Tests Needed
- [ ] Test Edge Function with mock Gemini/Groq responses
- [ ] Test fallback chain (Gemini → Groq)
- [ ] Test quota enforcement
- [ ] Test webhook signature verification
- [ ] Test USDA API integration

### Manual Testing
- [ ] Test image recognition with real photos
- [ ] Test manual food search
- [ ] Test barcode scanning
- [ ] Test quota exceeded flow
- [ ] Test premium upgrade flow

## Known Limitations

1. **RevenueCat SDK Integration**: The Flutter app doesn't yet have the RevenueCat SDK integrated. This is needed for:
    - In-app purchase UI
    - Subscription restoration
    - Receipt validation on client side

2. **Premium UI**: The UI doesn't yet distinguish between free and premium features. Need to add:
    - Upsell screens when quota is exceeded
    - Premium badge in UI
    - Feature gating in presentation layer

3. **Multi-item Detection**: The Edge Function supports multiple items, but the UI may need updates to handle this properly.

4. **Cache Cleanup**: The `cleanup_expired_cache()` function exists but needs to be scheduled (e.g., via pg_cron or a scheduled Edge Function).

## Next Steps

1. **Add RevenueCat SDK to Flutter**:
   ```yaml
   dependencies:
     purchases_flutter: ^5.0.0
   ```

2. **Implement Purchase Flow**:
    - Create subscription purchase screen
    - Integrate RevenueCat SDK
    - Handle purchase success/failure

3. **Add Premium UI Indicators**:
    - Show remaining scans in UI
    - Add premium badge
    - Create upsell modals

4. **Set up pg_cron for Cache Cleanup**:
   ```sql
   SELECT cron.schedule(
     'cleanup-food-cache',
     '0 2 * * *', -- Daily at 2 AM
     'SELECT cleanup_expired_cache()'
   );
   ```

5. **Add Error Handling in UI**:
    - Handle `ScanQuotaExceededFailure` with upsell
    - Handle `RecognitionUnavailableFailure` with retry prompt
    - Show appropriate error messages

## Architecture Notes

### Vision Provider Chain
The implementation uses a chain-of-responsibility pattern:
1. Try Gemini first (primary)
2. On 429/quota error, fall back to Groq
3. If both fail, return `RecognitionUnavailableFailure`
4. Log which provider served the request for analytics

### Quota Enforcement
Two-tier enforcement:
1. **Client-side**: Check quota before making API call (UX optimization)
2. **Server-side**: Edge Function checks quota before processing (security)

### Data Flow
```
Flutter App → Supabase Edge Function → Gemini/Groq (vision) + USDA (nutrition)
                                              ↓
                                      Postgres (cache/logs/quota)
```

## Security Considerations

1. **API Keys**: All API keys are stored as Supabase secrets, never in client code
2. **JWT Verification**: Edge Functions verify Supabase Auth JWTs before processing
3. **RLS Policies**: Database tables have Row Level Security enabled
4. **Webhook Verification**: RevenueCat webhook signature is verified before processing
5. **SECURITY DEFINER Functions**: Quota functions use SECURITY DEFINER to bypass RLS for trusted operations

## Performance Optimizations

1. **Caching**: USDA search results are cached in Postgres with TTL
2. **Session Cache**: Recognition results are cached in memory for the session
3. **Batch Operations**: Multiple food items are processed in parallel where possible
4. **Indexing**: Database tables have appropriate indexes for common queries
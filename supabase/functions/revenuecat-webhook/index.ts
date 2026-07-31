import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from '@supabase/supabase-js';
import { createHmac } from 'https://deno.land/std@0.208.0/crypto/mod.ts';

interface RevenueCatWebhookEvent {
  event: {
    type: string;
    product_id: string;
    entitlement_id: string;
    customer_info: {
      $email?: string;
      $displayName?: string;
      first_seen: string;
      original_app_user_id: string;
      original_application_version: string;
      latest_app_version: string;
      original_purchase_date: string;
      management_url: string;
    };
    transaction: {
      transaction_id: string;
      original_transaction_id: string;
      product_id: string;
      purchase_date: string;
      expires_date?: string;
      environment: string;
    };
    offer_code?: string;
    price: number;
    currency: string;
    country_code: string;
    store: string;
  };
  api_version: string;
  timestamp_ms: number;
}

const WEBHOOK_SECRET = Deno.env.get('REVENUECAT_WEBHOOK_SECRET')!;

async function verifySignature(payload: string, signature: string): Promise<boolean> {
  const hmac = createHmac('sha256', WEBHOOK_SECRET);
  hmac.update(payload);
  const expectedSignature = hmac.toString('base64');
  
  // Use timing-safe comparison
  if (signature.length !== expectedSignature.length) {
    return false;
  }
  
  let result = 0;
  for (let i = 0; i < signature.length; i++) {
    result |= signature.charCodeAt(i) ^ expectedSignature.charCodeAt(i);
  }
  
  return result === 0;
}

async function getUserIdFromRevenueCatId(originalAppUserId: string, supabase: any): Promise<string | null> {
  // Try to find user by their RevenueCat ID stored in user metadata
  const { data: users } = await supabase
    .from('auth.users')
    .select('id')
    .filter('raw_user_meta_data->revenuecat_id', 'eq', originalAppUserId)
    .limit(1);
  
  if (users && users.length > 0) {
    return users[0].id;
  }
  
  // If not found, try to match by email
  const { data: userByEmail } = await supabase
    .from('auth.users')
    .select('id')
    .eq('email', originalAppUserId)
    .limit(1);
  
  if (userByEmail && userByEmail.length > 0) {
    return userByEmail[0].id;
  }
  
  return null;
}

async function handleSubscriptionEvent(
  event: RevenueCatWebhookEvent,
  supabase: any
): Promise<void> {
  const eventType = event.event.type;
  const originalAppUserId = event.event.customer_info.original_app_user_id;
  const productId = event.event.product_id;
  const expiresDate = event.event.transaction.expires_date;
  
  // Map RevenueCat user ID to Supabase user ID
  const userId = await getUserIdFromRevenueCatId(originalAppUserId, supabase);
  
  if (!userId) {
    console.error(`User not found for RevenueCat ID: ${originalAppUserId}`);
    return;
  }
  
  let isPremium = false;
  let expiresAt: string | null = null;
  
  switch (eventType) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'PRODUCT_CHANGE':
    case 'UNCANCELLATION':
      isPremium = true;
      expiresAt = expiresDate || null;
      break;
      
    case 'CANCELLATION':
    case 'EXPIRATION':
    case 'REFUND':
    case 'REFUND_REQUESTED':
    case 'SUBSCRIPTION_PAUSED':
      isPremium = false;
      expiresAt = expiresDate || new Date().toISOString();
      break;
      
    case 'TEST':
      // Test event, ignore
      return;
      
    default:
      console.log(`Unhandled event type: ${eventType}`);
      return;
  }
  
  // Upsert subscription status
  const { error } = await supabase
    .from('subscriptions')
    .upsert({
      user_id: userId,
      is_premium: isPremium,
      product_id: productId,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id',
    });
  
  if (error) {
    console.error('Failed to upsert subscription:', error);
    throw error;
  }
  
  console.log(`Updated subscription for user ${userId}: isPremium=${isPremium}, productId=${productId}`);
}

Deno.serve(async (req) => {
  try {
    // Verify webhook signature
    const signature = req.headers.get('X-RevenueCat-Webhook-Signature');
    if (!signature) {
      return new Response(JSON.stringify({ error: 'Missing signature' }), { status: 401 });
    }
    
    const payload = await req.text();
    const isValid = await verifySignature(payload, signature);
    
    if (!isValid) {
      console.error('Invalid webhook signature');
      return new Response(JSON.stringify({ error: 'Invalid signature' }), { status: 401 });
    }
    
    const event: RevenueCatWebhookEvent = JSON.parse(payload);
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    await handleSubscriptionEvent(event, supabase);
    
    return new Response(JSON.stringify({ success: true }), { status: 200 });
    
  } catch (error) {
    console.error('Error in revenuecat-webhook:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500 }
    );
  }
});

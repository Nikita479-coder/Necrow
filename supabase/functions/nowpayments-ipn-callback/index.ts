import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey, x-nowpayments-sig',
};

const NOWPAYMENTS_IPN_SECRET = Deno.env.get('NOWPAYMENTS_IPN_SECRET') || '';

async function verifySignature(payload: string, signature: string): Promise<boolean> {
  if (!NOWPAYMENTS_IPN_SECRET) {
    console.warn('NOWPAYMENTS_IPN_SECRET not configured, skipping signature verification');
    return true;
  }

  try {
    const encoder = new TextEncoder();
    const keyData = encoder.encode(NOWPAYMENTS_IPN_SECRET);
    const data = encoder.encode(payload);

    const key = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-512' },
      false,
      ['sign']
    );

    const signatureBuffer = await crypto.subtle.sign('HMAC', key, data);
    const computedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return computedSignature === signature.toLowerCase();
  } catch (error) {
    console.error('Signature verification error:', error);
    return false;
  }
}

function sortObject(obj: any): any {
  if (typeof obj !== 'object' || obj === null) {
    return obj;
  }
  if (Array.isArray(obj)) {
    return obj.map(sortObject);
  }
  return Object.keys(obj)
    .sort()
    .reduce((result: any, key: string) => {
      result[key] = sortObject(obj[key]);
      return result;
    }, {});
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const rawBody = await req.text();
    const callbackData = JSON.parse(rawBody);
    
    console.log('NOWPayments IPN callback received:', callbackData);

    const signature = req.headers.get('x-nowpayments-sig');
    
    if (NOWPAYMENTS_IPN_SECRET && signature) {
      const sortedData = sortObject(callbackData);
      const sortedJson = JSON.stringify(sortedData);
      
      const isValid = await verifySignature(sortedJson, signature);
      
      if (!isValid) {
        console.error('Invalid IPN signature');
        return new Response(
          JSON.stringify({ success: false, error: 'Invalid signature' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      console.log('IPN signature verified successfully');
    }

    const paymentId = callbackData.payment_id?.toString();
    const paymentStatus = callbackData.payment_status;
    const actuallyPaid = parseFloat(callbackData.actually_paid || 0);
    const outcomeAmount = parseFloat(callbackData.outcome_amount || callbackData.price_amount || 0);
    const payCurrency = callbackData.pay_currency?.toUpperCase() || 'UNKNOWN';

    if (!paymentId) {
      throw new Error('Missing payment_id in callback');
    }

    await supabase
      .from('nowpayments_callbacks')
      .insert({
        nowpayments_payment_id: paymentId,
        callback_data: callbackData,
        processed: false,
      });

    const { data: deposit } = await supabase
      .from('crypto_deposits')
      .select('user_id, pay_currency, status, wallet_type, completed_at')
      .eq('nowpayments_payment_id', paymentId)
      .maybeSingle();

    if (paymentStatus === 'confirming' || paymentStatus === 'confirmed') {
      if (deposit && deposit.status !== paymentStatus) {
        await supabase.from('notifications').insert({
          user_id: deposit.user_id,
          type: 'system',
          title: 'Deposit Detected',
          message: `Your ${payCurrency} deposit has been detected and is being confirmed. Amount: ${actuallyPaid} ${payCurrency}`,
          is_read: false
        });
      }
    }

    const { data: result, error: processError } = await supabase
      .rpc('process_crypto_deposit_completion', {
        p_nowpayments_payment_id: paymentId,
        p_status: paymentStatus,
        p_actually_paid: actuallyPaid,
        p_outcome_amount: outcomeAmount,
      });

    if (processError) {
      console.error('Error processing deposit:', processError);
      throw processError;
    }

    console.log('Deposit processed:', result);

    if ((paymentStatus === 'failed' || paymentStatus === 'refunded') && deposit) {
      await supabase.from('notifications').insert({
        user_id: deposit.user_id,
        type: 'system',
        title: paymentStatus === 'failed' ? 'Deposit Failed' : 'Deposit Refunded',
        message: `Your ${payCurrency} deposit has ${paymentStatus === 'failed' ? 'failed' : 'been refunded'}. Please contact support if you need assistance.`,
        is_read: false
      });
    }

    await supabase
      .from('nowpayments_callbacks')
      .update({ processed: true })
      .eq('nowpayments_payment_id', paymentId)
      .order('created_at', { ascending: false })
      .limit(1);

    return new Response(
      JSON.stringify({
        success: true,
        result,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error in nowpayments-ipn-callback:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

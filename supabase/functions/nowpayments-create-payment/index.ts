import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const NOWPAYMENTS_API_KEY = Deno.env.get('NOWPAYMENTS_API_KEY') || '4XWP250-J9ZMZQR-Q8HD6B2-8TG7SVK';
const NOWPAYMENTS_API_URL = 'https://api.nowpayments.io/v1';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    const { price_amount, pay_currency, wallet_type } = await req.json();

    if (!pay_currency) {
      throw new Error('Missing required field: pay_currency');
    }

    const ipnCallbackUrl = `${supabaseUrl}/functions/v1/nowpayments-ipn-callback`;

    const defaultAmount = 10;

    const nowpaymentsResponse = await fetch(`${NOWPAYMENTS_API_URL}/payment`, {
      method: 'POST',
      headers: {
        'x-api-key': NOWPAYMENTS_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        price_amount: price_amount ? parseFloat(price_amount) : defaultAmount,
        price_currency: 'usd',
        pay_currency: pay_currency.toLowerCase(),
        ipn_callback_url: ipnCallbackUrl,
        order_id: crypto.randomUUID(),
        order_description: `Crypto deposit to ${wallet_type || 'spot'} wallet`,
      }),
    });

    if (!nowpaymentsResponse.ok) {
      const errorText = await nowpaymentsResponse.text();
      console.error('NOWPayments API error:', errorText);
      throw new Error(`NOWPayments API error: ${errorText}`);
    }

    const paymentData = await nowpaymentsResponse.json();
    console.log('NOWPayments response:', paymentData);

    const { data: deposit, error: insertError } = await supabase
      .from('crypto_deposits')
      .insert({
        user_id: user.id,
        nowpayments_payment_id: paymentData.payment_id.toString(),
        price_amount: price_amount ? parseFloat(price_amount) : null,
        price_currency: 'USD',
        pay_amount: paymentData.pay_amount,
        pay_currency: pay_currency.toUpperCase(),
        pay_address: paymentData.pay_address,
        wallet_type: wallet_type || 'spot',
        status: paymentData.payment_status,
        expires_at: paymentData.expiration_estimate_date,
        payment_extra: paymentData,
      })
      .select()
      .single();

    if (insertError) {
      console.error('Database insert error:', insertError);
      throw insertError;
    }

    await supabase.from('notifications').insert({
      user_id: user.id,
      type: 'system',
      title: 'Deposit Address Generated',
      message: `A ${pay_currency.toUpperCase()} deposit address has been generated. Send your funds to complete the deposit.`,
      is_read: false
    });

    return new Response(
      JSON.stringify({
        success: true,
        payment: {
          payment_id: deposit.payment_id,
          pay_address: paymentData.pay_address,
          pay_amount: paymentData.pay_amount,
          pay_currency: pay_currency.toUpperCase(),
          price_amount: price_amount,
          status: paymentData.payment_status,
          expires_at: paymentData.expiration_estimate_date,
        },
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error in nowpayments-create-payment:', error);
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
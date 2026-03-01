const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const NOWPAYMENTS_API_KEY = Deno.env.get('NOWPAYMENTS_API_KEY') || '4XWP250-J9ZMZQR-Q8HD6B2-8TG7SVK';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    let paymentId: string | null = null;

    if (req.method === 'GET') {
      const url = new URL(req.url);
      paymentId = url.searchParams.get('payment_id');
    } else if (req.method === 'POST') {
      const body = await req.json();
      paymentId = body.payment_id;
    }

    if (!paymentId) {
      return new Response(
        JSON.stringify({ error: 'payment_id required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const response = await fetch(
      `https://api.nowpayments.io/v1/payment/${paymentId}`,
      {
        method: 'GET',
        headers: { 'x-api-key': NOWPAYMENTS_API_KEY }
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      return new Response(
        JSON.stringify({ error: 'Failed to fetch payment status', details: errorText }),
        { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const data = await response.json();

    return new Response(
      JSON.stringify({
        payment_id: data.payment_id,
        payment_status: data.payment_status,
        actually_paid: data.actually_paid || 0,
        outcome_amount: data.outcome_amount || data.actually_paid || 0,
        pay_amount: data.pay_amount,
        pay_currency: data.pay_currency,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
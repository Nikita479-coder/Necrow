import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const NOWPAYMENTS_API_KEY = Deno.env.get('NOWPAYMENTS_API_KEY') || '4XWP250-J9ZMZQR-Q8HD6B2-8TG7SVK';
const NOWPAYMENTS_API_URL = 'https://api.nowpayments.io/v1';

interface CryptoDeposit {
  payment_id: string;
  user_id: string;
  nowpayments_payment_id: string;
  pay_currency: string;
  status: string;
  created_at: string;
  expires_at: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const pendingStatuses = ['waiting', 'confirming', 'confirmed', 'sending', 'partially_paid'];
    
    const { data: pendingDeposits, error: fetchError } = await supabase
      .from('crypto_deposits')
      .select('payment_id, user_id, nowpayments_payment_id, pay_currency, status, created_at, expires_at')
      .in('status', pendingStatuses)
      .not('nowpayments_payment_id', 'is', null)
      .order('created_at', { ascending: false })
      .limit(50);

    if (fetchError) {
      console.error('Error fetching pending deposits:', fetchError);
      throw fetchError;
    }

    if (!pendingDeposits || pendingDeposits.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: 'No pending deposits to check', checked: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Checking ${pendingDeposits.length} pending deposits`);

    const results = {
      checked: 0,
      updated: 0,
      completed: 0,
      expired: 0,
      errors: 0
    };

    for (const deposit of pendingDeposits) {
      results.checked++;
      
      try {
        const createdAt = new Date(deposit.created_at);
        const now = new Date();
        const hoursSinceCreation = (now.getTime() - createdAt.getTime()) / (1000 * 60 * 60);
        
        if (hoursSinceCreation > 24) {
          await supabase
            .from('crypto_deposits')
            .update({ 
              status: 'expired', 
              updated_at: now.toISOString() 
            })
            .eq('payment_id', deposit.payment_id);
          
          await supabase.from('notifications').insert({
            user_id: deposit.user_id,
            type: 'system',
            title: 'Deposit Expired',
            message: `Your ${deposit.pay_currency.toUpperCase()} deposit address has expired. Please generate a new address to make a deposit.`,
            is_read: false
          });
          
          results.expired++;
          console.log(`Deposit ${deposit.payment_id} marked as expired`);
          continue;
        }

        const nowpaymentsResponse = await fetch(
          `${NOWPAYMENTS_API_URL}/payment/${deposit.nowpayments_payment_id}`,
          {
            method: 'GET',
            headers: { 'x-api-key': NOWPAYMENTS_API_KEY }
          }
        );

        if (!nowpaymentsResponse.ok) {
          console.error(`Failed to fetch status for ${deposit.nowpayments_payment_id}:`, await nowpaymentsResponse.text());
          results.errors++;
          continue;
        }

        const paymentData = await nowpaymentsResponse.json();
        const newStatus = paymentData.payment_status;
        
        if (newStatus !== deposit.status) {
          console.log(`Deposit ${deposit.payment_id}: ${deposit.status} -> ${newStatus}`);
          
          await supabase
            .from('crypto_deposits')
            .update({
              status: newStatus,
              actually_paid: paymentData.actually_paid || 0,
              updated_at: new Date().toISOString()
            })
            .eq('payment_id', deposit.payment_id);
          
          results.updated++;

          if (newStatus === 'confirming' || newStatus === 'confirmed') {
            await supabase.from('notifications').insert({
              user_id: deposit.user_id,
              type: 'system',
              title: 'Deposit Detected',
              message: `Your ${deposit.pay_currency.toUpperCase()} deposit has been detected and is being confirmed. Amount: ${paymentData.actually_paid || 0} ${deposit.pay_currency.toUpperCase()}`,
              is_read: false
            });
          }

          if (newStatus === 'finished' || newStatus === 'partially_paid') {
            const actuallyPaid = parseFloat(paymentData.actually_paid || 0);
            const outcomeAmount = parseFloat(paymentData.outcome_amount || paymentData.actually_paid || 0);

            const { data: processResult, error: processError } = await supabase
              .rpc('process_crypto_deposit_completion', {
                p_nowpayments_payment_id: deposit.nowpayments_payment_id,
                p_status: newStatus,
                p_actually_paid: actuallyPaid,
                p_outcome_amount: outcomeAmount
              });

            if (processError) {
              console.error(`Error processing deposit ${deposit.payment_id}:`, processError);
              results.errors++;
            } else {
              console.log(`Deposit ${deposit.payment_id} completed (${newStatus}):`, processResult);
              results.completed++;
            }
          }

          if (newStatus === 'failed' || newStatus === 'refunded') {
            await supabase.from('notifications').insert({
              user_id: deposit.user_id,
              type: 'system',
              title: newStatus === 'failed' ? 'Deposit Failed' : 'Deposit Refunded',
              message: `Your ${deposit.pay_currency.toUpperCase()} deposit has ${newStatus === 'failed' ? 'failed' : 'been refunded'}. Please contact support if you need assistance.`,
              is_read: false
            });
          }
        }
      } catch (depositError) {
        console.error(`Error processing deposit ${deposit.payment_id}:`, depositError);
        results.errors++;
      }
    }

    console.log('Deposit status check complete:', results);

    return new Response(
      JSON.stringify({
        success: true,
        ...results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in check-deposit-status:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

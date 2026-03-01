import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const pendingStatuses = ['waiting', 'confirming', 'confirmed', 'sending'];
    
    const { data: expiredDeposits, error: fetchError } = await supabase
      .from('crypto_deposits')
      .select('payment_id, user_id, pay_currency, status, created_at')
      .in('status', pendingStatuses)
      .lt('created_at', twentyFourHoursAgo.toISOString())
      .limit(100);

    if (fetchError) {
      console.error('Error fetching expired deposits:', fetchError);
      throw fetchError;
    }

    if (!expiredDeposits || expiredDeposits.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No deposits to expire', 
          expired: 0 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Found ${expiredDeposits.length} deposits to expire`);

    let expiredCount = 0;
    let errorCount = 0;

    for (const deposit of expiredDeposits) {
      try {
        const { error: updateError } = await supabase
          .from('crypto_deposits')
          .update({ 
            status: 'expired', 
            updated_at: now.toISOString() 
          })
          .eq('payment_id', deposit.payment_id);

        if (updateError) {
          console.error(`Error expiring deposit ${deposit.payment_id}:`, updateError);
          errorCount++;
          continue;
        }

        await supabase.from('notifications').insert({
          user_id: deposit.user_id,
          type: 'system',
          title: 'Deposit Address Expired',
          message: `Your ${deposit.pay_currency.toUpperCase()} deposit address has expired after 24 hours. If you sent funds, please contact support. Otherwise, generate a new address for your next deposit.`,
          is_read: false
        });

        expiredCount++;
        console.log(`Expired deposit ${deposit.payment_id} for user ${deposit.user_id}`);

      } catch (depositError) {
        console.error(`Error processing expired deposit ${deposit.payment_id}:`, depositError);
        errorCount++;
      }
    }

    console.log(`Expiration complete: ${expiredCount} expired, ${errorCount} errors`);

    return new Response(
      JSON.stringify({
        success: true,
        expired: expiredCount,
        errors: errorCount,
        total_processed: expiredDeposits.length
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error in expire-pending-deposits:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
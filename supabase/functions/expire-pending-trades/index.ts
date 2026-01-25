import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: expiredTrades, error: tradesError } = await supabase.rpc('expire_old_pending_trades');

    if (tradesError) {
      console.error('Error expiring trades:', tradesError);
    }

    const { data: expiredAutoAccept, error: autoAcceptError } = await supabase.rpc('expire_auto_accept_settings');

    if (autoAcceptError) {
      console.error('Error expiring auto-accept:', autoAcceptError);
    }

    if (tradesError && autoAcceptError) {
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to expire trades and auto-accept settings' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        expired_trades: expiredTrades || 0,
        expired_auto_accept: expiredAutoAccept || 0,
        message: `Expired ${expiredTrades || 0} pending trades, ${expiredAutoAccept || 0} auto-accept settings`
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: any) {
    console.error('Error in expire-pending-trades:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
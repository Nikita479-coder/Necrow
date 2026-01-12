import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get all active trading pairs with open positions
    const { data: pairs, error: pairsError } = await supabase
      .from("futures_positions")
      .select("pair")
      .eq("status", "open");

    if (pairsError) {
      throw pairsError;
    }

    // Get unique pairs
    const uniquePairs = [...new Set(pairs?.map(p => p.pair) || [])];

    // Apply funding to each pair
    const results = [];
    for (const pair of uniquePairs) {
      const { error } = await supabase.rpc("apply_funding_payment", {
        p_pair: pair,
      });

      if (error) {
        console.error(`Error applying funding to ${pair}:`, error);
        results.push({
          pair,
          success: false,
          error: error.message,
        });
      } else {
        results.push({
          pair,
          success: true,
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Funding fees applied to ${uniquePairs.length} pairs`,
        results,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Error applying funding fees:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});

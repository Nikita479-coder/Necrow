import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: authHeader } },
      }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { currency, amount, address, network } = await req.json();

    if (!currency || !amount || !address || !network) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required fields: currency, amount, address, network" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const numericAmount = parseFloat(amount);
    if (isNaN(numericAmount) || numericAmount <= 0) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid amount" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const trimmedAddress = address.trim();
    if (trimmedAddress.length < 10) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid wallet address" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Calling create_withdrawal_request with:", {
      p_user_id: user.id,
      p_currency: currency.toUpperCase(),
      p_amount: numericAmount,
      p_address: trimmedAddress,
      p_network: network,
    });

    const { data, error } = await supabase.rpc("create_withdrawal_request", {
      p_user_id: user.id,
      p_currency: currency.toUpperCase(),
      p_amount: numericAmount,
      p_address: trimmedAddress,
      p_network: network,
    });

    console.log("RPC Response - data:", data);
    console.log("RPC Response - error:", error);
    console.log("RPC Response - data type:", typeof data);
    console.log("RPC Response - data.success:", data?.success);

    if (error) {
      console.error("Withdrawal error:", error);
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // If data is the result object, return it directly
    // If data.success is false, return 400 status
    if (data && typeof data === 'object' && 'success' in data) {
      const statusCode = data.success ? 200 : 400;
      console.log("Returning with status:", statusCode, "and data:", data);
      return new Response(
        JSON.stringify(data),
        { status: statusCode, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fallback - shouldn't reach here
    console.error("Unexpected data structure:", data);
    return new Response(
      JSON.stringify({ success: false, error: "Unexpected response format" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
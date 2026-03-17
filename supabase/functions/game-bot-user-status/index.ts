import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey, X-Game-Bot-Secret",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const GAME_BOT_SECRET = Deno.env.get("GAME_BOT_SECRET") || "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const botSecret = req.headers.get("X-Game-Bot-Secret");
    if (!botSecret) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", reason: "missing_header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (!GAME_BOT_SECRET) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", reason: "server_secret_not_configured" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (botSecret !== GAME_BOT_SECRET) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", reason: "secret_mismatch" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { chat_id } = await req.json();

    if (!chat_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: chat_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: userData, error: userError } = await supabase
      .from("user_profiles")
      .select("id, username, kyc_level, kyc_status, referred_by")
      .eq("game_bot_chat_id", String(chat_id))
      .maybeSingle();

    if (userError) {
      return new Response(
        JSON.stringify({ error: "Failed to look up user", details: userError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!userData) {
      return new Response(
        JSON.stringify({ linked: false, message: "No Shark Trades account linked to this chat" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = userData.id;

    const { data: traderRow } = await supabase
      .from("traders")
      .select("id")
      .eq("name", "Satoshi Academy")
      .maybeSingle();

    const satoshiTraderId = traderRow?.id || null;

    let copyDetails = null;
    let isCopyingSatoshi = false;

    if (satoshiTraderId) {
      const { data: copyRow } = await supabase
        .from("copy_relationships")
        .select(
          "status, is_active, is_mock, initial_balance, current_balance, total_pnl, cumulative_pnl, total_trades_copied, allocation_percentage, created_at"
        )
        .eq("follower_id", userId)
        .eq("trader_id", satoshiTraderId)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (copyRow) {
        isCopyingSatoshi = copyRow.is_active === true && copyRow.status === "active";
        copyDetails = {
          status: copyRow.status,
          is_active: copyRow.is_active,
          is_mock: copyRow.is_mock,
          initial_balance: Number(copyRow.initial_balance || 0),
          current_balance: Number(copyRow.current_balance || 0),
          total_pnl: Number(copyRow.total_pnl || 0),
          cumulative_pnl: Number(copyRow.cumulative_pnl || 0),
          total_trades_copied: copyRow.total_trades_copied || 0,
          allocation_percentage: copyRow.allocation_percentage || 0,
          started_at: copyRow.created_at,
        };
      }
    }

    const { count: totalReferrals } = await supabase
      .from("user_profiles")
      .select("id", { count: "exact", head: true })
      .eq("referred_by", userId);

    let referralsCopyingSatoshi = 0;

    if (satoshiTraderId && (totalReferrals || 0) > 0) {
      const { data: referralIds } = await supabase
        .from("user_profiles")
        .select("id")
        .eq("referred_by", userId);

      if (referralIds && referralIds.length > 0) {
        const ids = referralIds.map((r: { id: string }) => r.id);

        const { count: copyingCount } = await supabase
          .from("copy_relationships")
          .select("id", { count: "exact", head: true })
          .eq("trader_id", satoshiTraderId)
          .eq("is_active", true)
          .eq("status", "active")
          .in("follower_id", ids);

        referralsCopyingSatoshi = copyingCount || 0;
      }
    }

    return new Response(
      JSON.stringify({
        linked: true,
        user_id: userId,
        username: userData.username,
        kyc_level: userData.kyc_level,
        kyc_status: userData.kyc_status,
        is_copying_satoshi_academy: isCopyingSatoshi,
        copy_details: copyDetails,
        total_direct_referrals: totalReferrals || 0,
        referrals_copying_satoshi: referralsCopyingSatoshi,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

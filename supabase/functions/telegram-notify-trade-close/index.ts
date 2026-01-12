import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface CloseNotificationResult {
  userId: string;
  success: boolean;
  error?: string;
}

async function sendTelegramMessage(
  chatId: number,
  text: string
): Promise<{ ok: boolean; error?: string }> {
  try {
    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: chatId,
          text: text,
          parse_mode: "HTML",
          disable_web_page_preview: true,
        }),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      return { ok: false, error: data.description || "Unknown error" };
    }

    return { ok: true };
  } catch (error) {
    return { ok: false, error: String(error) };
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { trader_id, trader_trade_id, pair, side, entry_price, exit_price, pnl_percentage, leverage } = await req.json();

    if (!trader_id || !pair) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: traderProfile } = await supabase
      .from("user_profiles")
      .select("username")
      .eq("id", trader_id)
      .single();

    const { data: trader } = await supabase
      .from("traders")
      .select("name")
      .eq("id", trader_id)
      .single();

    const traderName = trader?.name || traderProfile?.username || "Unknown Trader";

    const { data: followers, error: followersError } = await supabase.rpc(
      "get_telegram_followers_for_trader",
      { p_trader_id: trader_id }
    );

    if (followersError || !followers || followers.length === 0) {
      return new Response(
        JSON.stringify({
          message: "No followers with Telegram enabled",
          follower_count: 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results: CloseNotificationResult[] = [];

    for (const follower of followers) {
      let userPnlPercentage = pnl_percentage;
      let userRealizedPnl = 0;
      let hasAllocation = false;

      if (trader_trade_id) {
        const { data: allocation } = await supabase
          .from("copy_trade_allocations")
          .select("pnl_percentage, realized_pnl, allocated_amount")
          .eq("follower_id", follower.user_id)
          .eq("trader_trade_id", trader_trade_id)
          .maybeSingle();

        if (allocation) {
          userPnlPercentage = allocation.pnl_percentage || pnl_percentage;
          userRealizedPnl = allocation.realized_pnl || 0;
          hasAllocation = true;
        }
      }

      const isProfitable = userPnlPercentage >= 0;
      const resultEmoji = isProfitable ? "\u{2705}" : "\u{274C}";
      const pnlSign = isProfitable ? "+" : "";

      let messageText =
        `<b>${resultEmoji} TRADE CLOSED</b>\n\n` +
        `<b>Trader:</b> ${traderName}\n` +
        `<b>Pair:</b> ${pair}\n` +
        `<b>Leverage:</b> ${leverage}x\n` +
        `<b>Entry:</b> $${Number(entry_price).toLocaleString()}\n` +
        `<b>Exit:</b> $${Number(exit_price).toLocaleString()}\n\n` +
        `<b>Your ROI:</b> ${pnlSign}${Number(userPnlPercentage).toFixed(2)}%`;

      if (hasAllocation && userRealizedPnl !== 0) {
        const pnlEmoji = userRealizedPnl >= 0 ? "\u{1F4B0}" : "\u{1F4B8}";
        messageText += `\n<b>Your PnL:</b> ${pnlEmoji} ${pnlSign}${Number(userRealizedPnl).toFixed(2)} USDT`;
      }

      messageText += `\n\n<i>Your balance has been updated accordingly.</i>`;

      const result = await sendTelegramMessage(follower.telegram_chat_id, messageText);

      if (result.ok) {
        results.push({ userId: follower.user_id, success: true });
      } else {
        results.push({ userId: follower.user_id, success: false, error: result.error });
      }

      await delay(35);
    }

    const sent = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    return new Response(
      JSON.stringify({
        success: true,
        notifications: {
          total: results.length,
          sent,
          failed,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Telegram close notify error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

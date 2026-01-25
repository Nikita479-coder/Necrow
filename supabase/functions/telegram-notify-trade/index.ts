import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") || "";
const TELEGRAM_RING_FILE_ID = Deno.env.get("TELEGRAM_RING_FILE_ID") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const SITE_URL = Deno.env.get("SITE_URL") || "https://app.sharktrade.io";

interface NotificationResult {
  userId: string;
  success: boolean;
  error?: string;
}

async function sendTelegramVoice(chatId: string | number, fileId: string): Promise<boolean> {
  if (!fileId) return true;

  try {
    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendVoice`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: chatId,
          voice: fileId,
        }),
      }
    );
    return response.ok;
  } catch {
    return false;
  }
}

async function sendTelegramMessage(
  chatId: string | number,
  text: string
): Promise<{ ok: boolean; error?: string; blocked?: boolean }> {
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
          disable_web_page_preview: false,
        }),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      const errorCode = data.error_code;
      const description = data.description || "Unknown error";

      if (errorCode === 403 || description.includes("blocked") || description.includes("deactivated")) {
        return { ok: false, error: description, blocked: true };
      }

      return { ok: false, error: description };
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
    const { pending_trade_id, type, record } = await req.json();
    
    const tradeId = pending_trade_id || record?.id;
    
    if (!tradeId) {
      return new Response(
        JSON.stringify({ error: "Missing pending_trade_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: trade, error: tradeError } = await supabase
      .from("pending_copy_trades")
      .select(`
        id,
        trader_id,
        pair,
        side,
        leverage,
        entry_price,
        expires_at,
        status
      `)
      .eq("id", tradeId)
      .single();

    if (tradeError || !trade) {
      return new Response(
        JSON.stringify({ error: "Trade not found", details: tradeError }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (trade.status !== "pending") {
      return new Response(
        JSON.stringify({ message: "Trade is not pending, skipping notifications" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: traderProfile } = await supabase
      .from("user_profiles")
      .select("username")
      .eq("id", trade.trader_id)
      .single();

    const { data: trader } = await supabase
      .from("traders")
      .select("name")
      .eq("id", trade.trader_id)
      .single();

    const traderName = trader?.name || traderProfile?.username || "Unknown Trader";

    const { data: followers, error: followersError } = await supabase.rpc(
      "get_telegram_followers_for_trader",
      { p_trader_id: trade.trader_id }
    );

    if (followersError || !followers || followers.length === 0) {
      return new Response(
        JSON.stringify({ 
          message: "No followers with Telegram enabled",
          follower_count: 0 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tradeUrl = `${SITE_URL}?page=copytrading&trade=${tradeId}`;

    const { data: autoAcceptedUsers } = await supabase
      .from("pending_trade_responses")
      .select("follower_id")
      .eq("pending_trade_id", tradeId)
      .eq("response", "accepted")
      .eq("auto_accepted", true);

    const autoAcceptedSet = new Set(
      (autoAcceptedUsers || []).map((r: { follower_id: string }) => r.follower_id)
    );

    const results: NotificationResult[] = [];

    for (const follower of followers) {
      const isAutoAccepted = autoAcceptedSet.has(follower.user_id);

      const messageText = isAutoAccepted
        ? `<b>\u{2705} TRADE AUTO-ACCEPTED</b>\n\n` +
          `<b>Trader:</b> ${traderName}\n` +
          `<b>Pair:</b> ${trade.pair}\n` +
          `<b>Side:</b> ${trade.side.toUpperCase()}\n` +
          `<b>Leverage:</b> ${trade.leverage}x\n` +
          `<b>Entry:</b> $${Number(trade.entry_price).toLocaleString()}\n\n` +
          `<i>This trade was automatically accepted based on your settings.</i>\n\n` +
          `${tradeUrl}`
        : `<b>\u{1F4C8} NEW TRADE SIGNAL</b>\n\n` +
          `<b>Trader:</b> ${traderName}\n` +
          `<b>Pair:</b> ${trade.pair}\n` +
          `<b>Side:</b> ${trade.side.toUpperCase()}\n` +
          `<b>Leverage:</b> ${trade.leverage}x\n` +
          `<b>Entry:</b> $${Number(trade.entry_price).toLocaleString()}\n\n` +
          `<i>You have 5 minutes to respond.</i>\n\n` +
          `${tradeUrl}`;
      const { data: logData } = await supabase.rpc("log_telegram_notification", {
        p_user_id: follower.user_id,
        p_pending_trade_id: tradeId,
        p_status: "pending",
      });

      const logId = logData;

      if (TELEGRAM_RING_FILE_ID) {
        await sendTelegramVoice(follower.telegram_chat_id, TELEGRAM_RING_FILE_ID);
        await delay(50);
      }

      const result = await sendTelegramMessage(follower.telegram_chat_id, messageText);

      if (result.ok) {
        await supabase.rpc("update_telegram_notification", {
          p_log_id: logId,
          p_status: "sent",
        });
        results.push({ userId: follower.user_id, success: true });
      } else {
        if (result.blocked) {
          await supabase.rpc("mark_telegram_blocked", {
            p_chat_id: follower.telegram_chat_id,
          });
          await supabase.rpc("update_telegram_notification", {
            p_log_id: logId,
            p_status: "blocked",
            p_error_message: result.error,
          });
        } else {
          await supabase.rpc("update_telegram_notification", {
            p_log_id: logId,
            p_status: "failed",
            p_error_message: result.error,
          });
        }
        results.push({ userId: follower.user_id, success: false, error: result.error });
      }

      await delay(35);
    }

    const sent = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    return new Response(
      JSON.stringify({
        success: true,
        trade_id: tradeId,
        notifications: {
          total: results.length,
          sent,
          failed,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Telegram notify error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
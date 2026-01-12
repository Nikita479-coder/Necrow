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

async function sendTelegramVoice(chatId: number, fileId: string): Promise<boolean> {
  if (!fileId) return true;
  
  try {
    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendVoice`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ chat_id: chatId, voice: fileId }),
      }
    );
    return response.ok;
  } catch {
    return false;
  }
}

async function sendTelegramMessage(
  chatId: number,
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
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUser = createClient(
      SUPABASE_URL,
      authHeader.replace("Bearer ", ""),
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: adminCheck } = await supabase
      .from("user_profiles")
      .select("is_admin")
      .eq("id", user.id)
      .single();

    const isAdmin = adminCheck?.is_admin || user.app_metadata?.is_admin;
    
    if (!isAdmin) {
      return new Response(
        JSON.stringify({ error: "Admin access required" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { pending_trade_id, user_id, notification_id } = await req.json();

    if (!pending_trade_id && !notification_id) {
      return new Response(
        JSON.stringify({ error: "pending_trade_id or notification_id required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let query = supabase
      .from("telegram_notifications_log")
      .select(`
        id,
        user_id,
        pending_trade_id,
        status,
        retry_count
      `);

    if (notification_id) {
      query = query.eq("id", notification_id);
    } else {
      query = query.eq("pending_trade_id", pending_trade_id);
      if (user_id) {
        query = query.eq("user_id", user_id);
      } else {
        query = query.in("status", ["failed"]);
      }
    }

    query = query.lt("retry_count", 3);

    const { data: notifications, error: notifError } = await query;

    if (notifError || !notifications || notifications.length === 0) {
      return new Response(
        JSON.stringify({ 
          message: "No notifications to resend",
          details: notifError 
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tradeIds = [...new Set(notifications.map(n => n.pending_trade_id))];
    const userIds = [...new Set(notifications.map(n => n.user_id))];

    const { data: trades } = await supabase
      .from("pending_copy_trades")
      .select(`
        id,
        trader_id,
        pair,
        side,
        leverage,
        entry_price,
        expires_at
      `)
      .in("id", tradeIds);

    const { data: users } = await supabase
      .from("user_profiles")
      .select("id, telegram_chat_id, telegram_blocked")
      .in("id", userIds);

    const tradeMap = new Map(trades?.map(t => [t.id, t]) || []);
    const userMap = new Map(users?.map(u => [u.id, u]) || []);

    const results: Array<{ notification_id: string; success: boolean; error?: string }> = [];

    for (const notification of notifications) {
      const trade = tradeMap.get(notification.pending_trade_id);
      const userProfile = userMap.get(notification.user_id);

      if (!trade || !userProfile) {
        results.push({ 
          notification_id: notification.id, 
          success: false, 
          error: "Trade or user not found" 
        });
        continue;
      }

      if (!userProfile.telegram_chat_id || userProfile.telegram_blocked) {
        results.push({ 
          notification_id: notification.id, 
          success: false, 
          error: "User has no Telegram or is blocked" 
        });
        continue;
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
      const tradeUrl = `${SITE_URL}/copy-trading?trade=${trade.id}`;
      const sideEmoji = trade.side === "long" ? "\u{1F7E2}" : "\u{1F534}";
      const sideText = trade.side.toUpperCase();
      
      const messageText = 
        `<b>${sideEmoji} NEW TRADE SIGNAL</b>\n\n` +
        `<b>Trader:</b> ${traderName}\n` +
        `<b>Pair:</b> ${trade.pair}\n` +
        `<b>Side:</b> ${sideText}\n` +
        `<b>Leverage:</b> ${trade.leverage}x\n` +
        `<b>Entry:</b> $${Number(trade.entry_price).toLocaleString()}\n\n` +
        `<i>Respond now to participate.</i>\n\n` +
        `${tradeUrl}`;

      if (TELEGRAM_RING_FILE_ID) {
        await sendTelegramVoice(userProfile.telegram_chat_id, TELEGRAM_RING_FILE_ID);
        await delay(50);
      }

      const result = await sendTelegramMessage(userProfile.telegram_chat_id, messageText);

      if (result.ok) {
        await supabase.rpc("update_telegram_notification", {
          p_log_id: notification.id,
          p_status: "sent",
        });
        results.push({ notification_id: notification.id, success: true });
      } else {
        if (result.blocked) {
          await supabase.rpc("mark_telegram_blocked", {
            p_chat_id: userProfile.telegram_chat_id,
          });
          await supabase.rpc("update_telegram_notification", {
            p_log_id: notification.id,
            p_status: "blocked",
            p_error_message: result.error,
          });
        } else {
          await supabase.rpc("update_telegram_notification", {
            p_log_id: notification.id,
            p_status: "failed",
            p_error_message: result.error,
          });
        }
        results.push({ notification_id: notification.id, success: false, error: result.error });
      }

      await delay(35);
    }

    const sent = results.filter(r => r.success).length;
    const failed = results.filter(r => !r.success).length;

    return new Response(
      JSON.stringify({
        success: true,
        resent: {
          total: results.length,
          sent,
          failed,
        },
        details: results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Resend notification error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

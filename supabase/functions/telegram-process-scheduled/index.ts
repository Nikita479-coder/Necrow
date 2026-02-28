import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface PendingMessage {
  message_id: string;
  msg_user_id: string;
  msg_content: string;
  msg_channel: string;
  msg_parse_mode: string;
  msg_disable_notification: boolean;
  msg_bot_token: string;
}

interface TelegramResponse {
  ok: boolean;
  result?: {
    message_id: number;
  };
  description?: string;
}

async function sendToTelegram(
  botToken: string,
  chatId: string,
  text: string,
  parseMode: string,
  disableNotification: boolean
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  try {
    const response = await fetch(
      `https://api.telegram.org/bot${botToken}/sendMessage`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: chatId,
          text: text,
          parse_mode: parseMode === "None" ? undefined : parseMode,
          disable_notification: disableNotification,
          disable_web_page_preview: false,
        }),
      }
    );

    const data: TelegramResponse = await response.json();

    if (!data.ok) {
      return {
        success: false,
        error: data.description || "Unknown Telegram error",
      };
    }

    return {
      success: true,
      messageId: data.result?.message_id?.toString(),
    };
  } catch (error) {
    return {
      success: false,
      error: String(error),
    };
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
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: pendingMessages, error: fetchError } = await supabase.rpc(
      "get_pending_telegram_messages",
      { p_limit: 20 }
    );

    if (fetchError) {
      console.error("Error fetching pending messages:", fetchError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch pending messages", details: fetchError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!pendingMessages || pendingMessages.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, message: "No pending messages" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results: { id: string; success: boolean; error?: string }[] = [];

    for (const msg of pendingMessages as PendingMessage[]) {
      await supabase.rpc("mark_telegram_message_processing", {
        p_message_id: msg.message_id,
      });

      const result = await sendToTelegram(
        msg.msg_bot_token,
        msg.msg_channel,
        msg.msg_content,
        msg.msg_parse_mode || "HTML",
        msg.msg_disable_notification || false
      );

      if (result.success) {
        await supabase.rpc("mark_telegram_message_sent", {
          p_message_id: msg.message_id,
          p_telegram_message_id: result.messageId || "",
        });
        results.push({ id: msg.message_id, success: true });
      } else {
        await supabase.rpc("mark_telegram_message_failed", {
          p_message_id: msg.message_id,
          p_error: result.error || "Unknown error",
        });
        results.push({ id: msg.message_id, success: false, error: result.error });
      }

      await delay(100);
    }

    const sent = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    return new Response(
      JSON.stringify({
        processed: results.length,
        sent,
        failed,
        results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error processing scheduled messages:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
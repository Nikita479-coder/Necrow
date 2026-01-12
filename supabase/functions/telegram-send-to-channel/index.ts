import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface SendMessageRequest {
  message: string;
  channel?: string;
  parse_mode?: "HTML" | "Markdown" | "MarkdownV2";
  disable_notification?: boolean;
  bot_token?: string;
}

interface TelegramResponse {
  ok: boolean;
  result?: {
    message_id: number;
    chat: { id: number; title: string };
    date: number;
  };
  description?: string;
  error_code?: number;
}

async function sendToTelegram(
  botToken: string,
  chatId: string,
  text: string,
  parseMode: string = "HTML",
  disableNotification: boolean = false
): Promise<{ success: boolean; messageId?: number; error?: string }> {
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
        error: data.description || `Error code: ${data.error_code}`,
      };
    }

    return {
      success: true,
      messageId: data.result?.message_id,
    };
  } catch (error) {
    return {
      success: false,
      error: String(error),
    };
  }
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

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const token = authHeader.replace("Bearer ", "");
    
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: profile } = await supabase
      .from("user_profiles")
      .select("is_admin")
      .eq("id", user.id)
      .single();

    if (!profile?.is_admin) {
      return new Response(
        JSON.stringify({ error: "Admin access required" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body: SendMessageRequest = await req.json();
    const { message, channel, parse_mode, disable_notification, bot_token } = body;

    if (!message || message.trim() === "") {
      return new Response(
        JSON.stringify({ error: "Message content is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let tokenToUse = bot_token;
    let channelToUse = channel || "@oldregular";

    if (!tokenToUse) {
      const { data: botConfig } = await supabase
        .from("telegram_bot_config")
        .select("bot_token, channel_username")
        .eq("created_by", user.id)
        .eq("is_active", true)
        .single();

      if (!botConfig?.bot_token) {
        return new Response(
          JSON.stringify({ error: "No bot configured. Please configure your Telegram bot first." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      tokenToUse = botConfig.bot_token;
      if (!channel) {
        channelToUse = botConfig.channel_username || "@oldregular";
      }
    }

    const result = await sendToTelegram(
      tokenToUse,
      channelToUse,
      message,
      parse_mode || "HTML",
      disable_notification || false
    );

    await supabase.from("telegram_message_logs").insert({
      created_by: user.id,
      action: result.success ? "direct_send_success" : "direct_send_failed",
      details: {
        channel: channelToUse,
        message_length: message.length,
        message_id: result.messageId,
        error: result.error,
      },
    });

    if (!result.success) {
      return new Response(
        JSON.stringify({ success: false, error: result.error }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message_id: result.messageId,
        channel: channelToUse,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
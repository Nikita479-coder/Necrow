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

interface TelegramUpdate {
  update_id: number;
  message?: {
    message_id: number;
    from: {
      id: number;
      is_bot: boolean;
      first_name: string;
      username?: string;
    };
    chat: {
      id: number;
      type: string;
    };
    date: number;
    text?: string;
  };
}

async function sendTelegramMessage(chatId: number, text: string): Promise<boolean> {
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
        }),
      }
    );
    return response.ok;
  } catch {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const update: TelegramUpdate = await req.json();
    
    if (!update.message?.text) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const chatId = update.message.chat.id;
    const text = update.message.text.trim();
    const username = update.message.from.username || null;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (text.startsWith("/start")) {
      const parts = text.split(" ");
      
      if (parts.length > 1) {
        const code = parts[1].toUpperCase();
        
        const { data, error } = await supabase.rpc("verify_telegram_linking_code", {
          p_code: code,
          p_chat_id: chatId,
          p_username: username,
        });

        if (error) {
          console.error("Error verifying code:", error);
          await sendTelegramMessage(
            chatId,
            "An error occurred while linking your account. Please try again."
          );
        } else if (data && data.length > 0) {
          const result = data[0];
          if (result.success) {
            await sendTelegramMessage(
              chatId,
              "Your Telegram account has been successfully linked!\n\n" +
              "You will now receive instant notifications when traders you follow open new positions.\n\n" +
              "Commands:\n" +
              "/status - Check linking status\n" +
              "/unlink - Disconnect your account"
            );
          } else {
            await sendTelegramMessage(chatId, result.message || "Invalid or expired code.");
          }
        }
      } else {
        await sendTelegramMessage(
          chatId,
          "Welcome to SharkTrade Notifications!\n\n" +
          "To link your account, please use the 'Connect Telegram' button on the website. " +
          "You will receive a code to enter here.\n\n" +
          "If you have a code, send: /start YOUR_CODE"
        );
      }
    } else if (text === "/unlink") {
      const { data, error } = await supabase.rpc("unlink_telegram_account", {
        p_chat_id: chatId,
      });

      if (error) {
        await sendTelegramMessage(
          chatId,
          "An error occurred. Please try again."
        );
      } else if (data && data.length > 0) {
        const result = data[0];
        await sendTelegramMessage(chatId, result.message);
      }
    } else if (text === "/status") {
      const { data: profile } = await supabase
        .from("user_profiles")
        .select("username, telegram_linked_at")
        .eq("telegram_chat_id", chatId)
        .single();

      if (profile) {
        const linkedDate = new Date(profile.telegram_linked_at).toLocaleDateString();
        await sendTelegramMessage(
          chatId,
          `Your Telegram is linked to: <b>${profile.username || "Your Account"}</b>\n` +
          `Linked since: ${linkedDate}\n\n` +
          "You will receive trade notifications when traders you follow open positions."
        );
      } else {
        await sendTelegramMessage(
          chatId,
          "Your Telegram is not linked to any account.\n\n" +
          "Use the 'Connect Telegram' button on the website to link your account."
        );
      }
    } else if (text === "/help") {
      await sendTelegramMessage(
        chatId,
        "<b>SharkTrade Bot Commands</b>\n\n" +
        "/start [CODE] - Link your account with a code\n" +
        "/status - Check your linking status\n" +
        "/unlink - Disconnect your account\n" +
        "/help - Show this help message"
      );
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Telegram webhook error:", error);
    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

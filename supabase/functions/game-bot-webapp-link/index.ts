import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, X-Client-Info, Apikey",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const GAME_BOT_TOKEN = Deno.env.get("GAME_BOT_TOKEN") || "";
const GAME_BOT_USERNAME = Deno.env.get("GAME_BOT_USERNAME") || "satoshiacademybot";

async function verifyTelegramInitData(
  initData: string,
  botToken: string
): Promise<{ valid: boolean; data: Record<string, string> }> {
  const params = new URLSearchParams(initData);
  const hash = params.get("hash");
  if (!hash) return { valid: false, data: {} };

  params.delete("hash");

  const entries = Array.from(params.entries());
  entries.sort(([a], [b]) => a.localeCompare(b));
  const dataCheckString = entries.map(([k, v]) => `${k}=${v}`).join("\n");

  const encoder = new TextEncoder();
  const secretKeyData = await crypto.subtle.importKey(
    "raw",
    encoder.encode("WebAppData"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const secretKey = await crypto.subtle.sign(
    "HMAC",
    secretKeyData,
    encoder.encode(botToken)
  );

  const signKey = await crypto.subtle.importKey(
    "raw",
    secretKey,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    signKey,
    encoder.encode(dataCheckString)
  );

  const hexSignature = Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  const parsed: Record<string, string> = {};
  for (const [k, v] of new URLSearchParams(initData).entries()) {
    parsed[k] = v;
  }

  return { valid: hexSignature === hash, data: parsed };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    if (!GAME_BOT_TOKEN) {
      return new Response(
        JSON.stringify({ error: "Game bot not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userError,
    } = await supabaseUser.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { init_data } = await req.json();

    if (!init_data) {
      return new Response(
        JSON.stringify({ error: "Missing required field: init_data" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { valid, data: telegramData } = await verifyTelegramInitData(
      init_data,
      GAME_BOT_TOKEN
    );

    if (!valid) {
      return new Response(
        JSON.stringify({ error: "Invalid Telegram data. Please try again from the game." }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const authDate = parseInt(telegramData.auth_date || "0", 10);
    const now = Math.floor(Date.now() / 1000);
    if (now - authDate > 86400) {
      return new Response(
        JSON.stringify({ error: "Telegram session expired. Please reopen the game and try again." }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    let chatId: string | null = null;
    let telegramUsername: string | null = null;

    if (telegramData.user) {
      try {
        const tgUser = JSON.parse(telegramData.user);
        chatId = String(tgUser.id);
        telegramUsername = tgUser.username || null;
      } catch {
        return new Response(
          JSON.stringify({ error: "Failed to parse Telegram user data" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    if (!chatId) {
      return new Response(
        JSON.stringify({ error: "Could not determine Telegram user ID" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: existingUser } = await supabase
      .from("user_profiles")
      .select("id, username")
      .eq("game_bot_chat_id", chatId)
      .maybeSingle();

    if (existingUser && existingUser.id !== user.id) {
      return new Response(
        JSON.stringify({
          error:
            "This Telegram account is already linked to another Shark user.",
        }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (existingUser && existingUser.id === user.id) {
      return new Response(
        JSON.stringify({
          success: true,
          already_linked: true,
          chat_id: chatId,
          telegram_username: telegramUsername,
          bot_username: GAME_BOT_USERNAME,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { data: currentProfile } = await supabase
      .from("user_profiles")
      .select("game_bot_chat_id")
      .eq("id", user.id)
      .maybeSingle();

    if (
      currentProfile?.game_bot_chat_id &&
      currentProfile.game_bot_chat_id !== chatId
    ) {
      return new Response(
        JSON.stringify({
          error:
            "Your account is already linked to a different Telegram account. Unlink it first in Settings.",
        }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { error: updateError } = await supabase
      .from("user_profiles")
      .update({
        game_bot_chat_id: chatId,
        game_bot_username: telegramUsername,
        game_bot_linked_at: new Date().toISOString(),
      })
      .eq("id", user.id);

    if (updateError) {
      return new Response(
        JSON.stringify({
          error: "Failed to link account",
          details: updateError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        chat_id: chatId,
        telegram_username: telegramUsername,
        bot_username: GAME_BOT_USERNAME,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

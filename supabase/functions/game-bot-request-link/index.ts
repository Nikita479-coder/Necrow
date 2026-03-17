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
const SITE_URL = Deno.env.get("SITE_URL") || "";

function generateToken(length = 32): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, (b) => chars[b % chars.length]).join("");
}

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

    const { chat_id, username } = await req.json();

    if (!chat_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: chat_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: existingProfile } = await supabase
      .from("user_profiles")
      .select("id, username")
      .eq("game_bot_chat_id", String(chat_id))
      .maybeSingle();

    if (existingProfile) {
      return new Response(
        JSON.stringify({
          already_linked: true,
          user_id: existingProfile.id,
          username: existingProfile.username,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await supabase
      .from("game_bot_link_requests")
      .delete()
      .eq("chat_id", String(chat_id))
      .is("confirmed_at", null);

    const token = generateToken(40);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: insertError } = await supabase
      .from("game_bot_link_requests")
      .insert({
        token,
        chat_id: String(chat_id),
        telegram_username: username || null,
        expires_at: expiresAt,
      });

    if (insertError) {
      return new Response(
        JSON.stringify({ error: "Failed to create link request", details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const linkUrl = `${SITE_URL}/link-bot?token=${token}`;

    return new Response(
      JSON.stringify({
        success: true,
        token,
        link_url: linkUrl,
        expires_at: expiresAt,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

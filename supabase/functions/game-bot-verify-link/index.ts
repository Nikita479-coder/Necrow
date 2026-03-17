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

    const { code, chat_id, username } = await req.json();

    if (!code || !chat_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: code, chat_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data, error } = await supabase.rpc("verify_game_bot_linking_code", {
      p_code: String(code),
      p_chat_id: String(chat_id),
      p_username: username || null,
    });

    if (error) {
      return new Response(
        JSON.stringify({ success: false, message: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result = data?.[0] || { success: false, message: "Unknown error" };

    return new Response(
      JSON.stringify({
        success: result.success,
        user_id: result.user_id,
        username: result.username,
        message: result.message,
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

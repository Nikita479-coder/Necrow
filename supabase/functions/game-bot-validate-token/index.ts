import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, X-Client-Info, Apikey",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { token } = await req.json();

    if (!token || typeof token !== "string") {
      return new Response(
        JSON.stringify({ valid: false, reason: "missing_token" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data, error } = await supabase
      .from("game_bot_link_requests")
      .select("token, telegram_username, chat_id, expires_at, confirmed_at")
      .eq("token", token)
      .maybeSingle();

    if (error || !data) {
      return new Response(
        JSON.stringify({ valid: false, reason: "not_found" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (data.confirmed_at) {
      return new Response(
        JSON.stringify({ valid: false, reason: "already_used" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (new Date(data.expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ valid: false, reason: "expired" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        valid: true,
        telegram_username: data.telegram_username,
        chat_id: data.chat_id,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        valid: false,
        reason: "server_error",
        details: String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

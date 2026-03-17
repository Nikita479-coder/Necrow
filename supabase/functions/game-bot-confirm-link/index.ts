import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const GAME_BOT_USERNAME = Deno.env.get("GAME_BOT_USERNAME") || "satoshiacademybot";

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

    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", details: userError?.message }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { token } = await req.json();

    if (!token) {
      return new Response(
        JSON.stringify({ error: "Missing required field: token" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: linkRequest, error: fetchError } = await supabase
      .from("game_bot_link_requests")
      .select("*")
      .eq("token", token)
      .is("confirmed_at", null)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();

    if (fetchError || !linkRequest) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired link request. Please try again from the bot." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: existingUser } = await supabase
      .from("user_profiles")
      .select("id, username")
      .eq("game_bot_chat_id", linkRequest.chat_id)
      .maybeSingle();

    if (existingUser && existingUser.id !== user.id) {
      return new Response(
        JSON.stringify({ error: "This Telegram account is already linked to another Shark user." }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: currentProfile } = await supabase
      .from("user_profiles")
      .select("game_bot_chat_id")
      .eq("id", user.id)
      .maybeSingle();

    if (currentProfile?.game_bot_chat_id) {
      return new Response(
        JSON.stringify({ error: "Your account is already linked to a Game Bot. Unlink it first in Settings." }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { error: updateProfileError } = await supabase
      .from("user_profiles")
      .update({
        game_bot_chat_id: linkRequest.chat_id,
        game_bot_username: linkRequest.telegram_username,
        game_bot_linked_at: new Date().toISOString(),
      })
      .eq("id", user.id);

    if (updateProfileError) {
      return new Response(
        JSON.stringify({ error: "Failed to link account", details: updateProfileError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    await supabase
      .from("game_bot_link_requests")
      .update({
        confirmed_by: user.id,
        confirmed_at: new Date().toISOString(),
      })
      .eq("id", linkRequest.id);

    return new Response(
      JSON.stringify({
        success: true,
        chat_id: linkRequest.chat_id,
        telegram_username: linkRequest.telegram_username,
        bot_username: GAME_BOT_USERNAME,
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

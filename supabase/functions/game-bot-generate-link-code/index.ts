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

    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: { user }, error: userError } = await supabase.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", details: userError?.message }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: profile } = await supabase
      .from("user_profiles")
      .select("game_bot_chat_id, game_bot_username, game_bot_linked_at")
      .eq("id", user.id)
      .maybeSingle();

    if (profile?.game_bot_chat_id) {
      return new Response(
        JSON.stringify({
          already_linked: true,
          game_bot_username: profile.game_bot_username,
          linked_at: profile.game_bot_linked_at,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data, error } = await supabase.rpc("generate_game_bot_linking_code", {
      p_user_id: user.id,
    });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message || "Failed to generate code" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!data || data.length === 0) {
      return new Response(
        JSON.stringify({ error: "Failed to generate code" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result = data[0];
    const deepLink = `https://t.me/${GAME_BOT_USERNAME}?start=${result.code}`;

    return new Response(
      JSON.stringify({
        code: result.code,
        expires_at: result.expires_at,
        deep_link: deepLink,
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

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "No authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    const supabaseUser = createClient(supabaseUrl, supabaseServiceKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false }
    });

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid user token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { target_user_id, reason } = await req.json();

    if (!target_user_id) {
      return new Response(
        JSON.stringify({ success: false, error: "target_user_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: tokenResult, error: tokenError } = await supabaseUser.rpc(
      'create_impersonation_token',
      {
        p_target_user_id: target_user_id,
        p_reason: reason || 'Admin support session',
        p_ip_address: req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown',
        p_user_agent: req.headers.get('user-agent') || 'unknown'
      }
    );

    if (tokenError) {
      return new Response(
        JSON.stringify({ success: false, error: tokenError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!tokenResult.success) {
      return new Response(
        JSON.stringify({ success: false, error: tokenResult.error }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: targetUser, error: targetError } = await supabaseAdmin.auth.admin.getUserById(target_user_id);
    if (targetError || !targetUser) {
      return new Response(
        JSON.stringify({ success: false, error: "Target user not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: magicLinkData, error: magicLinkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: targetUser.user.email!,
      options: {
        redirectTo: `${req.headers.get('origin') || supabaseUrl}/wallet?impersonated=true`
      }
    });

    if (magicLinkError) {
      return new Response(
        JSON.stringify({ success: false, error: "Failed to generate login link: " + magicLinkError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const actionLink = magicLinkData.properties?.action_link;

    if (!actionLink) {
      return new Response(
        JSON.stringify({ success: false, error: "Failed to generate action link" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const url = new URL(actionLink);
    const token = url.searchParams.get('token');
    const type = url.searchParams.get('type');

    if (!token || !type) {
      return new Response(
        JSON.stringify({ success: false, error: "Failed to extract token from link" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: sessionData, error: verifyError } = await supabaseAdmin.auth.verifyOtp({
      token_hash: token,
      type: type as any
    });

    if (verifyError || !sessionData.session) {
      return new Response(
        JSON.stringify({ success: false, error: "Failed to create session: " + (verifyError?.message || 'Unknown error') }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        access_token: sessionData.session.access_token,
        refresh_token: sessionData.session.refresh_token,
        expires_in: sessionData.session.expires_in,
        expires_at: sessionData.session.expires_at,
        user: sessionData.user,
        target_email: targetUser.user.email,
        session_id: tokenResult.session_id,
        impersonation_expires_at: tokenResult.expires_at,
        message: "Use these tokens to sign in as this user. Session is active and ready to use."
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
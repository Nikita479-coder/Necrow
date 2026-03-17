import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const { email, adminKey } = await req.json();

    const expectedKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.slice(-20);
    if (adminKey !== expectedKey) {
      return new Response(
        JSON.stringify({ error: "Invalid admin key" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!email) {
      return new Response(
        JSON.stringify({ error: "email is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: userData, error: userError } = await supabaseAdmin.auth.admin.listUsers();

    if (userError) {
      return new Response(
        JSON.stringify({ error: userError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const user = userData.users.find(u => u.email === email);

    if (!user) {
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: factors, error: factorsError } = await supabaseAdmin.auth.admin.mfa.listFactors({
      userId: user.id
    });

    if (factorsError) {
      return new Response(
        JSON.stringify({ error: factorsError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const unverifiedFactors = factors.factors.filter(f => f.status === 'unverified');

    for (const factor of unverifiedFactors) {
      const { error: deleteError } = await supabaseAdmin.auth.admin.mfa.deleteFactor({
        id: factor.id,
        userId: user.id
      });

      if (deleteError) {
        console.error('Failed to delete factor:', factor.id, deleteError);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Cleaned up ${unverifiedFactors.length} stuck MFA factor(s)`,
        factorsRemoved: unverifiedFactors.length
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

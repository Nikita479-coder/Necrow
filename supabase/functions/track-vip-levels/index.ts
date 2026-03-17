import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

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
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase environment variables");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log("Starting daily VIP snapshot capture...");

    // Capture snapshots for all users
    const { data: snapshotData, error: snapshotError } = await supabase.rpc(
      "capture_all_daily_vip_snapshots"
    );

    if (snapshotError) {
      throw new Error(`Failed to capture snapshots: ${snapshotError.message}`);
    }

    console.log("Snapshots captured:", snapshotData);

    // Detect VIP changes from snapshots
    const { data: changesData, error: changesError } = await supabase.rpc(
      "detect_vip_changes_from_snapshots"
    );

    if (changesError) {
      throw new Error(`Failed to detect changes: ${changesError.message}`);
    }

    console.log("VIP changes detected:", changesData);

    const result = {
      success: true,
      message: "Daily VIP snapshot and change detection completed successfully",
      snapshots: snapshotData || {},
      changes: changesData || {},
    };

    console.log("VIP tracking complete:", result);

    return new Response(JSON.stringify(result), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    console.error("Error in VIP tracking:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
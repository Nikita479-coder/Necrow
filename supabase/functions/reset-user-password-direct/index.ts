import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async () => {
  return new Response(JSON.stringify({ error: "Function disabled" }), {
    status: 403,
    headers: { "Content-Type": "application/json" },
  });
});
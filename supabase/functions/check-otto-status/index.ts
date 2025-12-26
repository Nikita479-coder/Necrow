import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const authHeader = req.headers.get('Authorization')!;

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const url = new URL(req.url);
    const sessionId = url.searchParams.get('sessionId');
    const token = url.searchParams.get('token');

    if (!sessionId && !token) {
      return new Response(
        JSON.stringify({ error: 'Missing sessionId or token parameter' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let query = supabase
      .from('otto_verification_sessions')
      .select('*')
      .eq('user_id', user.id);

    if (sessionId) {
      query = query.eq('session_id', sessionId);
    } else if (token) {
      query = query.eq('token', token);
    }

    const { data: session, error: sessionError } = await query.single();

    if (sessionError || !session) {
      return new Response(
        JSON.stringify({ error: 'Session not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { data: result, error: resultError } = await supabase
      .from('otto_verification_results')
      .select('*')
      .eq('session_id', session.session_id)
      .maybeSingle();

    const response = {
      session: {
        id: session.id,
        sessionId: session.session_id,
        token: session.token,
        status: session.status,
        scopes: session.scopes,
        nextStep: session.next_step,
        expiresAt: session.expires_at,
        attemptNumber: session.attempt_number,
        createdAt: session.created_at,
        updatedAt: session.updated_at,
      },
      result: result ? {
        livenessScore: result.liveness_score,
        livenessFine: result.liveness_fine,
        deepfakeScore: result.deepfake_score,
        deepfakeFine: result.deepfake_fine,
        qualityData: result.quality_data,
        demographicData: result.demographic_data,
        verificationPassed: result.verification_passed,
        createdAt: result.created_at,
      } : null,
    };

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Status check error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
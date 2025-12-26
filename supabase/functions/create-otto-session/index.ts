import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const OTTO_AI_APP_ID = 'bd52e589-202a-4e80-b47f-946b618ba342';
const OTTO_AI_APP_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBJZCI6ImJkNTJlNTg5LTIwMmEtNGU4MC1iNDdmLTk0NmI2MThiYTM0MiIsImlhdCI6MTc2MzIwODQxMCwiZXhwIjoyMDc0MjQ4NDEwfQ.p6WMWq8s5q_bQBVdhpBXjQrhFzdYvsztAtFnxOqnmGI';
const OTTO_AI_BASE_URL = 'https://cloud.ooto-ai.com/api/v1.0';

interface CreateSessionRequest {
  metadata?: Record<string, any>;
}

interface OttoCreateSessionResponse {
  sessionId: string;
  token: string;
  url: string;
}

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

    const { metadata = {} }: CreateSessionRequest = await req.json();

    // Check attempt count for rate limiting
    const { data: recentSessions, error: countError } = await supabase
      .from('otto_verification_sessions')
      .select('attempt_number')
      .eq('user_id', user.id)
      .gte('created_at', new Date(Date.now() - 3600000).toISOString())
      .order('created_at', { ascending: false })
      .limit(1);

    if (countError) {
      console.error('Error checking attempt count:', countError);
    }

    const attemptNumber = recentSessions && recentSessions.length > 0 
      ? recentSessions[0].attempt_number + 1 
      : 1;

    if (attemptNumber > 5) {
      return new Response(
        JSON.stringify({ error: 'Too many verification attempts. Please try again later.' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const callbackUrl = `${supabaseUrl}/functions/v1/otto-callback`;
    const returnUrl = `${req.headers.get('origin') || 'https://xcfyfzhcgphmiqvdfhrf.supabase.co'}/kyc?session=complete`;

    const ottoRequestBody = {
      scopes: ['liveness', 'deepfake'],
      metadata: {
        user_id: user.id,
        attempt_number: attemptNumber,
        ...metadata,
      },
      callbackUrl,
      returnUrl,
      ttlSec: 86400,
    };

    const ottoResponse = await fetch(`${OTTO_AI_BASE_URL}/flow/sessions`, {
      method: 'POST',
      headers: {
        'APP-ID': OTTO_AI_APP_ID,
        'APP-KEY': OTTO_AI_APP_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(ottoRequestBody),
    });

    if (!ottoResponse.ok) {
      const errorText = await ottoResponse.text();
      console.error('Otto AI API error:', errorText);
      return new Response(
        JSON.stringify({ error: 'Failed to create verification session', details: errorText }),
        { status: ottoResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const ottoData: OttoCreateSessionResponse = await ottoResponse.json();

    const expiresAt = new Date(Date.now() + 86400000).toISOString();

    const { data: sessionData, error: insertError } = await supabase
      .from('otto_verification_sessions')
      .insert({
        session_id: ottoData.sessionId,
        token: ottoData.token,
        url: ottoData.url,
        user_id: user.id,
        status: 'CREATED',
        scopes: ['liveness', 'deepfake'],
        expires_at: expiresAt,
        metadata: ottoRequestBody.metadata,
        attempt_number: attemptNumber,
      })
      .select()
      .single();

    if (insertError) {
      console.error('Database insert error:', insertError);
      return new Response(
        JSON.stringify({ error: 'Failed to store session', details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        sessionId: ottoData.sessionId,
        token: ottoData.token,
        url: ottoData.url,
        attemptNumber,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
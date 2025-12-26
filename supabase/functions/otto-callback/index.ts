import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const LIVENESS_THRESHOLD = 0.75;
const DEEPFAKE_THRESHOLD = 0.75;

interface OttoCallbackPayload {
  status: string;
  scopes: string[];
  nextStep: string | null;
  expiresAt: string;
  result?: {
    liveness?: {
      fine: boolean;
      score: number;
    };
    deepfake?: {
      fine: boolean;
      score: number;
    };
    quality?: any;
    demography?: any;
    landmarks?: any;
    box?: any;
    search?: any;
  };
  metadata?: {
    user_id?: string;
    attempt_number?: number;
  };
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
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const payload: OttoCallbackPayload = await req.json();
    
    console.log('Received Otto AI callback:', JSON.stringify(payload, null, 2));

    const userId = payload.metadata?.user_id;
    if (!userId) {
      console.error('No user_id in callback metadata');
      return new Response(
        JSON.stringify({ error: 'Missing user_id in metadata' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const urlPath = new URL(req.url).pathname;
    const tokenMatch = urlPath.match(/\/otto-callback\/([^\/]+)/);
    const token = tokenMatch ? tokenMatch[1] : null;

    let sessionId: string | null = null;

    if (token) {
      const { data: session } = await supabase
        .from('otto_verification_sessions')
        .select('session_id')
        .eq('token', token)
        .single();
      
      if (session) {
        sessionId = session.session_id;
      }
    }

    if (!sessionId) {
      const { data: latestSession } = await supabase
        .from('otto_verification_sessions')
        .select('session_id')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      if (latestSession) {
        sessionId = latestSession.session_id;
      }
    }

    if (!sessionId) {
      console.error('Could not find session for callback');
      return new Response(
        JSON.stringify({ error: 'Session not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { error: updateError } = await supabase
      .from('otto_verification_sessions')
      .update({
        status: payload.status,
        next_step: payload.nextStep,
        updated_at: new Date().toISOString(),
      })
      .eq('session_id', sessionId);

    if (updateError) {
      console.error('Error updating session:', updateError);
    }

    if (payload.status === 'DONE' && payload.result) {
      const livenessScore = payload.result.liveness?.score || 0;
      const livenessFine = payload.result.liveness?.fine || false;
      const deepfakeScore = payload.result.deepfake?.score || 0;
      const deepfakeFine = payload.result.deepfake?.fine || false;

      const verificationPassed = 
        livenessFine && 
        deepfakeFine && 
        livenessScore >= LIVENESS_THRESHOLD && 
        deepfakeScore >= DEEPFAKE_THRESHOLD;

      const { error: resultError } = await supabase
        .from('otto_verification_results')
        .insert({
          session_id: sessionId,
          user_id: userId,
          liveness_score: livenessScore,
          liveness_fine: livenessFine,
          deepfake_score: deepfakeScore,
          deepfake_fine: deepfakeFine,
          quality_data: payload.result.quality || {},
          demographic_data: payload.result.demography || null,
          landmarks: payload.result.landmarks || null,
          box: payload.result.box || null,
          raw_response: payload,
          verification_passed: verificationPassed,
        });

      if (resultError) {
        console.error('Error inserting verification result:', resultError);
      } else {
        const { data: kycData } = await supabase
          .from('kyc_verifications')
          .select('kyc_status')
          .eq('user_id', userId)
          .single();

        if (verificationPassed) {
          const { error: kycUpdateError } = await supabase
            .from('kyc_verifications')
            .upsert({
              user_id: userId,
              otto_session_id: sessionId,
              kyc_status: kycData ? kycData.kyc_status : 'pending',
              updated_at: new Date().toISOString(),
            });

          if (kycUpdateError) {
            console.error('Error updating KYC verification:', kycUpdateError);
          }

          const { error: profileError } = await supabase
            .from('user_profiles')
            .update({ kyc_level: 1 })
            .eq('user_id', userId);

          if (profileError) {
            console.error('Error updating user profile:', profileError);
          }
        } else {
          console.log('Verification failed:', {
            livenessScore,
            livenessFine,
            deepfakeScore,
            deepfakeFine,
          });
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, status: payload.status }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Callback processing error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
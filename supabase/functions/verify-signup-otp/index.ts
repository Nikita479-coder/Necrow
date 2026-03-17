import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface VerifyRequest {
  email: string;
  code: string;
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

    const requestData: VerifyRequest = await req.json();
    const { email, code } = requestData;

    if (!email || !email.includes('@')) {
      throw new Error('Valid email address is required');
    }

    if (!code || code.length !== 6) {
      throw new Error('6-digit verification code is required');
    }

    const normalizedEmail = email.toLowerCase().trim();

    const { data: verifyResult, error: verifyError } = await supabase.rpc('verify_email_code', {
      p_email: normalizedEmail,
      p_code: code,
    });

    if (verifyError) {
      throw new Error('Verification failed: ' + verifyError.message);
    }

    if (!verifyResult.success) {
      return new Response(
        JSON.stringify({
          success: false,
          error: verifyResult.error,
          attempts_remaining: verifyResult.attempts_remaining,
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email verified successfully',
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    console.error('Error verifying OTP:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});

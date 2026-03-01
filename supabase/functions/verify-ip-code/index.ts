import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface VerifyRequest {
  code: string;
  userId?: string;
  trustDurationDays?: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
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
    const { code, userId: providedUserId, trustDurationDays = 30 } = requestData;

    if (!code) {
      throw new Error('Verification code is required');
    }

    // Get user ID from auth token if not provided
    let userId = providedUserId;
    
    if (!userId) {
      const authHeader = req.headers.get('Authorization');
      if (authHeader) {
        const token = authHeader.replace('Bearer ', '');
        const { data: { user }, error: authError } = await supabase.auth.getUser(token);
        
        if (!authError && user) {
          userId = user.id;
        }
      }
    }

    if (!userId) {
      throw new Error('User ID is required. Please provide userId or a valid auth token.');
    }

    // Verify the code using database function
    const { data: result, error: verifyError } = await supabase.rpc('verify_ip_code', {
      p_user_id: userId,
      p_code: code,
      p_trust_duration_days: trustDurationDays,
    });

    if (verifyError) {
      console.error('Error verifying code:', verifyError);
      throw new Error('Failed to verify code');
    }

    if (!result.success) {
      return new Response(
        JSON.stringify({
          success: false,
          error: result.error || 'Invalid verification code',
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    // Send notification about new trusted device
    try {
      await supabase.from('notifications').insert({
        user_id: userId,
        type: 'security',
        title: 'New Device Trusted',
        message: `A new device has been added to your trusted devices. IP: ${result.ip_address}`,
        is_read: false,
        data: {
          trusted_ip_id: result.trusted_ip_id,
          ip_address: result.ip_address,
        },
      });
    } catch (notifError) {
      console.error('Failed to send notification:', notifError);
      // Don't fail the request if notification fails
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: result.message || 'Device verified and trusted',
        trustedIpId: result.trusted_ip_id,
        ipAddress: result.ip_address,
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error: any) {
    console.error('Error in verify-ip-code:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to verify code',
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
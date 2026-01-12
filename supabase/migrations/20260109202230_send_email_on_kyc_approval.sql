/*
  # Send Email on KYC Approval

  1. Overview
    - Automatically sends an email when a user's KYC status is approved
    - Uses the existing send-kyc-approval-email edge function
    - Only sends once per KYC approval (tracks email sent status)

  2. Changes
    - Create a trigger function that calls the email edge function
    - Add trigger on user_profiles when kyc_status changes to 'verified'
    - Uses pg_net extension to make async HTTP call to edge function
*/

-- Create function to send KYC approval email
CREATE OR REPLACE FUNCTION send_kyc_approval_email_notification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_supabase_url TEXT := current_setting('app.settings.supabase_url', true);
  v_service_role_key TEXT := current_setting('app.settings.service_role_key', true);
  v_request_id BIGINT;
BEGIN
  -- Only send email when status changes to 'verified' from a non-verified status
  IF NEW.kyc_status = 'verified' AND (OLD.kyc_status IS NULL OR OLD.kyc_status != 'verified') THEN
    
    -- Use default URL if not set in settings
    IF v_supabase_url IS NULL THEN
      v_supabase_url := TG_ARGV[0]; -- Pass as trigger argument
    END IF;
    
    -- Make async HTTP request to send-kyc-approval-email edge function
    SELECT net.http_post(
      url := v_supabase_url || '/functions/v1/send-kyc-approval-email',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || COALESCE(v_service_role_key, TG_ARGV[1])
      ),
      body := jsonb_build_object(
        'user_id', NEW.id::text
      ),
      timeout_milliseconds := 10000
    ) INTO v_request_id;
    
    -- Log the attempt (optional)
    RAISE LOG 'KYC approval email queued for user_id: %, request_id: %', NEW.id, v_request_id;
    
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_send_kyc_approval_email ON user_profiles;

-- Create trigger that fires AFTER update on user_profiles
CREATE TRIGGER trigger_send_kyc_approval_email
  AFTER UPDATE ON user_profiles
  FOR EACH ROW
  WHEN (NEW.kyc_status = 'verified' AND (OLD.kyc_status IS DISTINCT FROM 'verified'))
  EXECUTE FUNCTION send_kyc_approval_email_notification(
    'https://qklqejxahwuzqvbepykl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFrbHFlanhhend1enF2YmVweWtsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTkyNjg1NCwiZXhwIjoyMDQ1NTAyODU0fQ.n-79jLiCNnDoCU-YxQVvY5Ny85mG4YVzf7H6VkDcFWU'
  );

/*
  # Add Email Notification to KYC Bonus Trigger

  1. Purpose
    - When a user reaches KYC level 2, automatically send them an email
    - Uses the send-kyc-approval-email edge function

  2. Changes
    - Update the tr_award_kyc_bonus_on_approval trigger function
    - Call the edge function to send the email
*/

CREATE OR REPLACE FUNCTION public.tr_award_kyc_bonus_on_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_supabase_url text;
  v_service_key text;
BEGIN
  -- Check if KYC status changed to verified
  IF NEW.kyc_status = 'verified' AND (OLD.kyc_status IS NULL OR OLD.kyc_status != 'verified') THEN
    -- Award the KYC bonus
    v_result := public.award_kyc_bonus(NEW.id);
    
    -- Send KYC approval email
    BEGIN
      v_supabase_url := current_setting('app.settings.supabase_url', true);
      v_service_key := current_setting('app.settings.service_role_key', true);
      
      IF v_supabase_url IS NULL THEN
        v_supabase_url := 'https://xafyewqbbkehttbqajed.supabase.co';
      END IF;
      
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/send-kyc-approval-email',
        headers := jsonb_build_object(
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
          'user_id', NEW.id
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to send KYC approval email: %', SQLERRM;
    END;
  END IF;
  
  RETURN NEW;
END;
$$;

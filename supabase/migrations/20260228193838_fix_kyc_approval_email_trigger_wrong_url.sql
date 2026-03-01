/*
  # Fix KYC Approval Email Trigger - Wrong Supabase URL

  ## Problem
  The trigger `trigger_send_kyc_approval_email` was pointing to an old Supabase
  project URL (`qklqejxahwuzqvbepykl.supabase.co`) that no longer exists.
  Every HTTP POST from pg_net failed with "Couldn't resolve host name",
  meaning zero KYC approval emails were ever delivered.

  ## Fix
  - Drops and recreates the trigger with the correct project URL
  - Uses the project's anon key for JWT gateway verification
  - The edge function creates its own service-role client internally

  ## Changes
  - Recreated `trigger_send_kyc_approval_email` on `user_profiles`
    with correct URL: `xcfyfzhcgphmiqvdfhrf.supabase.co`
*/

DROP TRIGGER IF EXISTS trigger_send_kyc_approval_email ON user_profiles;

CREATE TRIGGER trigger_send_kyc_approval_email
  AFTER UPDATE ON user_profiles
  FOR EACH ROW
  WHEN (NEW.kyc_status = 'verified' AND OLD.kyc_status IS DISTINCT FROM 'verified')
  EXECUTE FUNCTION send_kyc_approval_email_notification(
    'https://xcfyfzhcgphmiqvdfhrf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhjZnlmemhjZ3BobWlxdmRmaHJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwODQ0NjUsImV4cCI6MjA3NzY2MDQ2NX0.74RgE-bEtfKxT8glAaYMG1Bm-doZ_oSf6wOwMoQPxqc'
  );

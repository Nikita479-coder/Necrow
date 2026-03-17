/*
  # Create Function to Expire Auto-Accept Settings

  ## Summary
  Creates a function that expires auto-accept settings when the 24-hour period ends.
  Called periodically by the expire-pending-trades edge function.

  ## Behavior
  - Finds users with copy_auto_accept_until < NOW()
  - Sets copy_auto_accept_enabled = false
  - Sends notification that auto-accept has expired
  - Returns count of expired settings
*/

CREATE OR REPLACE FUNCTION expire_auto_accept_settings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
  v_count integer := 0;
BEGIN
  FOR v_user IN
    SELECT id, full_name
    FROM user_profiles
    WHERE copy_auto_accept_enabled = true
    AND copy_auto_accept_until IS NOT NULL
    AND copy_auto_accept_until < NOW()
  LOOP
    UPDATE user_profiles
    SET 
      copy_auto_accept_enabled = false,
      copy_auto_accept_until = NULL,
      updated_at = NOW()
    WHERE id = v_user.id;

    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_user.id,
      'system',
      'Auto-Accept Period Ended',
      'Your 24-hour copy trading auto-accept period has ended. Enable it again to continue automatic trade acceptance.',
      false
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

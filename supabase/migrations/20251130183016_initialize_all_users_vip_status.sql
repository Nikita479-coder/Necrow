/*
  # Initialize VIP Status for All Users

  1. Changes
    - Calculate and set VIP level for all existing users
    - Ensure all users have a VIP status record

  2. Purpose
    - Backfill VIP status for existing users
    - Enable immediate rebate functionality
*/

-- Calculate VIP status for all existing users
DO $$
DECLARE
  v_user_record RECORD;
BEGIN
  FOR v_user_record IN
    SELECT DISTINCT id FROM auth.users
  LOOP
    PERFORM calculate_user_vip_level(v_user_record.id);
  END LOOP;
END $$;
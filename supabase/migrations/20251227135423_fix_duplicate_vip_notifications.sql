/*
  # Fix Duplicate VIP Upgrade Notifications
  
  Problem: The detect_vip_changes_from_snapshots() function creates duplicate notifications
  every time it runs if the user upgraded today.
  
  Solution: Make the notification creation idempotent by checking if a notification
  already exists for this user and tier change today before creating a new one.
*/

CREATE OR REPLACE FUNCTION detect_vip_changes_from_snapshots()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_change record;
  v_upgrades integer := 0;
  v_downgrades integer := 0;
  v_maintained integer := 0;
  v_notification_exists boolean;
BEGIN
  -- Compare yesterday's snapshot to today's
  FOR v_change IN
    SELECT 
      today.user_id,
      yesterday.vip_level as old_level,
      today.vip_level as new_level,
      yesterday.tier_name as old_tier,
      today.tier_name as new_tier
    FROM vip_daily_snapshots today
    LEFT JOIN vip_daily_snapshots yesterday 
      ON today.user_id = yesterday.user_id 
      AND yesterday.snapshot_date = CURRENT_DATE - INTERVAL '1 day'
    WHERE today.snapshot_date = CURRENT_DATE
      AND (yesterday.vip_level IS NULL OR yesterday.vip_level != today.vip_level)
  LOOP
    IF v_change.old_level IS NULL THEN
      -- New user, skip
      CONTINUE;
    ELSIF v_change.new_level > v_change.old_level THEN
      v_upgrades := v_upgrades + 1;
      
      -- Check if a notification already exists for this upgrade today
      SELECT EXISTS(
        SELECT 1 
        FROM notifications
        WHERE user_id = v_change.user_id
          AND type = 'vip_upgrade'
          AND message LIKE '%' || v_change.old_tier || '%' || v_change.new_tier || '%'
          AND created_at >= CURRENT_DATE
      ) INTO v_notification_exists;
      
      -- Only create notification if it doesn't already exist
      IF NOT v_notification_exists THEN
        INSERT INTO notifications (
          user_id,
          type,
          title,
          message,
          read
        ) VALUES (
          v_change.user_id,
          'vip_upgrade',
          'VIP Tier Upgrade!',
          'Congratulations! You have been upgraded from ' || v_change.old_tier || ' to ' || v_change.new_tier || '!',
          false
        );
      END IF;
    ELSIF v_change.new_level < v_change.old_level THEN
      v_downgrades := v_downgrades + 1;
      -- Downgrade notification is already handled by the trigger
      -- But we can log it here for redundancy
    END IF;
  END LOOP;
  
  RETURN jsonb_build_object(
    'upgrades', v_upgrades,
    'downgrades', v_downgrades,
    'checked_date', CURRENT_DATE
  );
END;
$$;

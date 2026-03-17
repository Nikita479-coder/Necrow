/*
  # Create VIP Snapshot Capture Functions

  1. New Functions
    - `capture_daily_vip_snapshot` - Capture snapshot for a single user
    - `capture_all_daily_vip_snapshots` - Capture snapshots for all users
    - `detect_vip_changes_from_snapshots` - Compare today vs yesterday and detect changes

  2. Purpose
    - Capture daily snapshots of all users' VIP status
    - Detect level changes by comparing snapshots
    - Provide bulletproof change tracking even if real-time triggers fail

  3. Security
    - All functions use SECURITY DEFINER
    - Can be called by edge functions with service role
*/

-- Function to capture a single user's VIP snapshot
CREATE OR REPLACE FUNCTION capture_daily_vip_snapshot(p_user_id uuid, p_snapshot_date date DEFAULT CURRENT_DATE)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_vip_status record;
  v_tier_name text;
BEGIN
  -- Get current VIP status
  SELECT * INTO v_vip_status
  FROM user_vip_status
  WHERE user_id = p_user_id;
  
  -- If no VIP status exists, initialize it first
  IF NOT FOUND THEN
    PERFORM calculate_user_vip_level(p_user_id);
    
    SELECT * INTO v_vip_status
    FROM user_vip_status
    WHERE user_id = p_user_id;
  END IF;
  
  -- Get tier name
  v_tier_name := get_vip_tier_name(v_vip_status.current_level);
  
  -- Insert snapshot (or update if already exists for today)
  INSERT INTO vip_daily_snapshots (
    user_id,
    snapshot_date,
    vip_level,
    tier_name,
    volume_30d,
    volume_all_time,
    commission_rate,
    rebate_rate
  ) VALUES (
    p_user_id,
    p_snapshot_date,
    v_vip_status.current_level,
    v_tier_name,
    v_vip_status.volume_30d,
    COALESCE((SELECT total_volume_all_time FROM referral_stats WHERE user_id = p_user_id), 0),
    v_vip_status.commission_rate,
    v_vip_status.rebate_rate
  )
  ON CONFLICT (user_id, snapshot_date) DO UPDATE SET
    vip_level = EXCLUDED.vip_level,
    tier_name = EXCLUDED.tier_name,
    volume_30d = EXCLUDED.volume_30d,
    volume_all_time = EXCLUDED.volume_all_time,
    commission_rate = EXCLUDED.commission_rate,
    rebate_rate = EXCLUDED.rebate_rate;
END;
$$;

-- Function to capture snapshots for all users
CREATE OR REPLACE FUNCTION capture_all_daily_vip_snapshots(p_snapshot_date date DEFAULT CURRENT_DATE)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_total_users integer := 0;
  v_successful integer := 0;
  v_failed integer := 0;
BEGIN
  -- First, recalculate VIP levels for all users
  PERFORM recalculate_all_vip_levels();
  
  -- Loop through all users and capture snapshots
  FOR v_user_id IN 
    SELECT id FROM auth.users
  LOOP
    BEGIN
      PERFORM capture_daily_vip_snapshot(v_user_id, p_snapshot_date);
      v_successful := v_successful + 1;
    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed + 1;
      RAISE WARNING 'Failed to capture snapshot for user %: %', v_user_id, SQLERRM;
    END;
    
    v_total_users := v_total_users + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'snapshot_date', p_snapshot_date,
    'total_users', v_total_users,
    'successful', v_successful,
    'failed', v_failed
  );
END;
$$;

-- Function to detect VIP changes from snapshots
CREATE OR REPLACE FUNCTION detect_vip_changes_from_snapshots()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_change record;
  v_upgrades integer := 0;
  v_downgrades integer := 0;
  v_maintained integer := 0;
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
      
      -- Create notification for upgrade
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
/*
  # Unify VIP Tracking to Single Source of Truth

  1. Changes
    - Make `user_vip_status` the single source of truth for VIP levels
    - Update `calculate_user_vip_level` to be the primary VIP calculation function
    - Keep `referral_stats.vip_level` in sync via trigger
    - Remove `update_user_vip_level` usage from triggers
    - All VIP changes now flow through `user_vip_status`

  2. Purpose
    - Eliminate dual storage inconsistencies
    - Make all VIP tracking reliable and consistent
    - Ensure all changes are properly tracked by the trigger system

  3. Security
    - Maintains existing RLS policies
    - Uses SECURITY DEFINER for consistency
*/

-- Update the trigger on futures_positions to use the correct function
DROP TRIGGER IF EXISTS update_vip_after_position ON futures_positions;

CREATE TRIGGER update_vip_after_position
  AFTER INSERT ON futures_positions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_vip_after_position();

-- Update the trigger function to call the correct calculation function
CREATE OR REPLACE FUNCTION trigger_update_vip_after_position()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update VIP level when new position is opened
  IF TG_OP = 'INSERT' THEN
    PERFORM calculate_user_vip_level(NEW.user_id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create a trigger to keep referral_stats.vip_level in sync
CREATE OR REPLACE FUNCTION sync_vip_to_referral_stats()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update referral_stats whenever user_vip_status changes
  UPDATE referral_stats
  SET 
    vip_level = NEW.current_level,
    updated_at = now()
  WHERE user_id = NEW.user_id;
  
  -- If no record exists, create one
  IF NOT FOUND THEN
    INSERT INTO referral_stats (
      user_id,
      vip_level,
      total_volume_30d,
      total_volume_all_time
    ) VALUES (
      NEW.user_id,
      NEW.current_level,
      NEW.volume_30d,
      0
    )
    ON CONFLICT (user_id) DO UPDATE SET
      vip_level = NEW.current_level,
      updated_at = now();
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create the sync trigger
DROP TRIGGER IF EXISTS sync_vip_level_to_referral_stats ON user_vip_status;

CREATE TRIGGER sync_vip_level_to_referral_stats
  AFTER INSERT OR UPDATE ON user_vip_status
  FOR EACH ROW
  EXECUTE FUNCTION sync_vip_to_referral_stats();
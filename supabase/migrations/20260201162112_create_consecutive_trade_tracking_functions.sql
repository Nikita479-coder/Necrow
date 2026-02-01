/*
  # Create Consecutive Trade Tracking Functions

  ## Summary
  Creates helper functions to track consecutive trading days for locked bonuses.
  This is used by the KYC + TrustPilot Review Bonus which requires users to trade
  for 30 consecutive days.

  ## New Functions
  
  ### record_qualifying_trade
  Called when a position is closed that meets the duration requirement.
  Updates daily trade count and consecutive day tracking.

  ### check_and_update_consecutive_days  
  Called at end of day or when daily trade requirement is met.
  Updates consecutive day count based on whether user met today's requirement.

  ### reset_daily_trade_counts
  Called at midnight to reset daily counters and check for broken streaks.

  ## Logic
  - Position must be held for at least 15 minutes (daily_trade_duration_minutes)
  - User must complete at least 2 trades per day (daily_trades_required)
  - Missing a day resets the consecutive day counter to 0
  - Streak continues if user trades every calendar day
*/

-- Function to record a qualifying trade and update consecutive tracking
CREATE OR REPLACE FUNCTION record_qualifying_trade(
  p_user_id uuid,
  p_locked_bonus_id uuid,
  p_position_duration_minutes integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_today date := CURRENT_DATE;
  v_is_new_day boolean;
  v_new_daily_count integer;
  v_consecutive_updated boolean := false;
BEGIN
  -- Get the locked bonus with requirements
  SELECT * INTO v_bonus
  FROM locked_bonuses
  WHERE id = p_locked_bonus_id
    AND user_id = p_user_id
    AND status = 'active'
    AND consecutive_trading_days_required IS NOT NULL
  FOR UPDATE;

  -- If no bonus found or no consecutive requirement, skip
  IF NOT FOUND OR v_bonus.daily_trade_duration_minutes IS NULL THEN
    RETURN jsonb_build_object('success', true, 'tracked', false, 'reason', 'No consecutive requirement');
  END IF;

  -- Check if position meets duration requirement
  IF p_position_duration_minutes < v_bonus.daily_trade_duration_minutes THEN
    RETURN jsonb_build_object(
      'success', true, 
      'tracked', false, 
      'reason', 'Position duration ' || p_position_duration_minutes || ' minutes is less than required ' || v_bonus.daily_trade_duration_minutes || ' minutes'
    );
  END IF;

  -- Check if this is a new day
  v_is_new_day := (v_bonus.last_qualifying_trade_date IS NULL OR v_bonus.last_qualifying_trade_date < v_today);

  IF v_is_new_day THEN
    -- First qualifying trade of the day
    v_new_daily_count := 1;
    
    -- Check if streak is broken (missed a day)
    IF v_bonus.last_qualifying_trade_date IS NOT NULL AND 
       v_today - v_bonus.last_qualifying_trade_date > 1 THEN
      -- Streak broken - reset consecutive days
      UPDATE locked_bonuses
      SET 
        current_consecutive_days = 0,
        daily_trade_count_today = 1,
        updated_at = now()
      WHERE id = p_locked_bonus_id;
      
      RETURN jsonb_build_object(
        'success', true,
        'tracked', true,
        'daily_count', 1,
        'streak_broken', true,
        'consecutive_days', 0,
        'message', 'Streak reset - you missed a day. Starting fresh!'
      );
    END IF;
  ELSE
    -- Same day - increment counter
    v_new_daily_count := v_bonus.daily_trade_count_today + 1;
  END IF;

  -- Update daily trade count
  UPDATE locked_bonuses
  SET 
    daily_trade_count_today = v_new_daily_count,
    updated_at = now()
  WHERE id = p_locked_bonus_id;

  -- Check if daily requirement is now met
  IF v_new_daily_count >= v_bonus.daily_trades_required AND 
     (v_bonus.last_qualifying_trade_date IS NULL OR v_bonus.last_qualifying_trade_date < v_today) THEN
    -- Daily requirement met - update consecutive days
    v_consecutive_updated := true;
    
    UPDATE locked_bonuses
    SET 
      current_consecutive_days = CASE 
        -- If this is day 1 or continuing streak from yesterday
        WHEN last_qualifying_trade_date IS NULL OR last_qualifying_trade_date = v_today - 1 THEN
          current_consecutive_days + 1
        ELSE
          1  -- Starting fresh after missed day
      END,
      last_qualifying_trade_date = v_today,
      updated_at = now()
    WHERE id = p_locked_bonus_id
    RETURNING current_consecutive_days INTO v_bonus.current_consecutive_days;

    -- Check if bonus should be unlocked
    IF v_bonus.current_consecutive_days >= v_bonus.consecutive_trading_days_required THEN
      -- Create notification for reaching consecutive day goal
      INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
      VALUES (
        p_user_id,
        'reward',
        'Consecutive Trading Days Complete!',
        'Congratulations! You have completed ' || v_bonus.consecutive_trading_days_required || ' consecutive trading days. ' ||
        'Check your bonus progress to see if all requirements are met!',
        false,
        jsonb_build_object(
          'locked_bonus_id', p_locked_bonus_id,
          'consecutive_days_completed', v_bonus.current_consecutive_days
        ),
        '/wallet'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'tracked', true,
    'daily_count', v_new_daily_count,
    'daily_required', v_bonus.daily_trades_required,
    'consecutive_days', v_bonus.current_consecutive_days,
    'consecutive_required', v_bonus.consecutive_trading_days_required,
    'day_completed', v_consecutive_updated,
    'message', CASE 
      WHEN v_consecutive_updated THEN 
        'Day ' || v_bonus.current_consecutive_days || ' of ' || v_bonus.consecutive_trading_days_required || ' completed!'
      ELSE 
        'Trade ' || v_new_daily_count || ' of ' || v_bonus.daily_trades_required || ' for today'
    END
  );
END;
$$;

-- Function to reset daily trade counts at midnight (called by scheduled job)
CREATE OR REPLACE FUNCTION reset_daily_trade_counts_for_consecutive_bonuses()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := CURRENT_DATE;
  v_yesterday date := CURRENT_DATE - 1;
  v_bonus record;
  v_reset_count integer := 0;
  v_streak_broken_count integer := 0;
BEGIN
  -- Process all active bonuses with consecutive requirements
  FOR v_bonus IN
    SELECT lb.*, up.username, up.email
    FROM locked_bonuses lb
    LEFT JOIN user_profiles up ON up.id = lb.user_id
    WHERE lb.status = 'active'
      AND lb.expires_at > now()
      AND lb.consecutive_trading_days_required IS NOT NULL
      AND lb.daily_trade_count_today > 0  -- Had trades yesterday
  LOOP
    -- Check if yesterday's requirement was NOT met (less than required trades)
    IF v_bonus.daily_trade_count_today < v_bonus.daily_trades_required 
       OR v_bonus.last_qualifying_trade_date IS NULL
       OR v_bonus.last_qualifying_trade_date < v_yesterday THEN
      -- Streak is broken - user didn't complete yesterday
      IF v_bonus.current_consecutive_days > 0 THEN
        UPDATE locked_bonuses
        SET 
          current_consecutive_days = 0,
          daily_trade_count_today = 0,
          updated_at = now()
        WHERE id = v_bonus.id;

        -- Notify user their streak was reset
        INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
        VALUES (
          v_bonus.user_id,
          'account_update',
          'Trading Streak Reset',
          'Your ' || v_bonus.current_consecutive_days || '-day trading streak has been reset because you did not complete ' ||
          v_bonus.daily_trades_required || ' qualifying trades yesterday. Start again today to rebuild your streak!',
          false,
          jsonb_build_object(
            'locked_bonus_id', v_bonus.id,
            'previous_streak', v_bonus.current_consecutive_days,
            'bonus_type', v_bonus.bonus_type_name
          ),
          '/wallet'
        );

        v_streak_broken_count := v_streak_broken_count + 1;
      ELSE
        -- Just reset the daily counter
        UPDATE locked_bonuses
        SET 
          daily_trade_count_today = 0,
          updated_at = now()
        WHERE id = v_bonus.id;
      END IF;
    ELSE
      -- User completed yesterday - just reset daily counter for new day
      UPDATE locked_bonuses
      SET 
        daily_trade_count_today = 0,
        updated_at = now()
      WHERE id = v_bonus.id;
    END IF;

    v_reset_count := v_reset_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'bonuses_processed', v_reset_count,
    'streaks_broken', v_streak_broken_count,
    'processed_at', now()
  );
END;
$$;

-- Update get_user_locked_bonuses to include consecutive tracking info
DROP FUNCTION IF EXISTS public.get_user_locked_bonuses(uuid);

CREATE FUNCTION public.get_user_locked_bonuses(p_user_id uuid)
RETURNS TABLE(
  id uuid, 
  original_amount numeric, 
  current_amount numeric, 
  realized_profits numeric, 
  bonus_type_name text, 
  status text, 
  expires_at timestamp with time zone, 
  days_remaining integer, 
  created_at timestamp with time zone,
  bonus_trading_volume_completed numeric,
  bonus_trading_volume_required numeric,
  consecutive_trading_days_required integer,
  current_consecutive_days integer,
  daily_trades_required integer,
  daily_trade_duration_minutes integer,
  daily_trade_count_today integer,
  last_qualifying_trade_date date
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
SELECT 
  lb.id,
  lb.original_amount,
  lb.current_amount,
  lb.realized_profits,
  lb.bonus_type_name,
  lb.status,
  lb.expires_at,
  GREATEST(0, EXTRACT(DAY FROM (lb.expires_at - now()))::integer) as days_remaining,
  lb.created_at,
  COALESCE(lb.bonus_trading_volume_completed, 0) as bonus_trading_volume_completed,
  COALESCE(lb.bonus_trading_volume_required, 0) as bonus_trading_volume_required,
  lb.consecutive_trading_days_required,
  lb.current_consecutive_days,
  lb.daily_trades_required,
  lb.daily_trade_duration_minutes,
  lb.daily_trade_count_today,
  lb.last_qualifying_trade_date
FROM locked_bonuses lb
WHERE lb.user_id = p_user_id
ORDER BY lb.created_at DESC;
$function$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION record_qualifying_trade(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION reset_daily_trade_counts_for_consecutive_bonuses() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_locked_bonuses(uuid) TO authenticated;

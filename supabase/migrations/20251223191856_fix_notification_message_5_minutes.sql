/*
  # Fix Notification Messages to Show 5 Minutes

  1. Changes
    - Update notification trigger to say "5 minutes" instead of "10 minutes"
    - Ensure all new notifications reflect the correct time window

  2. Purpose
    - Match the 5-minute expiration window in user-facing messages
*/

CREATE OR REPLACE FUNCTION create_pending_trade_notifications()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_follower RECORD;
  v_trader_name text;
BEGIN
  -- Get trader name with fallback
  SELECT COALESCE(t.name, up.full_name, up.username, 'Unknown Trader')
  INTO v_trader_name
  FROM user_profiles up
  LEFT JOIN traders t ON t.id = up.id
  WHERE up.id = NEW.trader_id;

  -- If still null, set a default
  IF v_trader_name IS NULL THEN
    v_trader_name := 'Trader';
  END IF;

  -- Create notification for each active follower
  FOR v_follower IN
    SELECT cr.follower_id, cr.allocation_percentage, cr.leverage
    FROM copy_relationships cr
    WHERE cr.trader_id = NEW.trader_id
    AND cr.status = 'active'
    AND cr.is_active = true
  LOOP
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      data,
      read
    ) VALUES (
      v_follower.follower_id,
      'pending_copy_trade',
      'New Trade Signal',
      v_trader_name || ' opened a new ' || NEW.pair || ' position at ' || NEW.leverage || 'x leverage. You have 5 minutes to accept or decline.',
      jsonb_build_object(
        'pending_trade_id', NEW.id,
        'trader_id', NEW.trader_id,
        'trader_name', v_trader_name,
        'pair', NEW.pair,
        'side', NEW.side,
        'leverage', NEW.leverage,
        'entry_price', NEW.entry_price,
        'allocation_percentage', v_follower.allocation_percentage,
        'follower_leverage', v_follower.leverage,
        'margin_percentage', NEW.margin_percentage,
        'expires_at', NEW.expires_at
      ),
      false
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_create_pending_trade_notifications ON pending_copy_trades;

CREATE TRIGGER trigger_create_pending_trade_notifications
AFTER INSERT ON pending_copy_trades
FOR EACH ROW
WHEN (NEW.status = 'pending')
EXECUTE FUNCTION create_pending_trade_notifications();

-- Expire old pending trades
UPDATE pending_copy_trades
SET status = 'expired'
WHERE status = 'pending'
AND expires_at < NOW();

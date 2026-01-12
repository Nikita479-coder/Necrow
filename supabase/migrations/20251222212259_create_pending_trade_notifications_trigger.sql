/*
  # Create Pending Trade Notifications Trigger

  1. Trigger Function
    - Automatically creates in-app notifications for all active followers
    - Runs when a pending trade is created
    - Ensures followers can see and respond to trade signals

  2. Changes
    - Creates notification records for each active follower
    - Links to pending trade for easy acceptance/decline
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
  -- Get trader name
  SELECT COALESCE(t.name, up.full_name, up.username, 'Unknown Trader')
  INTO v_trader_name
  FROM user_profiles up
  LEFT JOIN traders t ON t.id = up.id
  WHERE up.id = NEW.trader_id;

  -- Create notification for each active follower
  FOR v_follower IN
    SELECT cr.follower_id, cr.allocated_amount, cr.leverage
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
      v_trader_name || ' opened a new ' || NEW.pair || ' position at ' || NEW.leverage || 'x leverage. You have 10 minutes to accept or decline.',
      jsonb_build_object(
        'pending_trade_id', NEW.id,
        'trader_id', NEW.trader_id,
        'trader_name', v_trader_name,
        'pair', NEW.pair,
        'leverage', NEW.leverage,
        'entry_price', NEW.entry_price,
        'allocated_amount', v_follower.allocated_amount,
        'follower_leverage', v_follower.leverage,
        'margin_percentage', NEW.margin_percentage
      ),
      false
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_create_pending_trade_notifications ON pending_copy_trades;

-- Create trigger
CREATE TRIGGER trigger_create_pending_trade_notifications
AFTER INSERT ON pending_copy_trades
FOR EACH ROW
WHEN (NEW.status = 'pending')
EXECUTE FUNCTION create_pending_trade_notifications();

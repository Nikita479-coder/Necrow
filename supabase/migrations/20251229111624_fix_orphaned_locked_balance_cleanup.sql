/*
  # Fix Orphaned Locked Balance - Cleanup Function

  Creates a function to clean up any orphaned locked_balance
  in futures_margin_wallets where users have no open positions.

  This can be called periodically or triggered to ensure
  wallet balances stay synchronized with actual positions.
*/

CREATE OR REPLACE FUNCTION cleanup_orphaned_locked_balance()
RETURNS TABLE(user_id UUID, released_amount NUMERIC)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN QUERY
  UPDATE futures_margin_wallets fmw
  SET 
    available_balance = available_balance + locked_balance,
    locked_balance = 0,
    updated_at = NOW()
  WHERE fmw.locked_balance > 0
  AND NOT EXISTS (
    SELECT 1 FROM futures_positions fp 
    WHERE fp.user_id = fmw.user_id AND fp.status = 'open'
  )
  RETURNING fmw.user_id, fmw.locked_balance;
END;
$$;

-- Also add a check to the close_position function that syncs locked_balance
-- when closing the last position for a user
CREATE OR REPLACE FUNCTION sync_locked_balance_after_close()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- When a position is closed, check if user has any remaining open positions
  IF NEW.status = 'closed' AND OLD.status = 'open' THEN
    -- If no more open positions, ensure locked_balance is 0
    IF NOT EXISTS (
      SELECT 1 FROM futures_positions 
      WHERE user_id = NEW.user_id AND status = 'open' AND position_id != NEW.position_id
    ) THEN
      UPDATE futures_margin_wallets
      SET available_balance = available_balance + locked_balance,
          locked_balance = 0,
          updated_at = NOW()
      WHERE user_id = NEW.user_id AND locked_balance > 0;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to auto-cleanup after position close
DROP TRIGGER IF EXISTS sync_locked_balance_trigger ON futures_positions;
CREATE TRIGGER sync_locked_balance_trigger
  AFTER UPDATE ON futures_positions
  FOR EACH ROW
  WHEN (NEW.status = 'closed' AND OLD.status = 'open')
  EXECUTE FUNCTION sync_locked_balance_after_close();

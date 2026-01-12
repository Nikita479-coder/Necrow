/*
  # Add Cumulative PNL Tracking and Wallet Automation
  
  ## Changes
  1. Create trigger to update cumulative PNL when allocations close
  2. Ensure copy wallets are created automatically
  3. Fix copy_relationships to track proper starting balance
  
  ## Features
  - Automatic cumulative PNL updates
  - Automatic copy wallet creation
  - Proper balance tracking from start date
*/

-- Function to update cumulative PNL when allocation closes
CREATE OR REPLACE FUNCTION update_cumulative_pnl_on_allocation_close()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only process when status changes to closed
  IF NEW.status = 'closed' AND OLD.status != 'closed' THEN
    -- Update the copy relationship's cumulative PNL
    UPDATE copy_relationships
    SET 
      cumulative_pnl = COALESCE(cumulative_pnl, 0) + COALESCE(NEW.realized_pnl, 0),
      total_pnl = (COALESCE(total_pnl::numeric, 0) + COALESCE(NEW.realized_pnl, 0))::text,
      updated_at = NOW()
    WHERE id = NEW.copy_relationship_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for allocation closing
DROP TRIGGER IF EXISTS trigger_update_cumulative_pnl ON copy_trade_allocations;
CREATE TRIGGER trigger_update_cumulative_pnl
  AFTER UPDATE ON copy_trade_allocations
  FOR EACH ROW
  EXECUTE FUNCTION update_cumulative_pnl_on_allocation_close();

-- Function to ensure copy wallet exists
CREATE OR REPLACE FUNCTION ensure_copy_wallet(p_user_id uuid, p_wallet_type text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, 'USDT', p_wallet_type, 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;
END;
$$;

-- Ensure all users with copy relationships have copy wallets
DO $$
DECLARE
  v_relationship RECORD;
  v_wallet_type text;
BEGIN
  FOR v_relationship IN
    SELECT DISTINCT follower_id, is_mock
    FROM copy_relationships
  LOOP
    v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'copy' END;
    
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (v_relationship.follower_id, 'USDT', v_wallet_type, 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;
  END LOOP;
END $$;

-- Update copy_relationships to set initial_balance from current_balance if not set
UPDATE copy_relationships
SET initial_balance = current_balance
WHERE initial_balance IS NULL OR initial_balance = '0'
AND current_balance IS NOT NULL AND current_balance != '0';

-- Add index for better performance on cumulative PNL queries
CREATE INDEX IF NOT EXISTS idx_copy_relationships_cumulative_pnl ON copy_relationships(cumulative_pnl);
CREATE INDEX IF NOT EXISTS idx_allocations_closed_at ON copy_trade_allocations(closed_at) WHERE status = 'closed';

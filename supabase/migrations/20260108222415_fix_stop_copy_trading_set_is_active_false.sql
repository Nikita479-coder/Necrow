/*
  # Fix stop_copy_trading to set is_active = false

  ## Problem
  When stopping a copy trading relationship, the function updates status to 'stopped'
  but doesn't set is_active = false. This causes the transfer_between_wallets function
  to still count the stopped relationship as active when calculating allocated funds,
  preventing users from withdrawing their funds.

  ## Solution
  - Update stop_copy_trading to also set is_active = false
  - Update any existing stopped relationships to have is_active = false

  ## Changes
  1. Fix any existing stopped relationships
  2. Recreate stop_copy_trading function with is_active = false
*/

-- First, fix any existing stopped relationships
UPDATE copy_relationships
SET is_active = false
WHERE status = 'stopped' AND is_active = true;

-- Recreate the stop_copy_trading function with the fix
CREATE OR REPLACE FUNCTION stop_copy_trading(
  p_relationship_id uuid,
  p_close_positions boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_position RECORD;
  v_total_pnl numeric := 0;
  v_return_amount numeric := 0;
BEGIN
  -- Get relationship details
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
    AND follower_id = auth.uid()
    AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Active copy trading relationship not found'
    );
  END IF;

  -- Close all open positions if requested
  IF p_close_positions THEN
    FOR v_position IN
      SELECT * FROM copy_positions
      WHERE relationship_id = p_relationship_id
        AND follower_id = auth.uid()
    LOOP
      -- Calculate final PnL
      v_total_pnl := v_total_pnl + COALESCE(v_position.unrealized_pnl, 0);

      -- Move to history
      INSERT INTO copy_position_history (
        follower_id,
        trader_id,
        relationship_id,
        is_mock,
        symbol,
        side,
        entry_price,
        exit_price,
        size,
        leverage,
        margin,
        realized_pnl,
        fees,
        opened_at,
        closed_at
      ) VALUES (
        v_position.follower_id,
        v_position.trader_id,
        v_position.relationship_id,
        v_position.is_mock,
        v_position.symbol,
        v_position.side,
        v_position.entry_price,
        v_position.current_price,
        v_position.size,
        v_position.leverage,
        v_position.margin,
        COALESCE(v_position.unrealized_pnl, 0),
        0,
        v_position.opened_at,
        now()
      );

      -- Delete position
      DELETE FROM copy_positions WHERE id = v_position.id;
    END LOOP;
  END IF;

  -- Calculate total return (initial amount + PnL)
  v_return_amount := v_relationship.copy_amount + v_total_pnl;

  -- Return funds to wallet only for real trading
  IF NOT v_relationship.is_mock AND v_return_amount > 0 THEN
    UPDATE wallets
    SET balance = balance + v_return_amount,
        updated_at = now()
    WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy';
  END IF;

  -- Update relationship status AND set is_active = false
  UPDATE copy_relationships
  SET
    status = 'stopped',
    is_active = false,
    ended_at = now(),
    total_pnl = v_total_pnl,
    updated_at = now()
  WHERE id = p_relationship_id;

  RETURN jsonb_build_object(
    'success', true,
    'total_pnl', v_total_pnl,
    'return_amount', v_return_amount,
    'message', 'Successfully stopped copy trading'
  );
END;
$$;
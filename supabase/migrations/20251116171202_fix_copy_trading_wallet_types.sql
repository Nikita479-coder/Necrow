/*
  # Fix Copy Trading Wallet Types

  1. Changes
    - Update `start_copy_trading()` function to use 'copy' wallet type for both real and mock
    - Mock trading doesn't need separate wallet, it uses is_mock flag in copy_relationships
    - Update all references from 'copy_trading' and 'mock_copy' to 'copy'
    
  2. Notes
    - Mock trading balance is virtual and managed by the is_mock flag
    - Real copy trading uses the 'copy' wallet type
    - This fixes the constraint violation error
*/

-- Update start_copy_trading function
CREATE OR REPLACE FUNCTION start_copy_trading(
  p_trader_id uuid,
  p_copy_amount numeric,
  p_leverage integer DEFAULT 1,
  p_is_mock boolean DEFAULT false,
  p_stop_loss_percent numeric DEFAULT NULL,
  p_take_profit_percent numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_relationship_id uuid;
  v_wallet_balance numeric;
BEGIN
  -- Validate inputs
  IF p_copy_amount < 100 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Minimum copy amount is 100 USDT'
    );
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Leverage must be between 1 and 125'
    );
  END IF;

  -- For mock trading, always set balance to 10000 (virtual)
  -- For real trading, check actual 'copy' wallet balance
  IF NOT p_is_mock THEN
    SELECT balance INTO v_wallet_balance
    FROM wallets
    WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy';

    IF v_wallet_balance IS NULL THEN
      -- Create copy wallet if it doesn't exist
      INSERT INTO wallets (user_id, currency, wallet_type, balance)
      VALUES (auth.uid(), 'USDT', 'copy', 0);
      v_wallet_balance := 0;
    END IF;

    IF v_wallet_balance < p_copy_amount THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Insufficient balance in copy wallet'
      );
    END IF;

    -- Deduct from real wallet
    UPDATE wallets
    SET balance = balance - p_copy_amount
    WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy';
  END IF;

  -- Create copy trading relationship
  INSERT INTO copy_relationships (
    follower_id,
    trader_id,
    copy_amount,
    leverage,
    is_mock,
    stop_loss_percent,
    take_profit_percent,
    status
  ) VALUES (
    auth.uid(),
    p_trader_id,
    p_copy_amount,
    p_leverage,
    p_is_mock,
    p_stop_loss_percent,
    p_take_profit_percent,
    'active'
  )
  RETURNING id INTO v_relationship_id;

  RETURN jsonb_build_object(
    'success', true,
    'relationship_id', v_relationship_id,
    'message', 'Successfully started ' || CASE WHEN p_is_mock THEN 'mock ' ELSE '' END || 'copy trading'
  );
END;
$$;

-- Update stop_copy_trading function
CREATE OR REPLACE FUNCTION stop_copy_trading(
  p_relationship_id uuid,
  p_close_positions boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
        AND status = 'open'
    LOOP
      -- Calculate final PnL
      v_total_pnl := v_total_pnl + v_position.unrealized_pnl;

      -- Move to history
      INSERT INTO copy_position_history (
        follower_id,
        trader_id,
        relationship_id,
        is_mock,
        pair,
        side,
        entry_price,
        exit_price,
        position_size,
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
        v_position.pair,
        v_position.side,
        v_position.entry_price,
        v_position.current_price,
        v_position.position_size,
        v_position.leverage,
        v_position.margin,
        v_position.unrealized_pnl,
        v_position.fees,
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
    SET balance = balance + v_return_amount
    WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy';
  END IF;

  -- Update relationship status
  UPDATE copy_relationships
  SET 
    status = 'stopped',
    ended_at = now(),
    total_pnl = v_total_pnl
  WHERE id = p_relationship_id;

  RETURN jsonb_build_object(
    'success', true,
    'total_pnl', v_total_pnl,
    'return_amount', v_return_amount,
    'message', 'Successfully stopped copy trading'
  );
END;
$$;

-- Update open_copy_position function
CREATE OR REPLACE FUNCTION open_copy_position(
  p_relationship_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_leverage integer,
  p_is_mock boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_relationship RECORD;
  v_position_id uuid;
  v_margin numeric;
  v_position_size numeric;
  v_liquidation_price numeric;
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

  -- Calculate position size based on copy amount and leverage
  v_margin := v_relationship.copy_amount * 0.1;
  v_position_size := v_margin * p_leverage / p_entry_price;

  -- Calculate liquidation price
  IF p_side = 'long' THEN
    v_liquidation_price := p_entry_price * (1 - (1 / p_leverage::numeric) * 0.9);
  ELSE
    v_liquidation_price := p_entry_price * (1 + (1 / p_leverage::numeric) * 0.9);
  END IF;

  -- Create position
  INSERT INTO copy_positions (
    follower_id,
    trader_id,
    relationship_id,
    is_mock,
    pair,
    side,
    entry_price,
    current_price,
    position_size,
    leverage,
    margin,
    liquidation_price,
    stop_loss,
    take_profit,
    status
  ) VALUES (
    auth.uid(),
    v_relationship.trader_id,
    p_relationship_id,
    p_is_mock,
    p_pair,
    p_side,
    p_entry_price,
    p_entry_price,
    v_position_size,
    p_leverage,
    v_margin,
    v_liquidation_price,
    v_relationship.stop_loss_percent,
    v_relationship.take_profit_percent,
    'open'
  )
  RETURNING id INTO v_position_id;

  RETURN jsonb_build_object(
    'success', true,
    'position_id', v_position_id,
    'message', 'Successfully opened copy position'
  );
END;
$$;

-- Update close_copy_position function
CREATE OR REPLACE FUNCTION close_copy_position(
  p_position_id uuid,
  p_exit_price numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_position RECORD;
  v_return_amount numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM copy_positions
  WHERE id = p_position_id
    AND follower_id = auth.uid()
    AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Position not found'
    );
  END IF;

  -- Calculate return amount (margin + PnL)
  v_return_amount := v_position.margin + v_position.unrealized_pnl;

  -- Move to history
  INSERT INTO copy_position_history (
    follower_id,
    trader_id,
    relationship_id,
    is_mock,
    pair,
    side,
    entry_price,
    exit_price,
    position_size,
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
    v_position.pair,
    v_position.side,
    v_position.entry_price,
    p_exit_price,
    v_position.position_size,
    v_position.leverage,
    v_position.margin,
    v_position.unrealized_pnl,
    v_position.fees,
    v_position.opened_at,
    now()
  );

  -- Return funds to wallet only for real trading
  IF NOT v_position.is_mock AND v_return_amount > 0 THEN
    UPDATE wallets
    SET balance = balance + v_return_amount
    WHERE user_id = v_position.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';
  END IF;

  -- Delete position
  DELETE FROM copy_positions WHERE id = p_position_id;

  RETURN jsonb_build_object(
    'success', true,
    'realized_pnl', v_position.unrealized_pnl,
    'return_amount', v_return_amount,
    'message', 'Successfully closed copy position'
  );
END;
$$;
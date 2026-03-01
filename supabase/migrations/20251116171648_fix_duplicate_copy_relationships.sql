/*
  # Fix Duplicate Copy Relationships

  1. Changes
    - Update start_copy_trading to check for existing relationships
    - If stopped relationship exists, reactivate it
    - If active relationship exists, return error
    - Only create new relationship if none exists
    
  2. Notes
    - Prevents duplicate key violations
    - Allows users to restart copy trading with same trader
*/

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
  v_existing_relationship RECORD;
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

  -- Check for existing relationship
  SELECT * INTO v_existing_relationship
  FROM copy_relationships
  WHERE follower_id = auth.uid()
    AND trader_id = p_trader_id;

  -- If active relationship exists, return error
  IF FOUND AND v_existing_relationship.status = 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You are already copying this trader'
    );
  END IF;

  -- For mock trading, no wallet check needed
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

  -- If stopped relationship exists, reactivate it
  IF FOUND AND v_existing_relationship.status = 'stopped' THEN
    UPDATE copy_relationships
    SET 
      copy_amount = p_copy_amount,
      leverage = p_leverage,
      is_mock = p_is_mock,
      stop_loss_percent = p_stop_loss_percent,
      take_profit_percent = p_take_profit_percent,
      status = 'active',
      ended_at = NULL,
      updated_at = now()
    WHERE id = v_existing_relationship.id
    RETURNING id INTO v_relationship_id;

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'message', 'Successfully restarted ' || CASE WHEN p_is_mock THEN 'mock ' ELSE '' END || 'copy trading'
    );
  END IF;

  -- Create new copy trading relationship
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
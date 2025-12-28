/*
  # Integrate Unlock Tracking with Deposits and Trades

  ## Summary
  Automatically tracks deposits and trades toward locked bonus unlock requirements.

  ## Changes
  1. Update deposit completion to track deposits
  2. Update futures position closing to track trades
  3. Update locked_bonuses status enum to include 'unlocked'

  ## Logic
  - When a deposit is completed, call track_deposit_for_unlock()
  - When a futures position is closed, call track_trade_for_unlock()
  - Automatically unlock bonuses when requirements are met
*/

-- Update locked_bonuses status to include 'unlocked'
ALTER TABLE locked_bonuses
  DROP CONSTRAINT IF EXISTS locked_bonuses_status_check;

ALTER TABLE locked_bonuses
  ADD CONSTRAINT locked_bonuses_status_check
  CHECK (status IN ('active', 'expired', 'depleted', 'unlocked'));

-- Update the deposit completion function to track deposits
CREATE OR REPLACE FUNCTION complete_crypto_deposit(
  p_payment_id text,
  p_actual_amount_received numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deposit record;
  v_wallet_id uuid;
  v_transaction_id uuid;
  v_tracking_result jsonb;
BEGIN
  -- Get deposit details
  SELECT * INTO v_deposit
  FROM crypto_deposits
  WHERE payment_id = p_payment_id
    AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Deposit not found or already processed'
    );
  END IF;

  -- Update deposit status
  UPDATE crypto_deposits
  SET
    status = 'completed',
    actual_amount_received = p_actual_amount_received,
    completed_at = now(),
    updated_at = now()
  WHERE payment_id = p_payment_id;

  -- Get or create wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = v_deposit.user_id
    AND currency = v_deposit.currency
    AND wallet_type = 'main';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (v_deposit.user_id, v_deposit.currency, 'main', 0)
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Credit wallet
  UPDATE wallets
  SET
    balance = balance + p_actual_amount_received,
    updated_at = now()
  WHERE id = v_wallet_id;

  -- Create transaction record
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    description,
    details
  ) VALUES (
    v_deposit.user_id,
    'deposit',
    v_deposit.currency,
    p_actual_amount_received,
    'completed',
    'Crypto Deposit',
    jsonb_build_object(
      'payment_id', p_payment_id,
      'deposit_id', v_deposit.id,
      'expected_amount', v_deposit.amount_requested,
      'actual_amount', p_actual_amount_received
    )
  ) RETURNING id INTO v_transaction_id;

  -- Track deposit for unlock requirements
  v_tracking_result := track_deposit_for_unlock(
    v_deposit.user_id,
    p_actual_amount_received
  );

  -- Send notification
  INSERT INTO notifications (user_id, type, title, message, is_read, metadata)
  VALUES (
    v_deposit.user_id,
    'transaction',
    'Deposit Confirmed',
    'Your deposit of ' || p_actual_amount_received::text || ' ' || v_deposit.currency || ' has been confirmed and credited to your account.',
    false,
    jsonb_build_object(
      'transaction_id', v_transaction_id,
      'amount', p_actual_amount_received,
      'currency', v_deposit.currency,
      'bonuses_unlocked', v_tracking_result->'bonuses_unlocked'
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'deposit_id', v_deposit.id,
    'amount', p_actual_amount_received,
    'currency', v_deposit.currency,
    'bonuses_unlocked', v_tracking_result->'bonuses_unlocked'
  );
END;
$$;

-- Update close_position to track trades for unlock
CREATE OR REPLACE FUNCTION close_position(
  p_user_id uuid,
  p_position_id uuid,
  p_exit_price numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_pnl numeric;
  v_return_amount numeric;
  v_fees numeric;
  v_transaction_id uuid;
  v_locked_bonus_result jsonb;
  v_tracking_result jsonb;
BEGIN
  -- Get position
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND user_id = p_user_id
    AND status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found or already closed';
  END IF;

  -- Calculate PnL
  IF v_position.side = 'long' THEN
    v_pnl := (p_exit_price - v_position.entry_price) * v_position.quantity;
  ELSE
    v_pnl := (v_position.entry_price - p_exit_price) * v_position.quantity;
  END IF;

  -- Calculate fees (0.1% closing fee on margin)
  v_fees := v_position.margin_allocated * 0.001;

  -- Handle locked bonus PnL
  IF v_pnl < 0 THEN
    v_locked_bonus_result := apply_pnl_to_locked_bonus(p_user_id, v_pnl);
  END IF;

  -- Calculate return amount
  v_return_amount := v_position.margin_allocated + v_pnl - v_fees;
  v_return_amount := GREATEST(0, v_return_amount);

  -- Update position
  UPDATE futures_positions
  SET
    status = 'closed',
    realized_pnl = v_pnl,
    cumulative_fees = cumulative_fees + v_fees,
    mark_price = p_exit_price,
    closed_at = now(),
    last_price_update = now()
  WHERE position_id = p_position_id;

  -- Return to wallet if positive
  IF v_return_amount > 0 THEN
    UPDATE futures_margin_wallets
    SET
      available_balance = available_balance + v_return_amount,
      updated_at = now()
    WHERE user_id = p_user_id;
  END IF;

  -- Create transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    description,
    details
  ) VALUES (
    p_user_id,
    'futures_close',
    'USDT',
    v_return_amount,
    'completed',
    'Close Position: ' || v_position.pair,
    jsonb_build_object(
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'entry_price', v_position.entry_price,
      'exit_price', p_exit_price,
      'pnl', v_pnl,
      'fees', v_fees
    )
  ) RETURNING id INTO v_transaction_id;

  -- Distribute commissions
  PERFORM distribute_commissions(
    p_user_id,
    v_transaction_id,
    v_position.margin_allocated * v_position.leverage,
    v_fees
  );

  -- Track trade for unlock requirements
  v_tracking_result := track_trade_for_unlock(p_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'exit_price', p_exit_price,
    'pnl', v_pnl,
    'fees', v_fees,
    'return_amount', v_return_amount,
    'bonuses_unlocked', v_tracking_result->'bonuses_unlocked'
  );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION complete_crypto_deposit(text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION close_position(uuid, uuid, numeric) TO authenticated;

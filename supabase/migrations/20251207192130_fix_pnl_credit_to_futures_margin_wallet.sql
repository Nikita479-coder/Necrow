/*
  # Fix P&L Credit to Futures Margin Wallet

  ## Description
  Updates the close_position_market function to credit P&L to the correct
  futures_margin_wallets table instead of the generic wallets table.

  ## Changes
  - Modified close_position_market function to update futures_margin_wallets
  - Ensures P&L is added to available_balance in futures_margin_wallets
  - Maintains all existing fee calculations and referral distributions

  ## Security
  - Maintains existing RLS policies
  - Uses SECURITY DEFINER with search_path = public
*/

CREATE OR REPLACE FUNCTION close_position_market(
  p_user_id uuid,
  p_position_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_current_price numeric;
  v_pnl numeric;
  v_wallet_balance numeric;
  v_trading_fee numeric;
  v_return_amount numeric;
  v_transaction_id uuid;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND user_id = p_user_id
    AND status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found or already closed';
  END IF;

  -- Get current market price
  SELECT mark_price INTO v_current_price
  FROM market_prices
  WHERE pair = v_position.pair;

  IF v_current_price IS NULL THEN
    RAISE EXCEPTION 'Cannot get current price for %', v_position.pair;
  END IF;

  -- Calculate P&L
  IF v_position.side = 'long' THEN
    v_pnl := (v_current_price - v_position.entry_price) * v_position.quantity;
  ELSE
    v_pnl := (v_position.entry_price - v_current_price) * v_position.quantity;
  END IF;

  -- Calculate closing fee
  v_trading_fee := calculate_trading_fee(
    p_user_id,
    v_current_price * v_position.quantity,
    false
  );

  -- Calculate return amount: margin + PnL - closing fee
  v_return_amount := v_position.margin_allocated + v_pnl - v_trading_fee;

  -- Update position as closed
  UPDATE futures_positions
  SET
    status = 'closed',
    realized_pnl = v_pnl,
    cumulative_fees = cumulative_fees + v_trading_fee,
    mark_price = v_current_price,
    closed_at = NOW(),
    last_price_update = NOW()
  WHERE position_id = p_position_id;

  -- Return funds to FUTURES MARGIN WALLET (not generic wallets table)
  UPDATE futures_margin_wallets
  SET
    available_balance = available_balance + v_return_amount,
    updated_at = NOW()
  WHERE user_id = p_user_id;

  -- Auto-create futures_margin_wallets if it doesn't exist
  IF NOT FOUND THEN
    INSERT INTO futures_margin_wallets (user_id, available_balance)
    VALUES (p_user_id, v_return_amount)
    ON CONFLICT (user_id)
    DO UPDATE SET
      available_balance = futures_margin_wallets.available_balance + v_return_amount,
      updated_at = NOW();
  END IF;

  -- Record trading fee
  PERFORM record_trading_fee(
    p_user_id,
    p_position_id,
    v_position.pair,
    v_current_price * v_position.quantity,
    false
  );

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    p_user_id,
    'close_position',
    v_return_amount,
    'USDT',
    'completed',
    jsonb_build_object(
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'quantity', v_position.quantity,
      'entry_price', v_position.entry_price,
      'exit_price', v_current_price,
      'realized_pnl', v_pnl,
      'trading_fee', v_trading_fee,
      'return_amount', v_return_amount
    )
  ) RETURNING id INTO v_transaction_id;

  -- Distribute referral commissions and rebates
  PERFORM distribute_trading_fees(
    p_user_id,
    v_transaction_id,
    v_current_price * v_position.quantity,
    v_trading_fee
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'exit_price', v_current_price,
    'realized_pnl', v_pnl,
    'trading_fee', v_trading_fee,
    'return_amount', v_return_amount
  );
END;
$$;
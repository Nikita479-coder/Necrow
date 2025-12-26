/*
  # Integrate Locked Bonus with Futures Trading

  ## Summary
  Updates futures trading functions to properly handle locked bonus balances:
  - Allow using locked bonus balance for opening positions
  - Deduct losses from locked bonus first
  - Credit profits to regular wallet (withdrawable)

  ## Changes
  1. Update close_position_market to handle locked bonus PnL
  2. Update get_wallet_balances to include locked bonus

  ## Logic
  - When opening position: Can use locked bonus + regular balance
  - When closing position:
    - LOSS: Deduct from locked bonus first, then regular wallet
    - PROFIT: All profit goes to regular wallet (withdrawable)
*/

-- Update close_position_market to handle locked bonus
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
  v_locked_bonus_balance numeric;
  v_loss_from_locked numeric := 0;
  v_loss_from_regular numeric := 0;
  v_oldest_locked_bonus_id uuid;
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

  -- Handle PnL distribution for locked bonus
  IF v_pnl < 0 THEN
    -- LOSS: Deduct from locked bonus first
    v_locked_bonus_balance := get_user_locked_bonus_balance(p_user_id);
    
    IF v_locked_bonus_balance > 0 THEN
      -- Deduct loss from locked bonus
      v_loss_from_locked := LEAST(v_locked_bonus_balance, ABS(v_pnl));
      
      -- Apply the loss to locked bonuses
      PERFORM apply_pnl_to_locked_bonus(p_user_id, -v_loss_from_locked);
      
      -- Remaining loss comes from regular wallet
      v_loss_from_regular := ABS(v_pnl) - v_loss_from_locked;
    ELSE
      v_loss_from_regular := ABS(v_pnl);
    END IF;
    
    -- Credit back only the margin minus the portion of loss from regular wallet
    -- (locked bonus portion of loss was already deducted from locked_bonuses table)
    v_return_amount := v_position.margin_allocated - v_loss_from_regular - v_trading_fee;
  END IF;

  -- Return funds to FUTURES MARGIN WALLET
  IF v_return_amount > 0 THEN
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
      'return_amount', v_return_amount,
      'loss_from_locked_bonus', v_loss_from_locked,
      'loss_from_regular_wallet', v_loss_from_regular
    )
  ) RETURNING id INTO v_transaction_id;

  -- Distribute referral commissions and rebates
  PERFORM distribute_trading_fees(
    p_user_id,
    v_transaction_id,
    v_current_price * v_position.quantity,
    v_trading_fee
  );

  -- If there was profit, track it in the oldest active locked bonus
  IF v_pnl > 0 THEN
    SELECT id INTO v_oldest_locked_bonus_id
    FROM locked_bonuses
    WHERE user_id = p_user_id 
      AND status = 'active'
      AND expires_at > NOW()
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_oldest_locked_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses
      SET 
        realized_profits = realized_profits + v_pnl,
        updated_at = NOW()
      WHERE id = v_oldest_locked_bonus_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'exit_price', v_current_price,
    'realized_pnl', v_pnl,
    'trading_fee', v_trading_fee,
    'return_amount', v_return_amount,
    'loss_from_locked_bonus', v_loss_from_locked
  );
END;
$$;

-- Update get_wallet_balances function to include locked bonus info
CREATE OR REPLACE FUNCTION get_wallet_balances(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_main_balances jsonb;
  v_futures_balance numeric := 0;
  v_futures_locked numeric := 0;
  v_total_in_positions numeric := 0;
  v_locked_bonus_balance numeric := 0;
BEGIN
  -- Get main wallet balances
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'currency', currency,
        'balance', balance,
        'wallet_type', wallet_type
      )
    ),
    '[]'::jsonb
  ) INTO v_main_balances
  FROM wallets
  WHERE user_id = p_user_id AND wallet_type = 'main';

  -- Get futures wallet balance
  SELECT 
    COALESCE(available_balance, 0),
    COALESCE(locked_balance, 0)
  INTO v_futures_balance, v_futures_locked
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  -- Calculate margin in open positions
  SELECT COALESCE(SUM(margin_allocated), 0) INTO v_total_in_positions
  FROM futures_positions
  WHERE user_id = p_user_id AND status = 'open';

  -- Get locked bonus balance
  v_locked_bonus_balance := get_user_locked_bonus_balance(p_user_id);

  RETURN jsonb_build_object(
    'main_wallets', v_main_balances,
    'futures', jsonb_build_object(
      'available_balance', v_futures_balance,
      'locked_balance', v_futures_locked,
      'margin_in_positions', v_total_in_positions,
      'total_equity', v_futures_balance + v_futures_locked + v_total_in_positions
    ),
    'locked_bonus', jsonb_build_object(
      'balance', v_locked_bonus_balance,
      'note', 'Can be used for trading but cannot be withdrawn'
    ),
    'total_trading_available', v_futures_balance + v_locked_bonus_balance
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION close_position_market(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_wallet_balances(uuid) TO authenticated;

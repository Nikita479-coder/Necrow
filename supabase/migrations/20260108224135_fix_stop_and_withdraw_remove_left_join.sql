/*
  # Fix Stop and Withdraw - Remove LEFT JOIN with FOR UPDATE

  ## Problem
  PostgreSQL doesn't allow FOR UPDATE on the nullable side of an outer join.

  ## Solution
  Fetch trader name separately instead of using LEFT JOIN.
*/

CREATE OR REPLACE FUNCTION stop_and_withdraw_copy_trading(
  p_relationship_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_trader_name text;
  v_initial_balance numeric;
  v_current_balance numeric;
  v_profit numeric;
  v_platform_fee numeric := 0;
  v_withdraw_amount numeric;
  v_copy_wallet_balance numeric;
BEGIN
  -- Get and lock the relationship (without join)
  SELECT *
  INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
    AND follower_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Copy trading relationship not found'
    );
  END IF;

  -- Get trader name separately
  SELECT name INTO v_trader_name
  FROM traders
  WHERE id = v_relationship.trader_id;

  -- Check if already stopped
  IF v_relationship.status = 'stopped' OR v_relationship.is_active = false THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'This copy trading relationship is already stopped'
    );
  END IF;

  -- Handle mock trading (no real funds)
  IF v_relationship.is_mock THEN
    UPDATE copy_relationships
    SET 
      is_active = false,
      status = 'stopped',
      ended_at = now(),
      updated_at = now()
    WHERE id = p_relationship_id;

    RETURN jsonb_build_object(
      'success', true,
      'is_mock', true,
      'message', 'Mock copy trading stopped successfully'
    );
  END IF;

  -- Calculate balances
  v_initial_balance := COALESCE(v_relationship.initial_balance::numeric, 0);
  v_current_balance := v_initial_balance + COALESCE(v_relationship.cumulative_pnl::numeric, 0);
  v_profit := v_current_balance - v_initial_balance;

  -- Calculate platform fee (20% of profit, only if profitable)
  IF v_profit > 0 THEN
    v_platform_fee := v_profit * 0.20;
  END IF;

  v_withdraw_amount := v_current_balance - v_platform_fee;

  -- Ensure positive withdrawal amount
  IF v_withdraw_amount < 0 THEN
    v_withdraw_amount := 0;
  END IF;

  -- Step 1: Mark relationship as stopped FIRST (this releases the allocation)
  UPDATE copy_relationships
  SET 
    is_active = false,
    status = 'stopped',
    current_balance = '0',
    ended_at = now(),
    updated_at = now()
  WHERE id = p_relationship_id;

  -- Step 2: Get copy wallet balance and transfer to main
  IF v_withdraw_amount > 0 THEN
    -- Get current copy wallet balance
    SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
    FROM wallets
    WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy'
    FOR UPDATE;

    -- Ensure we don't withdraw more than available
    IF v_withdraw_amount > COALESCE(v_copy_wallet_balance, 0) THEN
      v_withdraw_amount := COALESCE(v_copy_wallet_balance, 0);
    END IF;

    IF v_withdraw_amount > 0 THEN
      -- Deduct from copy wallet
      UPDATE wallets
      SET balance = balance - v_withdraw_amount,
          updated_at = now()
      WHERE user_id = auth.uid()
        AND currency = 'USDT'
        AND wallet_type = 'copy';

      -- Add to main wallet
      INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
      VALUES (auth.uid(), 'USDT', 'main', v_withdraw_amount, 0, now(), now())
      ON CONFLICT (user_id, currency, wallet_type)
      DO UPDATE SET
        balance = wallets.balance + v_withdraw_amount,
        updated_at = now();

      -- Record transaction
      INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, details, confirmed_at)
      VALUES (
        auth.uid(), 
        'transfer', 
        'USDT', 
        v_withdraw_amount, 
        v_platform_fee,
        'completed',
        jsonb_build_object(
          'type', 'copy_trading_withdrawal',
          'trader_name', v_trader_name,
          'initial_balance', v_initial_balance,
          'final_balance', v_current_balance,
          'profit', v_profit,
          'platform_fee', v_platform_fee
        ),
        now()
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'is_mock', false,
    'initial_balance', v_initial_balance,
    'final_balance', v_current_balance,
    'profit', v_profit,
    'platform_fee', v_platform_fee,
    'withdraw_amount', v_withdraw_amount,
    'message', 'Successfully stopped copy trading and withdrew funds'
  );
END;
$$;
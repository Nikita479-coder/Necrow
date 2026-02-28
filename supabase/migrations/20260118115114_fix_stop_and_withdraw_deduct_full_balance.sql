/*
  # Fix Stop and Withdraw - Deduct Full Balance Including Platform Fee

  ## Problem
  When stopping copy trading, the function was only deducting the withdrawal amount
  from the copy wallet, but NOT the platform fee. This left the platform fee (20% of profit)
  sitting in the user's copy wallet as orphaned funds.

  ## Solution
  Deduct the FULL copy wallet balance (v_withdraw_amount + platform_fee) from the wallet,
  not just the withdrawal amount. The platform fee is recorded in the transaction for
  accounting purposes.

  ## Changes
  - Deduct full balance from copy wallet instead of just withdraw_amount
  - Platform fee is captured in the transaction fee field
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
  v_total_to_deduct numeric;
BEGIN
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

  SELECT name INTO v_trader_name
  FROM traders
  WHERE id = v_relationship.trader_id;

  IF v_relationship.status = 'stopped' OR v_relationship.is_active = false THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'This copy trading relationship is already stopped'
    );
  END IF;

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

  v_initial_balance := COALESCE(v_relationship.initial_balance::numeric, 0);
  v_current_balance := v_initial_balance + COALESCE(v_relationship.cumulative_pnl::numeric, 0);
  v_profit := v_current_balance - v_initial_balance;

  IF v_profit > 0 THEN
    v_platform_fee := v_profit * 0.20;
  END IF;

  v_withdraw_amount := v_current_balance - v_platform_fee;

  IF v_withdraw_amount < 0 THEN
    v_withdraw_amount := 0;
  END IF;

  UPDATE copy_relationships
  SET 
    is_active = false,
    status = 'stopped',
    current_balance = '0',
    ended_at = now(),
    updated_at = now()
  WHERE id = p_relationship_id;

  IF v_withdraw_amount > 0 OR v_platform_fee > 0 THEN
    SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
    FROM wallets
    WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy'
    FOR UPDATE;

    v_total_to_deduct := v_withdraw_amount + v_platform_fee;

    IF v_total_to_deduct > COALESCE(v_copy_wallet_balance, 0) THEN
      v_total_to_deduct := COALESCE(v_copy_wallet_balance, 0);
      IF v_platform_fee > 0 AND v_total_to_deduct > v_platform_fee THEN
        v_withdraw_amount := v_total_to_deduct - v_platform_fee;
      ELSE
        v_withdraw_amount := v_total_to_deduct;
        v_platform_fee := 0;
      END IF;
    END IF;

    IF v_total_to_deduct > 0 THEN
      UPDATE wallets
      SET balance = balance - v_total_to_deduct,
          updated_at = now()
      WHERE user_id = auth.uid()
        AND currency = 'USDT'
        AND wallet_type = 'copy';
    END IF;

    IF v_withdraw_amount > 0 THEN
      INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
      VALUES (auth.uid(), 'USDT', 'main', v_withdraw_amount, 0, now(), now())
      ON CONFLICT (user_id, currency, wallet_type)
      DO UPDATE SET
        balance = wallets.balance + v_withdraw_amount,
        updated_at = now();

      INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, details, confirmed_at)
      VALUES (
        auth.uid(), 
        'transfer', 
        'USDT', 
        v_withdraw_amount, 
        v_platform_fee,
        'completed',
        'Withdraw from ' || COALESCE(v_trader_name, 'trader'),
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

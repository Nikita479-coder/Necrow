/*
  # Fix withdrawal functions to use current_balance field

  1. Problem
    - Both `calculate_copy_trading_early_withdrawal` and `stop_and_withdraw_copy_trading`
      computed balance as `initial_balance + cumulative_pnl`
    - This was inconsistent with the UI which displays the `current_balance` field directly
    - Even with corrected cumulative_pnl, using the stored current_balance is more reliable
      since it is maintained by the close_trader_trade function in real-time

  2. Fix
    - Change both functions to use `COALESCE(v_relationship.current_balance::numeric, 0)`
      instead of `v_initial_balance + cumulative_pnl`
    - This ensures the withdrawal preview and actual withdrawal match what the UI shows

  3. Impact
    - Withdrawal previews will match the "Current Balance" shown on the copy trading card
    - No more phantom "previously withdrawn" amounts caused by inflated PNL calculations
*/

CREATE OR REPLACE FUNCTION calculate_copy_trading_early_withdrawal(
  p_relationship_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_initial_balance numeric;
  v_original_allocation numeric;
  v_current_balance numeric;
  v_raw_balance numeric;
  v_cumulative_pnl numeric;
  v_profit numeric;
  v_platform_fee numeric := 0;
  v_bonus_amount numeric;
  v_bonus_locked_until timestamptz;
  v_bonus_proportion numeric;
  v_forfeited_amount numeric := 0;
  v_withdraw_amount numeric;
  v_is_bonus_locked boolean := false;
  v_open_positions_count integer;
  v_open_positions jsonb;
  v_copy_wallet_balance numeric;
  v_previously_withdrawn numeric := 0;
BEGIN
  SELECT *
  INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
  AND follower_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Relationship not found'
    );
  END IF;

  SELECT
    COUNT(*),
    COALESCE(jsonb_agg(jsonb_build_object(
      'id', cta.id,
      'symbol', COALESCE(tt.symbol, 'Unknown'),
      'side', cta.side,
      'allocated_amount', cta.allocated_amount,
      'entry_price', cta.entry_price
    )), '[]'::jsonb)
  INTO v_open_positions_count, v_open_positions
  FROM copy_trade_allocations cta
  INNER JOIN trader_trades tt ON tt.id = cta.trader_trade_id AND tt.status = 'open'
  WHERE cta.copy_relationship_id = p_relationship_id
  AND cta.status = 'open';

  SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
  FROM wallets
  WHERE user_id = auth.uid()
  AND currency = 'USDT'
  AND wallet_type = 'copy';

  v_initial_balance := COALESCE(v_relationship.initial_balance::numeric, 0);
  v_bonus_amount := COALESCE(v_relationship.bonus_amount, 0);
  v_bonus_locked_until := v_relationship.bonus_locked_until;
  v_cumulative_pnl := COALESCE(v_relationship.cumulative_pnl::numeric, 0);
  v_current_balance := COALESCE(v_relationship.current_balance::numeric, 0);
  v_raw_balance := v_current_balance;
  v_original_allocation := v_initial_balance - v_bonus_amount;

  IF v_copy_wallet_balance < v_current_balance THEN
    v_previously_withdrawn := v_current_balance - v_copy_wallet_balance;
    v_current_balance := v_copy_wallet_balance;
  END IF;

  IF v_bonus_amount > 0 AND v_bonus_locked_until IS NOT NULL AND v_bonus_locked_until > now() THEN
    v_is_bonus_locked := true;
    v_bonus_proportion := v_bonus_amount / v_initial_balance;
    v_forfeited_amount := v_current_balance * v_bonus_proportion;
    v_current_balance := v_current_balance - v_forfeited_amount;
  END IF;

  v_profit := v_current_balance - GREATEST(v_original_allocation - v_previously_withdrawn, 0);

  IF v_profit > 0 THEN
    v_platform_fee := v_profit * 0.20;
  END IF;

  v_withdraw_amount := v_current_balance - v_platform_fee;

  IF v_withdraw_amount < 0 THEN
    v_withdraw_amount := 0;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'initial_balance', v_initial_balance,
    'cumulative_pnl', v_cumulative_pnl,
    'original_allocation', v_original_allocation,
    'bonus_amount', v_bonus_amount,
    'total_balance', v_current_balance,
    'raw_balance', v_raw_balance,
    'is_bonus_locked', v_is_bonus_locked,
    'bonus_locked_until', v_bonus_locked_until,
    'days_remaining', CASE
      WHEN v_bonus_locked_until IS NOT NULL THEN
        GREATEST(0, EXTRACT(DAY FROM v_bonus_locked_until - now())::integer)
      ELSE 0
    END,
    'forfeited_amount', v_forfeited_amount,
    'profit', v_profit,
    'profit_after_forfeiture', v_profit,
    'platform_fee', v_platform_fee,
    'you_will_receive', v_withdraw_amount,
    'previously_withdrawn', v_previously_withdrawn,
    'has_open_positions', v_open_positions_count > 0,
    'open_positions_count', v_open_positions_count,
    'open_positions', v_open_positions
  );
END;
$$;


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
  v_original_allocation numeric;
  v_current_balance numeric;
  v_profit numeric;
  v_platform_fee numeric := 0;
  v_withdraw_amount numeric;
  v_copy_wallet_balance numeric;
  v_total_to_deduct numeric;
  v_bonus_amount numeric;
  v_bonus_locked_until timestamptz;
  v_bonus_proportion numeric;
  v_forfeited_amount numeric := 0;
  v_is_bonus_locked boolean := false;
  v_open_positions_count integer;
  v_open_positions jsonb;
  v_previously_withdrawn numeric := 0;
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

  SELECT
    COUNT(*),
    COALESCE(jsonb_agg(jsonb_build_object(
      'id', cta.id,
      'symbol', COALESCE(tt.symbol, 'Unknown'),
      'side', cta.side,
      'allocated_amount', cta.allocated_amount,
      'entry_price', cta.entry_price
    )), '[]'::jsonb)
  INTO v_open_positions_count, v_open_positions
  FROM copy_trade_allocations cta
  INNER JOIN trader_trades tt ON tt.id = cta.trader_trade_id AND tt.status = 'open'
  WHERE cta.copy_relationship_id = p_relationship_id
  AND cta.status = 'open';

  IF v_open_positions_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot stop copy trading while you have open positions. Please wait for all positions to be closed.',
      'error_code', 'OPEN_POSITIONS_EXIST',
      'open_positions_count', v_open_positions_count,
      'open_positions', v_open_positions
    );
  END IF;

  UPDATE copy_trade_allocations
  SET status = 'closed', updated_at = now()
  WHERE copy_relationship_id = p_relationship_id
  AND status = 'open'
  AND NOT EXISTS (
    SELECT 1 FROM trader_trades tt
    WHERE tt.id = copy_trade_allocations.trader_trade_id
    AND tt.status = 'open'
  );

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

  SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
  FROM wallets
  WHERE user_id = auth.uid()
  AND currency = 'USDT'
  AND wallet_type = 'copy'
  FOR UPDATE;

  v_initial_balance := COALESCE(v_relationship.initial_balance::numeric, 0);
  v_bonus_amount := COALESCE(v_relationship.bonus_amount, 0);
  v_bonus_locked_until := v_relationship.bonus_locked_until;
  v_current_balance := COALESCE(v_relationship.current_balance::numeric, 0);

  v_original_allocation := v_initial_balance - v_bonus_amount;

  IF v_copy_wallet_balance < v_current_balance THEN
    v_previously_withdrawn := v_current_balance - v_copy_wallet_balance;
    v_current_balance := v_copy_wallet_balance;
  END IF;

  IF v_bonus_amount > 0 AND v_bonus_locked_until IS NOT NULL AND v_bonus_locked_until > now() THEN
    v_is_bonus_locked := true;
    v_bonus_proportion := v_bonus_amount / v_initial_balance;
    v_forfeited_amount := v_current_balance * v_bonus_proportion;
    v_current_balance := v_current_balance - v_forfeited_amount;
  END IF;

  v_profit := v_current_balance - GREATEST(v_original_allocation - v_previously_withdrawn, 0);

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

  IF v_is_bonus_locked AND v_forfeited_amount > 0 THEN
    UPDATE copy_trading_bonus_claims
    SET
      forfeited = true,
      forfeited_at = now(),
      forfeited_amount = v_forfeited_amount,
      updated_at = now()
    WHERE relationship_id = p_relationship_id;
  END IF;

  v_total_to_deduct := v_withdraw_amount + v_platform_fee + v_forfeited_amount;

  IF v_total_to_deduct > 0 AND v_total_to_deduct <= COALESCE(v_copy_wallet_balance, 0) THEN
    UPDATE wallets
    SET balance = balance - v_total_to_deduct,
        updated_at = now()
    WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = 'copy';
  ELSIF v_total_to_deduct > COALESCE(v_copy_wallet_balance, 0) THEN
    UPDATE wallets
    SET balance = 0,
        updated_at = now()
    WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = 'copy';

    v_total_to_deduct := COALESCE(v_copy_wallet_balance, 0);
    v_withdraw_amount := GREATEST(0, v_total_to_deduct - v_platform_fee - v_forfeited_amount);
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
      jsonb_build_object(
        'type', 'copy_trading_withdrawal',
        'trader_name', v_trader_name,
        'original_allocation', v_original_allocation,
        'bonus_amount', v_bonus_amount,
        'bonus_forfeited', v_is_bonus_locked,
        'forfeited_amount', v_forfeited_amount,
        'previously_withdrawn', v_previously_withdrawn
      ),
      now()
    );
  END IF;

  IF v_is_bonus_locked AND v_forfeited_amount > 0 THEN
    INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
    VALUES (
      auth.uid(),
      'system',
      'Copy Trading Bonus Forfeited',
      'You withdrew before the 30-day lock period. ' || ROUND(v_forfeited_amount, 2) || ' USDT (bonus portion) was forfeited.',
      false,
      jsonb_build_object(
        'forfeited_amount', v_forfeited_amount,
        'bonus_amount', v_bonus_amount,
        'relationship_id', p_relationship_id
      ),
      now()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'is_mock', false,
    'original_allocation', v_original_allocation,
    'bonus_amount', v_bonus_amount,
    'initial_balance', v_initial_balance,
    'final_balance', v_current_balance + v_forfeited_amount,
    'profit', v_profit,
    'platform_fee', v_platform_fee,
    'bonus_forfeited', v_is_bonus_locked,
    'forfeited_amount', v_forfeited_amount,
    'withdraw_amount', v_withdraw_amount,
    'previously_withdrawn', v_previously_withdrawn,
    'message', CASE
      WHEN v_is_bonus_locked THEN 'Stopped copy trading. Bonus portion forfeited due to early withdrawal.'
      ELSE 'Successfully stopped copy trading and withdrew funds'
    END
  );
END;
$$;

/*
  # Fix stop_and_withdraw_copy_trading notification column name

  The function referenced `notification_type` but the actual column
  in the `notifications` table is `type`. This caused the function
  to fail when a user had a locked bonus and tried to stop and withdraw.

  ## Changes
  - Fixed column name from `notification_type` to `type` in the INSERT INTO notifications statement
*/

CREATE OR REPLACE FUNCTION public.stop_and_withdraw_copy_trading(p_relationship_id uuid)
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

v_initial_balance := COALESCE(v_relationship.initial_balance::numeric, 0);
v_bonus_amount := COALESCE(v_relationship.bonus_amount, 0);
v_bonus_locked_until := v_relationship.bonus_locked_until;
v_current_balance := v_initial_balance + COALESCE(v_relationship.cumulative_pnl::numeric, 0);

v_original_allocation := v_initial_balance - v_bonus_amount;

IF v_bonus_amount > 0 AND v_bonus_locked_until IS NOT NULL AND v_bonus_locked_until > now() THEN
v_is_bonus_locked := true;
v_bonus_proportion := v_bonus_amount / v_initial_balance;
v_forfeited_amount := v_current_balance * v_bonus_proportion;

v_current_balance := v_current_balance - v_forfeited_amount;
END IF;

v_profit := v_current_balance - v_original_allocation;

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

IF v_withdraw_amount > 0 OR v_platform_fee > 0 OR v_forfeited_amount > 0 THEN
SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
FROM wallets
WHERE user_id = auth.uid()
AND currency = 'USDT'
AND wallet_type = 'copy'
FOR UPDATE;

v_total_to_deduct := v_withdraw_amount + v_platform_fee + v_forfeited_amount;

IF v_total_to_deduct > COALESCE(v_copy_wallet_balance, 0) THEN
v_total_to_deduct := COALESCE(v_copy_wallet_balance, 0);

IF v_forfeited_amount > 0 THEN
IF v_total_to_deduct > v_forfeited_amount THEN
v_total_to_deduct := v_total_to_deduct;
v_withdraw_amount := v_total_to_deduct - v_forfeited_amount - v_platform_fee;
IF v_withdraw_amount < 0 THEN
v_withdraw_amount := 0;
v_platform_fee := GREATEST(0, v_total_to_deduct - v_forfeited_amount);
END IF;
ELSE
v_forfeited_amount := v_total_to_deduct;
v_withdraw_amount := 0;
v_platform_fee := 0;
END IF;
ELSIF v_platform_fee > 0 AND v_total_to_deduct > v_platform_fee THEN
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
jsonb_build_object(
'type', 'copy_trading_withdrawal',
'trader_name', v_trader_name,
'original_allocation', v_original_allocation,
'bonus_amount', v_bonus_amount,
'bonus_forfeited', v_is_bonus_locked,
'forfeited_amount', v_forfeited_amount
),
now()
);
END IF;
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
'message', CASE 
WHEN v_is_bonus_locked THEN 'Stopped copy trading. Bonus portion forfeited due to early withdrawal.'
ELSE 'Successfully stopped copy trading and withdrew funds'
END
);
END;
$$;

/*
  # Fix allocated-to-traders calculation in get_wallet_balances

  1. Changes
    - Updated `get_wallet_balances` function to use `current_balance` instead of
      `initial_balance + cumulative_pnl` when computing copy_allocated
    - `current_balance` accurately reflects the amount tied to each active copy
      relationship and matches what users see on their copy trading dashboard
    - The old formula (`initial_balance + cumulative_pnl`) overstated the allocated
      amount because it did not account for funds sitting in open trade allocations

  2. Impact
    - The Transfer Between Wallets modal will now show the correct allocated amount
    - No change to actual balances or fund availability
*/

CREATE OR REPLACE FUNCTION public.get_wallet_balances(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
v_main_balance numeric := 0;
v_main_locked numeric := 0;
v_copy_balance numeric := 0;
v_copy_locked numeric := 0;
v_allocated_to_traders numeric := 0;
v_futures_available numeric := 0;
v_futures_locked numeric := 0;
v_locked_bonus_balance numeric := 0;
v_locked_bonus_profits numeric := 0;
v_margin_in_positions numeric := 0;
v_total_locked_bonus numeric := 0;
v_futures_transferable numeric := 0;
BEGIN
SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
INTO v_main_balance, v_main_locked
FROM wallets
WHERE user_id = p_user_id
AND currency = 'USDT'
AND wallet_type = 'main';

SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
INTO v_copy_balance, v_copy_locked
FROM wallets
WHERE user_id = p_user_id
AND currency = 'USDT'
AND wallet_type = 'copy';

SELECT COALESCE(SUM(
COALESCE(current_balance::numeric, 0)
), 0)
INTO v_allocated_to_traders
FROM copy_relationships
WHERE follower_id = p_user_id
AND is_active = true
AND is_mock = false;

SELECT COALESCE(available_balance, 0), COALESCE(locked_balance, 0)
INTO v_futures_available, v_futures_locked
FROM futures_margin_wallets
WHERE user_id = p_user_id;

SELECT
COALESCE(SUM(current_amount), 0),
COALESCE(SUM(realized_profits), 0)
INTO v_locked_bonus_balance, v_locked_bonus_profits
FROM locked_bonuses
WHERE user_id = p_user_id
AND status = 'active'
AND is_unlocked = false
AND (expires_at IS NULL OR expires_at > now());

v_total_locked_bonus := v_locked_bonus_balance + v_locked_bonus_profits;

v_futures_transferable := v_futures_available;

SELECT COALESCE(SUM(margin_allocated), 0)
INTO v_margin_in_positions
FROM futures_positions
WHERE user_id = p_user_id
AND status = 'open';

RETURN jsonb_build_object(
'main_wallet', v_main_balance,
'main_locked', v_main_locked,
'main_available', GREATEST(v_main_balance - v_main_locked, 0),
'copy_wallet', v_copy_balance,
'copy_locked', v_copy_locked,
'copy_allocated', v_allocated_to_traders,
'copy_available', GREATEST(v_copy_balance - v_copy_locked - v_allocated_to_traders, 0),
'futures_available', v_futures_available,
'futures_locked', v_futures_locked,
'futures_transferable', v_futures_transferable,
'futures_locked_bonus', v_total_locked_bonus,
'futures', jsonb_build_object(
'available_balance', v_futures_available,
'locked_balance', v_futures_locked,
'total_equity', v_futures_available + v_futures_locked,
'margin_in_positions', v_margin_in_positions,
'transferable', v_futures_transferable,
'locked_bonus', v_total_locked_bonus
),
'locked_bonus', jsonb_build_object(
'balance', v_locked_bonus_balance
),
'total_trading_available', v_futures_available + v_locked_bonus_balance
);
END;
$function$;

/*
  # Fix get_wallet_balances return structure

  1. Problem
    - Function returns nested `futures.available_balance`
    - Frontend expects flat `futures_available`
    - This mismatch causes the balance to show as 0

  2. Solution
    - Return both nested and flat structures for compatibility
    - Add `futures_available` and `futures_locked` at top level
*/

CREATE OR REPLACE FUNCTION get_wallet_balances(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_main_balance numeric := 0;
  v_main_locked numeric := 0;
  v_copy_balance numeric := 0;
  v_copy_locked numeric := 0;
  v_allocated_to_traders numeric := 0;
  v_futures_available numeric := 0;
  v_futures_locked numeric := 0;
  v_locked_bonus_balance numeric := 0;
  v_margin_in_positions numeric := 0;
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
    COALESCE(initial_balance::numeric, 0) + COALESCE(cumulative_pnl::numeric, 0)
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

  SELECT COALESCE(SUM(current_amount), 0)
  INTO v_locked_bonus_balance
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status = 'active';

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
    'futures', jsonb_build_object(
      'available_balance', v_futures_available,
      'locked_balance', v_futures_locked,
      'total_equity', v_futures_available + v_futures_locked,
      'margin_in_positions', v_margin_in_positions
    ),
    'locked_bonus', jsonb_build_object(
      'balance', v_locked_bonus_balance
    ),
    'total_trading_available', v_futures_available + v_locked_bonus_balance
  );
END;
$$;

/*
  # Fix get_wallet_balances - Show Accurate Transferable Amount

  ## Changes
  Update the futures_transferable calculation to match the new transfer logic:
  - Use total_deposited - total_withdrawn to estimate real balance
  - Subtract bonus profits (not bonus amounts, since those are separate)
  - Subtract margin locked in open positions
  - This gives users an accurate view of what they can actually transfer
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
  v_futures_total_deposited numeric := 0;
  v_futures_total_withdrawn numeric := 0;
  v_locked_bonus_balance numeric := 0;
  v_locked_bonus_profits numeric := 0;
  v_margin_in_positions numeric := 0;
  v_real_balance_estimate numeric := 0;
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
    COALESCE(initial_balance::numeric, 0) + COALESCE(cumulative_pnl::numeric, 0)
  ), 0)
  INTO v_allocated_to_traders
  FROM copy_relationships
  WHERE follower_id = p_user_id
    AND is_active = true
    AND is_mock = false;

  SELECT
    COALESCE(available_balance, 0),
    COALESCE(locked_balance, 0),
    COALESCE(total_deposited, 0),
    COALESCE(total_withdrawn, 0)
  INTO v_futures_available, v_futures_locked, v_futures_total_deposited, v_futures_total_withdrawn
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  SELECT
    COALESCE(SUM(current_amount), 0),
    COALESCE(SUM(realized_profits), 0)
  INTO v_locked_bonus_balance, v_locked_bonus_profits
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status = 'active'
    AND is_unlocked = false;

  SELECT COALESCE(SUM(margin_allocated), 0)
  INTO v_margin_in_positions
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'open';

  -- Calculate real balance estimate
  v_real_balance_estimate := v_futures_total_deposited - v_futures_total_withdrawn;

  -- Transferable = minimum of (available - margin_in_positions, real_balance - bonus_profits)
  v_futures_transferable := LEAST(
    v_futures_available - v_margin_in_positions,
    GREATEST(v_real_balance_estimate - v_locked_bonus_profits, 0)
  );

  -- Ensure never negative
  v_futures_transferable := GREATEST(v_futures_transferable, 0);

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
    'futures_locked_bonus', v_locked_bonus_balance,
    'futures_bonus_profits', v_locked_bonus_profits,
    'futures', jsonb_build_object(
      'available_balance', v_futures_available,
      'locked_balance', v_futures_locked,
      'total_equity', v_futures_available + v_futures_locked,
      'margin_in_positions', v_margin_in_positions,
      'transferable', v_futures_transferable,
      'locked_bonus', v_locked_bonus_balance,
      'bonus_profits', v_locked_bonus_profits
    ),
    'locked_bonus', jsonb_build_object(
      'balance', v_locked_bonus_balance,
      'profits', v_locked_bonus_profits
    ),
    'total_trading_available', v_futures_available + v_locked_bonus_balance
  );
END;
$$;

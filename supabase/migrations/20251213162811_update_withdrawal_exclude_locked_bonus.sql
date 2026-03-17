/*
  # Update Withdrawal System to Exclude Locked Bonuses

  ## Summary
  Updates the withdrawal checking functions to exclude locked bonus amounts
  from withdrawable balances. Users can only withdraw regular balance + profits,
  not the locked bonus itself.

  ## Changes
  1. Update check_withdrawal_allowed to return locked bonus info
  2. Create get_max_withdrawal_amount function
*/

-- Update check_withdrawal_allowed to include locked bonus info
CREATE OR REPLACE FUNCTION check_withdrawal_allowed(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked boolean;
  v_reason text;
  v_blocked_at timestamptz;
  v_main_balance numeric := 0;
  v_futures_balance numeric := 0;
  v_locked_bonus numeric := 0;
  v_withdrawable numeric := 0;
BEGIN
  -- Check if user is blocked from withdrawals
  SELECT withdrawal_blocked, withdrawal_block_reason, withdrawal_blocked_at
  INTO v_blocked, v_reason, v_blocked_at
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_blocked THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', COALESCE(v_reason, 'Withdrawals are temporarily blocked'),
      'blocked_at', v_blocked_at
    );
  END IF;

  -- Get main wallet balance
  SELECT COALESCE(SUM(balance), 0) INTO v_main_balance
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  -- Get futures wallet available balance
  SELECT COALESCE(available_balance, 0) INTO v_futures_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  -- Get locked bonus balance (NOT withdrawable)
  v_locked_bonus := get_user_locked_bonus_balance(p_user_id);

  -- Calculate total withdrawable (excludes locked bonus)
  v_withdrawable := v_main_balance + v_futures_balance;

  RETURN jsonb_build_object(
    'allowed', true,
    'main_balance', v_main_balance,
    'futures_balance', v_futures_balance,
    'locked_bonus', v_locked_bonus,
    'max_withdrawable', v_withdrawable,
    'locked_bonus_note', 'Locked bonuses cannot be withdrawn but can be used for trading'
  );
END;
$$;

-- Function to get maximum withdrawal amount
CREATE OR REPLACE FUNCTION get_max_withdrawal_amount(p_user_id uuid, p_currency text DEFAULT 'USDT')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_main_balance numeric := 0;
  v_futures_balance numeric := 0;
  v_locked_bonus numeric := 0;
  v_total_withdrawable numeric := 0;
  v_withdrawal_allowed jsonb;
BEGIN
  -- First check if withdrawals are allowed
  v_withdrawal_allowed := check_withdrawal_allowed(p_user_id);
  
  IF NOT (v_withdrawal_allowed->>'allowed')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_withdrawal_allowed->>'reason',
      'max_amount', 0
    );
  END IF;

  IF p_currency = 'USDT' THEN
    -- Get main wallet balance
    SELECT COALESCE(balance, 0) INTO v_main_balance
    FROM wallets
    WHERE user_id = p_user_id 
      AND currency = 'USDT' 
      AND wallet_type = 'main';

    -- Get futures wallet balance
    SELECT COALESCE(available_balance, 0) INTO v_futures_balance
    FROM futures_margin_wallets
    WHERE user_id = p_user_id;

    -- Get locked bonus (NOT withdrawable)
    v_locked_bonus := get_user_locked_bonus_balance(p_user_id);

    v_total_withdrawable := v_main_balance + v_futures_balance;
  ELSE
    -- For other currencies, just get main wallet balance
    SELECT COALESCE(balance, 0) INTO v_total_withdrawable
    FROM wallets
    WHERE user_id = p_user_id 
      AND currency = p_currency 
      AND wallet_type = 'main';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'currency', p_currency,
    'main_balance', v_main_balance,
    'futures_balance', v_futures_balance,
    'locked_bonus', v_locked_bonus,
    'max_amount', v_total_withdrawable,
    'locked_bonus_note', CASE 
      WHEN v_locked_bonus > 0 THEN 'You have $' || v_locked_bonus::text || ' in locked bonus (for trading only)'
      ELSE NULL
    END
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_withdrawal_allowed(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_max_withdrawal_amount(uuid, text) TO authenticated;

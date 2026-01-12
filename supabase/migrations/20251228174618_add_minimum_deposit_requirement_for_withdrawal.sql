/*
  # Add Minimum Deposit Requirement for Withdrawals

  ## Summary
  Updates the check_withdrawal_allowed function to require users to have deposited
  at least $100 USD (in USDT or equivalent) before allowing withdrawals. This is
  the most important requirement check for withdrawal eligibility.

  ## Changes
  1. Add deposit total check to check_withdrawal_allowed function
  2. Return error if user has not deposited at least $100
  3. Calculate total deposits from completed deposit transactions

  ## Security
  - Prevents withdrawal abuse by requiring minimum deposit
  - Uses completed deposits only (status = 'completed')
  - Checks are done before any other withdrawal validations
*/

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
  v_total_deposits numeric := 0;
BEGIN
  -- MOST IMPORTANT: Check minimum deposit requirement ($100 USD)
  -- Calculate total completed deposits (in USDT equivalent)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_deposits
  FROM transactions
  WHERE user_id = p_user_id
    AND transaction_type = 'deposit'
    AND status = 'completed'
    AND currency IN ('USDT', 'USDC'); -- Count stablecoins as USD equivalent

  -- Require at least $100 in deposits before allowing withdrawals
  IF v_total_deposits < 100 THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'You must deposit at least $100 USD before you can withdraw. Current deposits: $' || ROUND(v_total_deposits, 2)::text,
      'deposit_requirement', 100,
      'current_deposits', ROUND(v_total_deposits, 2)
    );
  END IF;

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
    'total_deposits', ROUND(v_total_deposits, 2),
    'locked_bonus_note', 'Locked bonuses cannot be withdrawn but can be used for trading'
  );
END;
$$;
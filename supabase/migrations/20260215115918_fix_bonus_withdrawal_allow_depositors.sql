/*
  # Fix Bonus Withdrawal Block - Allow Users With Real Deposits

  ## Summary
  Updates the withdrawal blocking logic so that users who have made real
  deposits are allowed to withdraw, even if they have active or unlocked
  bonuses. The block only applies to users operating purely on bonus funds
  with no real deposits.

  ## Changes
  1. `check_withdrawal_allowed` - checks for real completed deposits before blocking
  2. `get_user_bonus_withdrawal_status` - includes deposit info in status response
  3. Users with deposits can always withdraw (admin still reviews manually)
  4. Users with NO deposits + active bonus -> blocked until volume met
  5. Users with NO deposits + unlocked bonus -> must contact support
*/

CREATE OR REPLACE FUNCTION get_user_bonus_withdrawal_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_active_bonus_count integer := 0;
  v_active_bonus_total numeric := 0;
  v_unlocked_bonus_count integer := 0;
  v_unlocked_bonus_total numeric := 0;
  v_total_volume_required numeric := 0;
  v_total_volume_completed numeric := 0;
  v_has_any_bonus boolean := false;
  v_withdrawal_blocked boolean := false;
  v_block_reason text := '';
  v_total_real_deposits numeric := 0;
  v_has_real_deposits boolean := false;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_real_deposits
  FROM transactions
  WHERE user_id = p_user_id
    AND transaction_type = 'deposit'
    AND status = 'completed';

  v_has_real_deposits := v_total_real_deposits > 0;

  SELECT
    COUNT(*) FILTER (WHERE status = 'active' AND is_unlocked = false),
    COALESCE(SUM(current_amount) FILTER (WHERE status = 'active' AND is_unlocked = false), 0),
    COUNT(*) FILTER (WHERE is_unlocked = true AND unlocked_at >= now() - interval '90 days'),
    COALESCE(SUM(original_amount) FILTER (WHERE is_unlocked = true AND unlocked_at >= now() - interval '90 days'), 0),
    COALESCE(SUM(bonus_trading_volume_required) FILTER (WHERE status = 'active' AND is_unlocked = false), 0),
    COALESCE(SUM(bonus_trading_volume_completed) FILTER (WHERE status = 'active' AND is_unlocked = false), 0)
  INTO
    v_active_bonus_count,
    v_active_bonus_total,
    v_unlocked_bonus_count,
    v_unlocked_bonus_total,
    v_total_volume_required,
    v_total_volume_completed
  FROM locked_bonuses
  WHERE user_id = p_user_id;

  v_has_any_bonus := (v_active_bonus_count > 0) OR (v_unlocked_bonus_count > 0);

  IF NOT v_has_real_deposits THEN
    IF v_active_bonus_count > 0 THEN
      v_withdrawal_blocked := true;
      v_block_reason := 'You have active trading bonuses that require volume completion before withdrawals are enabled. Complete the required trading volume to unlock your bonus first.';
    ELSIF v_unlocked_bonus_count > 0 THEN
      v_withdrawal_blocked := true;
      v_block_reason := 'Your bonus has been unlocked. To process a withdrawal, please contact our support team for assistance.';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'has_any_bonus', v_has_any_bonus,
    'has_real_deposits', v_has_real_deposits,
    'total_real_deposits', ROUND(v_total_real_deposits, 2),
    'withdrawal_blocked', v_withdrawal_blocked,
    'block_reason', v_block_reason,
    'active_bonus_count', v_active_bonus_count,
    'active_bonus_total', ROUND(v_active_bonus_total, 2),
    'unlocked_bonus_count', v_unlocked_bonus_count,
    'unlocked_bonus_total', ROUND(v_unlocked_bonus_total, 2),
    'volume_required', ROUND(v_total_volume_required, 2),
    'volume_completed', ROUND(v_total_volume_completed, 2),
    'volume_remaining', ROUND(GREATEST(v_total_volume_required - v_total_volume_completed, 0), 2),
    'volume_percentage', CASE
      WHEN v_total_volume_required > 0
      THEN ROUND((v_total_volume_completed / v_total_volume_required * 100)::numeric, 1)
      ELSE 0
    END
  );
END;
$$;

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
  v_active_bonus_count integer := 0;
  v_active_bonus_total numeric := 0;
  v_unlocked_bonus_count integer := 0;
  v_volume_required numeric := 0;
  v_volume_completed numeric := 0;
  v_suspended boolean := false;
  v_total_real_deposits numeric := 0;
BEGIN
  SELECT COALESCE(is_suspended, false) INTO v_suspended
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_suspended THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'Your account is suspended. Please contact support.'
    );
  END IF;

  SELECT withdrawal_blocked, withdrawal_block_reason, withdrawal_blocked_at
  INTO v_blocked, v_reason, v_blocked_at
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_blocked THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', COALESCE(v_reason, 'Withdrawals are temporarily blocked. Please contact support.')
    );
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_real_deposits
  FROM transactions
  WHERE user_id = p_user_id
    AND transaction_type = 'deposit'
    AND status = 'completed';

  IF v_total_real_deposits > 0 THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'requires_manual_review', false
    );
  END IF;

  SELECT
    COUNT(*),
    COALESCE(SUM(current_amount), 0),
    COALESCE(SUM(bonus_trading_volume_required), 0),
    COALESCE(SUM(bonus_trading_volume_completed), 0)
  INTO v_active_bonus_count, v_active_bonus_total, v_volume_required, v_volume_completed
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status = 'active'
    AND is_unlocked = false;

  IF v_active_bonus_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'Withdrawals are not available while you have active trading bonuses. Complete the required trading volume ($' || ROUND(GREATEST(v_volume_required - v_volume_completed, 0), 2) || ' remaining) to unlock your bonus first.',
      'bonus_block', true,
      'active_bonuses', v_active_bonus_count,
      'volume_required', v_volume_required,
      'volume_completed', v_volume_completed,
      'volume_remaining', GREATEST(v_volume_required - v_volume_completed, 0)
    );
  END IF;

  SELECT COUNT(*)
  INTO v_unlocked_bonus_count
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND is_unlocked = true
    AND unlocked_at >= now() - interval '90 days';

  IF v_unlocked_bonus_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'Your trading bonus has been unlocked. To withdraw funds, please contact our support team who will assist you with the process.',
      'bonus_block', true,
      'contact_support', true,
      'unlocked_bonuses', v_unlocked_bonus_count
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed', true,
    'requires_manual_review', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_bonus_withdrawal_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION check_withdrawal_allowed(uuid) TO authenticated;

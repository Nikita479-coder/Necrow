/*
  # Block Withdrawals for Users with Active or Unlocked Bonuses

  ## Summary
  Prevents bonus abuse by blocking withdrawals for users who have any
  locked bonuses (active or recently unlocked). Users with active bonuses
  must complete volume requirements first. Users with unlocked bonuses
  must contact support to process withdrawals.

  ## Changes
  1. Updated `check_withdrawal_allowed` function:
     - Blocks withdrawal if user has ANY active (not yet unlocked) locked bonuses
     - Blocks withdrawal if user has unlocked bonuses within last 90 days
     - Returns clear messages directing users to contact support
  2. New helper function `get_user_bonus_withdrawal_status` for frontend checks

  ## Security
  - Prevents bonus fund extraction via withdrawals
  - Forces admin review for all bonus-related withdrawals
  - Users with no bonuses are unaffected
*/

-- Helper function for frontend to check bonus withdrawal status
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
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

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

  IF v_active_bonus_count > 0 THEN
    v_withdrawal_blocked := true;
    v_block_reason := 'You have active trading bonuses that require volume completion before withdrawals are enabled. Complete the required trading volume to unlock your bonus first.';
  ELSIF v_unlocked_bonus_count > 0 THEN
    v_withdrawal_blocked := true;
    v_block_reason := 'Your bonus has been unlocked. To process a withdrawal, please contact our support team for assistance.';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'has_any_bonus', v_has_any_bonus,
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

-- Update check_withdrawal_allowed to hard-block bonus users
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
BEGIN
  -- Check if account is suspended
  SELECT COALESCE(is_suspended, false) INTO v_suspended
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_suspended THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'Your account is suspended. Please contact support.'
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
      'reason', COALESCE(v_reason, 'Withdrawals are temporarily blocked. Please contact support.')
    );
  END IF;

  -- Check for active locked bonuses (not yet unlocked)
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

  -- Check for recently unlocked bonuses - require support contact
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

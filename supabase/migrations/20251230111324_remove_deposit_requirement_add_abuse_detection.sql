/*
  # Remove $100 Deposit Requirement and Add Bonus Abuse Detection

  ## Summary
  Removes the minimum $100 deposit requirement for withdrawals and replaces it
  with sophisticated bonus abuse detection. Users can now withdraw without a 
  minimum deposit, but suspicious bonus-related patterns will flag for review.

  ## Changes
  1. Remove minimum deposit requirement from check_withdrawal_allowed
  2. Add bonus abuse detection logic
  3. Flag withdrawals for manual review if suspicious patterns detected
  4. Keep existing withdrawal block functionality

  ## Abuse Detection Criteria
  - High ratio of bonus funds to real deposits
  - Large unlocked bonus with minimal real deposits
  - Suspicious trading patterns (all under 61 minutes, 100% win rate, etc.)
  - Will set withdrawal_review_required flag on locked_bonuses

  ## Security
  - Does not block legitimate users
  - Flags suspicious activity for admin review
  - Maintains existing withdrawal block system
*/

-- Create function to detect bonus abuse patterns
CREATE OR REPLACE FUNCTION detect_bonus_abuse_for_withdrawal(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_deposits numeric := 0;
  v_total_unlocked_bonus numeric := 0;
  v_locked_bonus_count integer := 0;
  v_suspicious_patterns jsonb := '[]'::jsonb;
  v_requires_review boolean := false;
  v_bonus_to_deposit_ratio numeric;
  v_recent_trades record;
BEGIN
  -- Calculate total deposits
  SELECT COALESCE(SUM(amount), 0) INTO v_total_deposits
  FROM transactions
  WHERE user_id = p_user_id
    AND transaction_type = 'deposit'
    AND status = 'completed';

  -- Calculate total unlocked bonuses (in last 30 days)
  SELECT 
    COALESCE(SUM(current_amount), 0),
    COUNT(*)
  INTO v_total_unlocked_bonus, v_locked_bonus_count
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status = 'unlocked'
    AND unlocked_at >= now() - interval '30 days';

  -- Check 1: High bonus-to-deposit ratio (more than 5:1)
  IF v_total_deposits > 0 THEN
    v_bonus_to_deposit_ratio := v_total_unlocked_bonus / v_total_deposits;
    
    IF v_bonus_to_deposit_ratio > 5 THEN
      v_requires_review := true;
      v_suspicious_patterns := v_suspicious_patterns || jsonb_build_object(
        'type', 'high_bonus_ratio',
        'ratio', ROUND(v_bonus_to_deposit_ratio, 2),
        'deposits', v_total_deposits,
        'unlocked_bonus', v_total_unlocked_bonus,
        'severity', 'high'
      );
    END IF;
  ELSIF v_total_unlocked_bonus > 100 THEN
    -- No deposits but large unlocked bonus
    v_requires_review := true;
    v_suspicious_patterns := v_suspicious_patterns || jsonb_build_object(
      'type', 'bonus_without_deposit',
      'unlocked_bonus', v_total_unlocked_bonus,
      'severity', 'critical'
    );
  END IF;

  -- Check 2: Analyze recent trading patterns (last 50 bonus-funded trades)
  SELECT
    COUNT(*) as trade_count,
    COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (closed_at - opened_at)) < 3660) as short_duration_trades,
    COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (closed_at - opened_at)) BETWEEN 3600 AND 3720) as exactly_60min_trades,
    COUNT(*) FILTER (WHERE realized_pnl > 0) as winning_trades,
    AVG(EXTRACT(EPOCH FROM (closed_at - opened_at)) / 60) as avg_duration_minutes
  INTO v_recent_trades
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'closed'
    AND margin_from_locked_bonus > 0
    AND closed_at >= now() - interval '30 days'
  LIMIT 50;

  IF v_recent_trades.trade_count >= 10 THEN
    -- Check for suspicious patterns:
    -- 1. Most trades exactly at 60-61 minutes (timing the requirement)
    IF v_recent_trades.exactly_60min_trades::numeric / v_recent_trades.trade_count > 0.6 THEN
      v_requires_review := true;
      v_suspicious_patterns := v_suspicious_patterns || jsonb_build_object(
        'type', 'timing_manipulation',
        'exactly_60min_pct', ROUND((v_recent_trades.exactly_60min_trades::numeric / v_recent_trades.trade_count * 100)::numeric, 1),
        'severity', 'medium'
      );
    END IF;

    -- 2. Unrealistically high win rate (>90%)
    IF v_recent_trades.winning_trades::numeric / v_recent_trades.trade_count > 0.9 THEN
      v_requires_review := true;
      v_suspicious_patterns := v_suspicious_patterns || jsonb_build_object(
        'type', 'unrealistic_win_rate',
        'win_rate', ROUND((v_recent_trades.winning_trades::numeric / v_recent_trades.trade_count * 100)::numeric, 1),
        'severity', 'high'
      );
    END IF;

    -- 3. All trades under 61 minutes but user unlocked bonus (shouldn't be possible)
    IF v_recent_trades.short_duration_trades = v_recent_trades.trade_count AND v_total_unlocked_bonus > 0 THEN
      v_requires_review := true;
      v_suspicious_patterns := v_suspicious_patterns || jsonb_build_object(
        'type', 'volume_manipulation',
        'description', 'Bonus unlocked despite all short trades',
        'severity', 'critical'
      );
    END IF;
  END IF;

  -- Mark bonuses for review if suspicious
  IF v_requires_review THEN
    UPDATE locked_bonuses
    SET 
      withdrawal_review_required = true,
      abuse_flags = v_suspicious_patterns,
      updated_at = now()
    WHERE user_id = p_user_id
      AND status IN ('active', 'unlocked')
      AND withdrawal_review_required = false;
  END IF;

  RETURN jsonb_build_object(
    'requires_review', v_requires_review,
    'suspicious_patterns', v_suspicious_patterns,
    'total_deposits', v_total_deposits,
    'total_unlocked_bonus', v_total_unlocked_bonus,
    'bonus_count', v_locked_bonus_count
  );
END;
$$;

-- Update check_withdrawal_allowed to remove deposit requirement and add abuse detection
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
  v_abuse_check jsonb;
  v_requires_review boolean := false;
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

  -- Run bonus abuse detection
  v_abuse_check := detect_bonus_abuse_for_withdrawal(p_user_id);
  v_requires_review := (v_abuse_check->>'requires_review')::boolean;

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

  -- If abuse detected, flag for review but still allow withdrawal
  -- (Admin will review before processing)
  IF v_requires_review THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'requires_manual_review', true,
      'review_reason', 'Potential bonus abuse detected - withdrawal flagged for admin review',
      'abuse_details', v_abuse_check->'suspicious_patterns',
      'main_balance', v_main_balance,
      'futures_balance', v_futures_balance,
      'locked_bonus', v_locked_bonus,
      'max_withdrawable', v_withdrawable,
      'warning', 'Your withdrawal request will be reviewed by our team before processing'
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed', true,
    'requires_manual_review', false,
    'main_balance', v_main_balance,
    'futures_balance', v_futures_balance,
    'locked_bonus', v_locked_bonus,
    'max_withdrawable', v_withdrawable,
    'locked_bonus_note', 'Locked bonuses cannot be withdrawn but can be used for trading'
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION detect_bonus_abuse_for_withdrawal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION check_withdrawal_allowed(uuid) TO authenticated;

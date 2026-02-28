/*
  # Risk Calculation and Monitoring Functions

  ## Description
  Comprehensive risk scoring system that automatically calculates user risk
  based on multiple factors including trading behavior, KYC status, account age,
  transaction patterns, and more.

  ## Risk Score Components (0-100, higher = riskier)

  ### 1. KYC Score (0-30 points)
  - Not verified: 30 points
  - Pending: 15 points
  - Verified: 0 points

  ### 2. Trading Score (0-30 points)
  - High leverage usage: +10 points
  - Frequent liquidations: +10 points
  - Large position sizes: +5 points
  - Suspicious trading patterns: +5 points

  ### 3. Behavior Score (0-25 points)
  - Multiple failed login attempts: +10 points
  - Suspicious IP changes: +5 points
  - Multiple devices: +5 points
  - High velocity transactions: +5 points

  ### 4. Account Age Score (0-15 points)
  - Less than 7 days: 15 points
  - Less than 30 days: 10 points
  - Less than 90 days: 5 points
  - Older: 0 points

  ## Risk Levels
  - Low: 0-30 points
  - Medium: 31-50 points
  - High: 51-70 points
  - Critical: 71-100 points
*/

-- Function to calculate KYC risk score
CREATE OR REPLACE FUNCTION calculate_kyc_risk_score(p_user_id uuid)
RETURNS numeric AS $$
DECLARE
  v_kyc_status text;
  v_score numeric := 0;
BEGIN
  SELECT kyc_status INTO v_kyc_status
  FROM user_profiles
  WHERE id = p_user_id;

  v_score := CASE
    WHEN v_kyc_status = 'verified' THEN 0
    WHEN v_kyc_status = 'pending' THEN 15
    ELSE 30
  END;

  RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to calculate trading risk score
CREATE OR REPLACE FUNCTION calculate_trading_risk_score(p_user_id uuid)
RETURNS numeric AS $$
DECLARE
  v_score numeric := 0;
  v_high_leverage_count integer;
  v_liquidation_count integer;
  v_avg_position_size numeric;
  v_total_positions integer;
  v_pnl_volatility numeric;
BEGIN
  -- Check high leverage usage (>50x)
  SELECT COUNT(*) INTO v_high_leverage_count
  FROM futures_positions
  WHERE user_id = p_user_id
    AND leverage > 50
    AND opened_at > NOW() - INTERVAL '30 days';

  IF v_high_leverage_count > 5 THEN
    v_score := v_score + 10;
  ELSIF v_high_leverage_count > 2 THEN
    v_score := v_score + 5;
  END IF;

  -- Check liquidation history
  SELECT COUNT(*) INTO v_liquidation_count
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'liquidated'
    AND opened_at > NOW() - INTERVAL '30 days';

  IF v_liquidation_count > 3 THEN
    v_score := v_score + 10;
  ELSIF v_liquidation_count > 1 THEN
    v_score := v_score + 5;
  END IF;

  -- Check position sizes relative to account balance
  SELECT 
    COUNT(*),
    AVG(margin_amount)
  INTO v_total_positions, v_avg_position_size
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status IN ('open', 'closed')
    AND opened_at > NOW() - INTERVAL '30 days';

  IF v_total_positions > 0 THEN
    -- Get user's average wallet balance
    DECLARE
      v_avg_balance numeric;
    BEGIN
      SELECT AVG(balance) INTO v_avg_balance
      FROM wallets
      WHERE user_id = p_user_id;

      -- If average position size is > 50% of balance, add risk
      IF v_avg_balance > 0 AND v_avg_position_size > (v_avg_balance * 0.5) THEN
        v_score := v_score + 5;
      END IF;
    END;
  END IF;

  -- Check PnL volatility (wild swings indicate risky trading)
  SELECT STDDEV(pnl) INTO v_pnl_volatility
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'closed'
    AND opened_at > NOW() - INTERVAL '30 days'
    AND pnl IS NOT NULL;

  IF v_pnl_volatility > 1000 THEN
    v_score := v_score + 5;
  END IF;

  -- Cap at 30
  RETURN LEAST(v_score, 30);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to calculate behavior risk score
CREATE OR REPLACE FUNCTION calculate_behavior_risk_score(p_user_id uuid)
RETURNS numeric AS $$
DECLARE
  v_score numeric := 0;
  v_failed_logins integer;
  v_device_count integer;
  v_ip_changes integer;
  v_transaction_velocity integer;
BEGIN
  -- Check failed login attempts
  SELECT COUNT(*) INTO v_failed_logins
  FROM security_logs
  WHERE user_id = p_user_id
    AND event_type = 'login_failed'
    AND created_at > NOW() - INTERVAL '7 days';

  IF v_failed_logins > 10 THEN
    v_score := v_score + 10;
  ELSIF v_failed_logins > 5 THEN
    v_score := v_score + 5;
  END IF;

  -- Check device fingerprints
  SELECT COUNT(DISTINCT device_id) INTO v_device_count
  FROM user_device_fingerprints
  WHERE user_id = p_user_id
    AND last_seen_at > NOW() - INTERVAL '30 days';

  IF v_device_count > 5 THEN
    v_score := v_score + 5;
  ELSIF v_device_count > 3 THEN
    v_score := v_score + 3;
  END IF;

  -- Check IP address changes
  SELECT COUNT(DISTINCT ip_address) INTO v_ip_changes
  FROM user_device_fingerprints
  WHERE user_id = p_user_id
    AND last_seen_at > NOW() - INTERVAL '7 days';

  IF v_ip_changes > 10 THEN
    v_score := v_score + 5;
  ELSIF v_ip_changes > 5 THEN
    v_score := v_score + 3;
  END IF;

  -- Check transaction velocity (many transactions in short time)
  SELECT COUNT(*) INTO v_transaction_velocity
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_transaction_velocity > 50 THEN
    v_score := v_score + 5;
  ELSIF v_transaction_velocity > 20 THEN
    v_score := v_score + 3;
  END IF;

  -- Cap at 25
  RETURN LEAST(v_score, 25);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to calculate account age risk score
CREATE OR REPLACE FUNCTION calculate_account_age_risk_score(p_user_id uuid)
RETURNS numeric AS $$
DECLARE
  v_score numeric := 0;
  v_account_age_days integer;
BEGIN
  SELECT EXTRACT(DAY FROM (NOW() - created_at))::integer
  INTO v_account_age_days
  FROM user_profiles
  WHERE id = p_user_id;

  v_score := CASE
    WHEN v_account_age_days < 7 THEN 15
    WHEN v_account_age_days < 30 THEN 10
    WHEN v_account_age_days < 90 THEN 5
    ELSE 0
  END;

  RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Main function to calculate and update complete risk score
CREATE OR REPLACE FUNCTION update_user_risk_score(p_user_id uuid)
RETURNS void AS $$
DECLARE
  v_kyc_score numeric;
  v_trading_score numeric;
  v_behavior_score numeric;
  v_account_age_score numeric;
  v_overall_score numeric;
  v_risk_level text;
  v_factors jsonb;
BEGIN
  -- Calculate individual scores
  v_kyc_score := calculate_kyc_risk_score(p_user_id);
  v_trading_score := calculate_trading_risk_score(p_user_id);
  v_behavior_score := calculate_behavior_risk_score(p_user_id);
  v_account_age_score := calculate_account_age_risk_score(p_user_id);

  -- Calculate overall score
  v_overall_score := v_kyc_score + v_trading_score + v_behavior_score + v_account_age_score;

  -- Determine risk level
  v_risk_level := CASE
    WHEN v_overall_score >= 71 THEN 'critical'
    WHEN v_overall_score >= 51 THEN 'high'
    WHEN v_overall_score >= 31 THEN 'medium'
    ELSE 'low'
  END;

  -- Build factors JSON
  v_factors := jsonb_build_object(
    'kyc_score', v_kyc_score,
    'trading_score', v_trading_score,
    'behavior_score', v_behavior_score,
    'account_age_score', v_account_age_score,
    'calculation_details', jsonb_build_object(
      'kyc_status', (SELECT kyc_status FROM user_profiles WHERE id = p_user_id),
      'account_age_days', (SELECT EXTRACT(DAY FROM (NOW() - created_at))::integer FROM user_profiles WHERE id = p_user_id),
      'recent_liquidations', (SELECT COUNT(*) FROM futures_positions WHERE user_id = p_user_id AND status = 'liquidated' AND opened_at > NOW() - INTERVAL '30 days'),
      'high_leverage_positions', (SELECT COUNT(*) FROM futures_positions WHERE user_id = p_user_id AND leverage > 50 AND opened_at > NOW() - INTERVAL '30 days'),
      'failed_logins_7d', (SELECT COUNT(*) FROM security_logs WHERE user_id = p_user_id AND event_type = 'login_failed' AND created_at > NOW() - INTERVAL '7 days'),
      'device_count_30d', (SELECT COUNT(DISTINCT device_id) FROM user_device_fingerprints WHERE user_id = p_user_id AND last_seen_at > NOW() - INTERVAL '30 days')
    )
  );

  -- Update or insert risk score
  INSERT INTO risk_scores (
    user_id,
    overall_score,
    trading_score,
    kyc_score,
    behavior_score,
    risk_level,
    factors,
    last_calculated_at,
    updated_at
  ) VALUES (
    p_user_id,
    v_overall_score,
    v_trading_score,
    v_kyc_score,
    v_behavior_score,
    v_risk_level,
    v_factors,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    overall_score = EXCLUDED.overall_score,
    trading_score = EXCLUDED.trading_score,
    kyc_score = EXCLUDED.kyc_score,
    behavior_score = EXCLUDED.behavior_score,
    risk_level = EXCLUDED.risk_level,
    factors = EXCLUDED.factors,
    last_calculated_at = NOW(),
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to check and generate risk alerts
CREATE OR REPLACE FUNCTION check_and_generate_risk_alerts(p_user_id uuid)
RETURNS void AS $$
DECLARE
  v_risk_score record;
  v_alert_exists boolean;
BEGIN
  -- Get current risk score
  SELECT * INTO v_risk_score
  FROM risk_scores
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Alert for critical risk level
  IF v_risk_score.risk_level = 'critical' THEN
    SELECT EXISTS(
      SELECT 1 FROM risk_alerts
      WHERE user_id = p_user_id
        AND alert_type = 'critical_risk_level'
        AND status = 'active'
    ) INTO v_alert_exists;

    IF NOT v_alert_exists THEN
      INSERT INTO risk_alerts (
        user_id,
        alert_type,
        severity,
        description,
        is_auto_generated,
        metadata
      ) VALUES (
        p_user_id,
        'critical_risk_level',
        'critical',
        'User has reached critical risk level (' || v_risk_score.overall_score || ' points)',
        true,
        jsonb_build_object('score', v_risk_score.overall_score, 'factors', v_risk_score.factors)
      );
    END IF;
  END IF;

  -- Alert for high leverage
  IF (v_risk_score.factors->'calculation_details'->>'high_leverage_positions')::integer > 5 THEN
    SELECT EXISTS(
      SELECT 1 FROM risk_alerts
      WHERE user_id = p_user_id
        AND alert_type = 'high_leverage_usage'
        AND status = 'active'
        AND triggered_at > NOW() - INTERVAL '7 days'
    ) INTO v_alert_exists;

    IF NOT v_alert_exists THEN
      INSERT INTO risk_alerts (
        user_id,
        alert_type,
        severity,
        description,
        is_auto_generated
      ) VALUES (
        p_user_id,
        'high_leverage_usage',
        'high',
        'User is frequently using high leverage (>50x)',
        true
      );
    END IF;
  END IF;

  -- Alert for frequent liquidations
  IF (v_risk_score.factors->'calculation_details'->>'recent_liquidations')::integer > 3 THEN
    SELECT EXISTS(
      SELECT 1 FROM risk_alerts
      WHERE user_id = p_user_id
        AND alert_type = 'frequent_liquidations'
        AND status = 'active'
        AND triggered_at > NOW() - INTERVAL '7 days'
    ) INTO v_alert_exists;

    IF NOT v_alert_exists THEN
      INSERT INTO risk_alerts (
        user_id,
        alert_type,
        severity,
        description,
        is_auto_generated
      ) VALUES (
        p_user_id,
        'frequent_liquidations',
        'high',
        'User has been liquidated multiple times recently',
        true
      );
    END IF;
  END IF;

  -- Alert for failed login attempts
  IF (v_risk_score.factors->'calculation_details'->>'failed_logins_7d')::integer > 10 THEN
    SELECT EXISTS(
      SELECT 1 FROM risk_alerts
      WHERE user_id = p_user_id
        AND alert_type = 'suspicious_login_attempts'
        AND status = 'active'
        AND triggered_at > NOW() - INTERVAL '7 days'
    ) INTO v_alert_exists;

    IF NOT v_alert_exists THEN
      INSERT INTO risk_alerts (
        user_id,
        alert_type,
        severity,
        description,
        is_auto_generated
      ) VALUES (
        p_user_id,
        'suspicious_login_attempts',
        'medium',
        'Multiple failed login attempts detected',
        true
      );
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to recalculate all user risk scores (for batch processing)
CREATE OR REPLACE FUNCTION recalculate_all_risk_scores()
RETURNS integer AS $$
DECLARE
  v_user_id uuid;
  v_count integer := 0;
BEGIN
  FOR v_user_id IN
    SELECT id FROM user_profiles
  LOOP
    PERFORM update_user_risk_score(v_user_id);
    PERFORM check_and_generate_risk_alerts(v_user_id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;
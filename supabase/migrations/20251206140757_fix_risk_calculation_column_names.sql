/*
  # Fix Risk Calculation Functions - Column Names

  ## Description
  Updates the risk calculation functions to use correct column names from futures_positions table
*/

-- Drop the old function
DROP FUNCTION IF EXISTS calculate_trading_risk_score(uuid);

-- Recreate with correct column names
CREATE OR REPLACE FUNCTION calculate_trading_risk_score(p_user_id uuid)
RETURNS numeric AS $$
DECLARE
  v_score numeric := 0;
  v_high_leverage_count integer;
  v_liquidation_count integer;
  v_avg_margin_allocated numeric;
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
    AVG(margin_allocated)
  INTO v_total_positions, v_avg_margin_allocated
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

      -- If average margin allocated is > 50% of balance, add risk
      IF v_avg_balance > 0 AND v_avg_margin_allocated > (v_avg_balance * 0.5) THEN
        v_score := v_score + 5;
      END IF;
    END;
  END IF;

  -- Check PnL volatility (wild swings indicate risky trading)
  -- Use realized_pnl for closed positions
  SELECT STDDEV(realized_pnl) INTO v_pnl_volatility
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'closed'
    AND opened_at > NOW() - INTERVAL '30 days'
    AND realized_pnl IS NOT NULL;

  IF v_pnl_volatility > 1000 THEN
    v_score := v_score + 5;
  END IF;

  -- Cap at 30
  RETURN LEAST(v_score, 30);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Drop and recreate trigger function with correct column names
DROP FUNCTION IF EXISTS trigger_risk_update_on_position_change();

CREATE OR REPLACE FUNCTION trigger_risk_update_on_position_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Update risk score asynchronously
  PERFORM update_user_risk_score(COALESCE(NEW.user_id, OLD.user_id));
  PERFORM check_and_generate_risk_alerts(COALESCE(NEW.user_id, OLD.user_id));

  -- Log large positions
  IF TG_OP = 'INSERT' AND NEW.margin_allocated > 10000 THEN
    INSERT INTO position_monitoring_logs (
      user_id,
      position_id,
      event_type,
      details
    ) VALUES (
      NEW.user_id,
      NEW.position_id,
      'large_position_opened',
      jsonb_build_object(
        'margin', NEW.margin_allocated,
        'leverage', NEW.leverage,
        'pair', NEW.pair
      )
    );
  END IF;

  -- Log liquidations
  IF TG_OP = 'UPDATE' AND OLD.status != 'liquidated' AND NEW.status = 'liquidated' THEN
    INSERT INTO position_monitoring_logs (
      user_id,
      position_id,
      event_type,
      details,
      notified_admin
    ) VALUES (
      NEW.user_id,
      NEW.position_id,
      'liquidation_risk',
      jsonb_build_object(
        'margin_lost', NEW.margin_allocated,
        'leverage', NEW.leverage,
        'pair', NEW.pair
      ),
      true
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Recreate trigger
DROP TRIGGER IF EXISTS update_risk_on_position_change ON futures_positions;
CREATE TRIGGER update_risk_on_position_change
  AFTER INSERT OR UPDATE ON futures_positions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_risk_update_on_position_change();

-- Trigger function for KYC status changes
CREATE OR REPLACE FUNCTION trigger_risk_update_on_kyc_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.kyc_status IS DISTINCT FROM NEW.kyc_status THEN
    PERFORM update_user_risk_score(NEW.id);
    PERFORM check_and_generate_risk_alerts(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Create trigger on user_profiles
DROP TRIGGER IF EXISTS update_risk_on_kyc_change ON user_profiles;
CREATE TRIGGER update_risk_on_kyc_change
  AFTER UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION trigger_risk_update_on_kyc_change();

-- Trigger function for security events
CREATE OR REPLACE FUNCTION trigger_risk_update_on_security_event()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update on failed logins or suspicious events
  IF NEW.event_type IN ('login_failed', 'suspicious_ip', 'brute_force_detected') AND NEW.user_id IS NOT NULL THEN
    PERFORM update_user_risk_score(NEW.user_id);
    PERFORM check_and_generate_risk_alerts(NEW.user_id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Create trigger on security_logs
DROP TRIGGER IF EXISTS update_risk_on_security_event ON security_logs;
CREATE TRIGGER update_risk_on_security_event
  AFTER INSERT ON security_logs
  FOR EACH ROW
  EXECUTE FUNCTION trigger_risk_update_on_security_event();

-- Trigger function for large withdrawals
CREATE OR REPLACE FUNCTION trigger_risk_check_on_withdrawal()
RETURNS TRIGGER AS $$
DECLARE
  v_risk_level text;
  v_total_balance numeric;
BEGIN
  -- Only check on withdrawal transactions
  IF NEW.transaction_type = 'withdrawal' THEN
    -- Get user's risk level
    SELECT risk_level INTO v_risk_level
    FROM risk_scores
    WHERE user_id = NEW.user_id;

    -- Get user's total balance
    SELECT SUM(balance) INTO v_total_balance
    FROM wallets
    WHERE user_id = NEW.user_id;

    -- If high risk or large withdrawal (>$10k or >50% of balance), create approval request
    IF (v_risk_level IN ('high', 'critical') AND ABS(NEW.amount) > 1000)
       OR ABS(NEW.amount) > 10000
       OR (v_total_balance > 0 AND ABS(NEW.amount) > v_total_balance * 0.5) THEN
      
      INSERT INTO withdrawal_approvals (
        user_id,
        transaction_id,
        amount,
        currency,
        destination_address,
        risk_score,
        status,
        auto_approved
      ) VALUES (
        NEW.user_id,
        NEW.id,
        ABS(NEW.amount),
        NEW.currency,
        COALESCE(NEW.address, 'N/A'),
        COALESCE((SELECT overall_score FROM risk_scores WHERE user_id = NEW.user_id), 0),
        'pending',
        false
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Create trigger on transactions
DROP TRIGGER IF EXISTS check_withdrawal_risk ON transactions;
CREATE TRIGGER check_withdrawal_risk
  AFTER INSERT ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_risk_check_on_withdrawal();

-- Function to schedule periodic risk score updates
CREATE OR REPLACE FUNCTION scheduled_risk_score_update()
RETURNS void AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Update risk scores for users with recent activity
  FOR v_user_id IN
    SELECT DISTINCT user_id
    FROM (
      -- Users with recent positions
      SELECT user_id FROM futures_positions
      WHERE opened_at > NOW() - INTERVAL '24 hours'
      UNION
      -- Users with recent transactions
      SELECT user_id FROM transactions
      WHERE created_at > NOW() - INTERVAL '24 hours'
      UNION
      -- Users with recent security events
      SELECT user_id FROM security_logs
      WHERE created_at > NOW() - INTERVAL '24 hours'
      AND user_id IS NOT NULL
    ) AS active_users
  LOOP
    PERFORM update_user_risk_score(v_user_id);
    PERFORM check_and_generate_risk_alerts(v_user_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Initialize risk scores for existing users (limit to avoid timeout)
SELECT update_user_risk_score(id)
FROM user_profiles
WHERE id IN (SELECT id FROM user_profiles LIMIT 50);
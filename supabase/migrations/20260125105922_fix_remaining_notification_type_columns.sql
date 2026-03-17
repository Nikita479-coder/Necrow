/*
  # Fix Remaining notification_type Column References
  
  1. Problem
    - Several functions use 'notification_type' instead of 'type' for notifications table
  
  2. Functions Fixed
    - log_security_incident
    - stop_and_withdraw_copy_trading (notification_type in INSERT)
    - claim_copy_trading_bonus (notification_type in INSERT)
*/

-- Fix log_security_incident
CREATE OR REPLACE FUNCTION log_security_incident(
  p_user_id uuid,
  p_incident_type text,
  p_severity text,
  p_description text,
  p_malicious_content text DEFAULT NULL,
  p_table_name text DEFAULT NULL,
  p_column_name text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO security_incidents (
    user_id,
    incident_type,
    severity,
    description,
    malicious_content,
    table_name,
    column_name
  ) VALUES (
    p_user_id,
    p_incident_type,
    p_severity,
    p_description,
    p_malicious_content,
    p_table_name,
    p_column_name
  );

  -- If critical severity, create admin notification
  IF p_severity = 'critical' THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      read
    )
    SELECT 
      id,
      'system',
      'SECURITY ALERT: XSS Attempt Detected',
      format('User attempted XSS injection in %s.%s', 
        COALESCE(p_table_name, 'unknown'),
        COALESCE(p_column_name, 'unknown')
      ),
      false
    FROM user_profiles
    WHERE is_user_admin(id);
  END IF;
END;
$$;

-- Fix stop_and_withdraw_copy_trading notification insert
CREATE OR REPLACE FUNCTION stop_and_withdraw_copy_trading(p_relationship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_trader_name text;
  v_initial_balance numeric;
  v_original_allocation numeric;
  v_current_balance numeric;
  v_profit numeric;
  v_platform_fee numeric := 0;
  v_withdraw_amount numeric;
  v_copy_wallet_balance numeric;
  v_total_to_deduct numeric;
  v_bonus_amount numeric;
  v_bonus_locked_until timestamptz;
  v_bonus_proportion numeric;
  v_forfeited_amount numeric := 0;
  v_is_bonus_locked boolean := false;
BEGIN
  SELECT *
  INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
  AND follower_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Copy trading relationship not found'
    );
  END IF;

  SELECT name INTO v_trader_name
  FROM traders
  WHERE id = v_relationship.trader_id;

  IF v_relationship.status = 'stopped' OR v_relationship.is_active = false THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'This copy trading relationship is already stopped'
    );
  END IF;

  IF v_relationship.is_mock THEN
    UPDATE copy_relationships
    SET 
      is_active = false,
      status = 'stopped',
      ended_at = now(),
      updated_at = now()
    WHERE id = p_relationship_id;

    RETURN jsonb_build_object(
      'success', true,
      'is_mock', true,
      'message', 'Mock copy trading stopped successfully'
    );
  END IF;

  v_initial_balance := COALESCE(v_relationship.initial_balance::numeric, 0);
  v_bonus_amount := COALESCE(v_relationship.bonus_amount, 0);
  v_bonus_locked_until := v_relationship.bonus_locked_until;
  v_current_balance := v_initial_balance + COALESCE(v_relationship.cumulative_pnl::numeric, 0);

  v_original_allocation := v_initial_balance - v_bonus_amount;

  IF v_bonus_amount > 0 AND v_bonus_locked_until IS NOT NULL AND v_bonus_locked_until > now() THEN
    v_is_bonus_locked := true;
    v_bonus_proportion := v_bonus_amount / v_initial_balance;
    v_forfeited_amount := v_current_balance * v_bonus_proportion;

    v_current_balance := v_current_balance - v_forfeited_amount;
  END IF;

  v_profit := v_current_balance - v_original_allocation;

  IF v_profit > 0 THEN
    v_platform_fee := v_profit * 0.20;
  END IF;

  v_withdraw_amount := v_current_balance - v_platform_fee;

  IF v_withdraw_amount < 0 THEN
    v_withdraw_amount := 0;
  END IF;

  UPDATE copy_relationships
  SET 
    is_active = false,
    status = 'stopped',
    current_balance = '0',
    ended_at = now(),
    updated_at = now()
  WHERE id = p_relationship_id;

  IF v_is_bonus_locked AND v_forfeited_amount > 0 THEN
    UPDATE copy_trading_bonus_claims
    SET 
      forfeited = true,
      forfeited_at = now(),
      forfeited_amount = v_forfeited_amount,
      updated_at = now()
    WHERE relationship_id = p_relationship_id;
  END IF;

  IF v_withdraw_amount > 0 OR v_platform_fee > 0 OR v_forfeited_amount > 0 THEN
    SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
    FROM wallets
    WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = 'copy'
    FOR UPDATE;

    v_total_to_deduct := v_withdraw_amount + v_platform_fee + v_forfeited_amount;

    IF v_total_to_deduct > COALESCE(v_copy_wallet_balance, 0) THEN
      v_total_to_deduct := COALESCE(v_copy_wallet_balance, 0);

      IF v_forfeited_amount > 0 THEN
        IF v_total_to_deduct > v_forfeited_amount THEN
          v_total_to_deduct := v_total_to_deduct;
          v_withdraw_amount := v_total_to_deduct - v_forfeited_amount - v_platform_fee;
          IF v_withdraw_amount < 0 THEN
            v_withdraw_amount := 0;
            v_platform_fee := GREATEST(0, v_total_to_deduct - v_forfeited_amount);
          END IF;
        ELSE
          v_forfeited_amount := v_total_to_deduct;
          v_withdraw_amount := 0;
          v_platform_fee := 0;
        END IF;
      ELSIF v_platform_fee > 0 AND v_total_to_deduct > v_platform_fee THEN
        v_withdraw_amount := v_total_to_deduct - v_platform_fee;
      ELSE
        v_withdraw_amount := v_total_to_deduct;
        v_platform_fee := 0;
      END IF;
    END IF;

    IF v_total_to_deduct > 0 THEN
      UPDATE wallets
      SET balance = balance - v_total_to_deduct,
          updated_at = now()
      WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy';
    END IF;

    IF v_withdraw_amount > 0 THEN
      INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
      VALUES (auth.uid(), 'USDT', 'main', v_withdraw_amount, 0, now(), now())
      ON CONFLICT (user_id, currency, wallet_type)
      DO UPDATE SET
        balance = wallets.balance + v_withdraw_amount,
        updated_at = now();

      INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, details, confirmed_at)
      VALUES (
        auth.uid(), 
        'transfer', 
        'USDT', 
        v_withdraw_amount, 
        v_platform_fee,
        'completed',
        jsonb_build_object(
          'type', 'copy_trading_withdrawal',
          'trader_name', v_trader_name,
          'original_allocation', v_original_allocation,
          'bonus_amount', v_bonus_amount,
          'bonus_forfeited', v_is_bonus_locked,
          'forfeited_amount', v_forfeited_amount
        ),
        now()
      );
    END IF;
  END IF;

  -- FIXED: use 'type' instead of 'notification_type'
  IF v_is_bonus_locked AND v_forfeited_amount > 0 THEN
    INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
    VALUES (
      auth.uid(),
      'system',
      'Copy Trading Bonus Forfeited',
      'You withdrew before the 30-day lock period. ' || ROUND(v_forfeited_amount, 2) || ' USDT (bonus portion) was forfeited.',
      false,
      jsonb_build_object(
        'forfeited_amount', v_forfeited_amount,
        'bonus_amount', v_bonus_amount,
        'relationship_id', p_relationship_id
      ),
      now()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'is_mock', false,
    'original_allocation', v_original_allocation,
    'bonus_amount', v_bonus_amount,
    'initial_balance', v_initial_balance,
    'final_balance', v_current_balance + v_forfeited_amount,
    'profit', v_profit,
    'platform_fee', v_platform_fee,
    'bonus_forfeited', v_is_bonus_locked,
    'forfeited_amount', v_forfeited_amount,
    'withdraw_amount', v_withdraw_amount,
    'message', CASE 
      WHEN v_is_bonus_locked THEN 'Stopped copy trading. Bonus portion forfeited due to early withdrawal.'
      ELSE 'Successfully stopped copy trading and withdrew funds'
    END
  );
END;
$$;

-- Fix claim_copy_trading_bonus notification insert
CREATE OR REPLACE FUNCTION claim_copy_trading_bonus()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_existing_claim RECORD;
  v_eligible_relationship RECORD;
  v_bonus_amount numeric := 100;
  v_lock_days integer := 30;
  v_new_initial_balance numeric;
  v_copy_wallet_balance numeric;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Not authenticated'
    );
  END IF;

  -- Check if user already claimed
  SELECT * INTO v_existing_claim
  FROM copy_trading_bonus_claims
  WHERE user_id = v_user_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You have already claimed the copy trading bonus',
      'claimed_at', v_existing_claim.claimed_at
    );
  END IF;

  -- Find the FIRST eligible relationship (active, real, 500+ initial balance, no bonus yet)
  SELECT cr.*, t.name as trader_name
  INTO v_eligible_relationship
  FROM copy_relationships cr
  LEFT JOIN traders t ON t.id = cr.trader_id
  WHERE cr.follower_id = v_user_id
  AND cr.is_active = true
  AND cr.status = 'active'
  AND (cr.is_mock IS NULL OR cr.is_mock = false)
  AND COALESCE(cr.initial_balance::numeric, 0) >= 500
  AND COALESCE(cr.bonus_amount, 0) = 0
  ORDER BY cr.created_at ASC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No eligible copy trading relationship found. You need an active copy trading position with at least 500 USDT allocated.'
    );
  END IF;

  -- Calculate new initial balance (original + bonus)
  v_new_initial_balance := COALESCE(v_eligible_relationship.initial_balance::numeric, 0) + v_bonus_amount;

  -- Add bonus to copy wallet
  UPDATE wallets
  SET balance = balance + v_bonus_amount,
      updated_at = now()
  WHERE user_id = v_user_id
  AND currency = 'USDT'
  AND wallet_type = 'copy'
  RETURNING balance INTO v_copy_wallet_balance;

  -- If no copy wallet exists, create it with the bonus
  IF v_copy_wallet_balance IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
    VALUES (v_user_id, 'USDT', 'copy', v_bonus_amount, 0, now(), now())
    RETURNING balance INTO v_copy_wallet_balance;
  END IF;

  -- Update the relationship with bonus info
  UPDATE copy_relationships
  SET 
    initial_balance = v_new_initial_balance::text,
    bonus_amount = v_bonus_amount,
    bonus_claimed_at = now(),
    bonus_locked_until = now() + (v_lock_days || ' days')::interval,
    updated_at = now()
  WHERE id = v_eligible_relationship.id;

  -- Record the claim (unique constraint prevents duplicates)
  INSERT INTO copy_trading_bonus_claims (user_id, relationship_id, amount, claimed_at)
  VALUES (v_user_id, v_eligible_relationship.id, v_bonus_amount, now());

  -- FIXED: use 'type' instead of 'notification_type'
  INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
  VALUES (
    v_user_id,
    'reward',
    'Copy Trading Bonus Claimed!',
    'You received 100 USDT bonus on your copy trading with ' || COALESCE(v_eligible_relationship.trader_name, 'trader') || '. The bonus is locked for 30 days.',
    false,
    jsonb_build_object(
      'bonus_amount', v_bonus_amount,
      'relationship_id', v_eligible_relationship.id,
      'trader_name', v_eligible_relationship.trader_name,
      'locked_until', now() + (v_lock_days || ' days')::interval
    ),
    now()
  );

  -- Record transaction
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details, confirmed_at)
  VALUES (
    v_user_id,
    'reward',
    'USDT',
    v_bonus_amount,
    'completed',
    jsonb_build_object(
      'type', 'copy_trading_bonus',
      'relationship_id', v_eligible_relationship.id,
      'trader_name', v_eligible_relationship.trader_name,
      'original_allocation', v_eligible_relationship.initial_balance,
      'new_allocation', v_new_initial_balance,
      'locked_until', now() + (v_lock_days || ' days')::interval
    ),
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Successfully claimed 100 USDT copy trading bonus!',
    'relationship_id', v_eligible_relationship.id,
    'trader_name', v_eligible_relationship.trader_name,
    'bonus_amount', v_bonus_amount,
    'new_initial_balance', v_new_initial_balance,
    'copy_wallet_balance', v_copy_wallet_balance,
    'locked_until', now() + (v_lock_days || ' days')::interval
  );
END;
$$;

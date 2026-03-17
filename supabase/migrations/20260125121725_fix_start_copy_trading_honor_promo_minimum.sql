/*
  # Fix Start Copy Trading to Honor Promo Code Minimum

  1. Changes
    - Update start_copy_trading function to check for active promo code redemptions
    - If user has active copy_trading_only promo bonus, reduce minimum from $100 to $20
    - Allow users with promo bonus to start copy trading with their bonus amount

  2. Impact
    - Users with COPY20 promo code can now start copying with just $20
*/

CREATE OR REPLACE FUNCTION start_copy_trading(
  p_trader_id uuid,
  p_allocation_percentage integer,
  p_leverage integer DEFAULT 1,
  p_stop_loss_percent numeric DEFAULT NULL,
  p_take_profit_percent numeric DEFAULT NULL,
  p_is_mock boolean DEFAULT false,
  p_require_approval boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_follower_id uuid;
  v_existing_relationship copy_relationships;
  v_relationship_id uuid;
  v_trader_exists boolean;
  v_trader_name text;
  v_copy_wallet_id uuid;
  v_wallet_balance numeric;
  v_already_allocated numeric;
  v_available_balance numeric;
  v_initial_balance numeric;
  v_bonus_eligible boolean := false;
  v_bonus_amount numeric := 100;
  v_lock_days integer := 30;
  v_existing_claim_count integer;
  v_minimum_amount numeric := 100;
  v_has_promo_bonus boolean := false;
  v_promo_bonus_amount numeric := 0;
BEGIN
  v_follower_id := auth.uid();

  IF v_follower_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_allocation_percentage < 1 OR p_allocation_percentage > 100 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Allocation percentage must be between 1 and 100'
    );
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Leverage must be between 1 and 125'
    );
  END IF;

  SELECT EXISTS(SELECT 1 FROM traders WHERE id = p_trader_id), name 
  INTO v_trader_exists, v_trader_name
  FROM traders WHERE id = p_trader_id;

  IF NOT v_trader_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trader not found');
  END IF;

  SELECT * INTO v_existing_relationship
  FROM copy_relationships
  WHERE follower_id = v_follower_id
  AND trader_id = p_trader_id
  AND is_mock = p_is_mock;

  IF FOUND AND v_existing_relationship.status = 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You are already copying this trader in ' || 
        CASE WHEN p_is_mock THEN 'mock' ELSE 'real' END || ' mode'
    );
  END IF;

  -- Check for active promo bonus to reduce minimum
  IF NOT p_is_mock THEN
    SELECT COALESCE(SUM(pcr.bonus_amount), 0) INTO v_promo_bonus_amount
    FROM promo_code_redemptions pcr
    JOIN promo_codes pc ON pc.id = pcr.promo_code_id
    WHERE pcr.user_id = v_follower_id
    AND pcr.status = 'active'
    AND pcr.bonus_expires_at > now()
    AND pc.bonus_type = 'copy_trading_only';

    IF v_promo_bonus_amount > 0 THEN
      v_has_promo_bonus := true;
      -- Reduce minimum to the promo bonus amount (e.g., $20 for COPY20)
      v_minimum_amount := LEAST(v_promo_bonus_amount, 100);
    END IF;
  END IF;

  -- Calculate initial balance based on mode
  IF p_is_mock THEN
    v_initial_balance := 10000.0 * p_allocation_percentage / 100.0;
  ELSE
    SELECT balance INTO v_wallet_balance
    FROM wallets
    WHERE user_id = v_follower_id
    AND currency = 'USDT'
    AND wallet_type = 'copy';

    IF v_wallet_balance IS NULL THEN
      INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
      VALUES (v_follower_id, 'USDT', 'copy', 0, 0)
      ON CONFLICT (user_id, currency, wallet_type) 
      DO UPDATE SET updated_at = NOW()
      RETURNING balance INTO v_wallet_balance;
    END IF;

    SELECT COALESCE(SUM(initial_balance), 0) INTO v_already_allocated
    FROM copy_relationships
    WHERE follower_id = v_follower_id
    AND is_active = true
    AND is_mock = false
    AND trader_id != p_trader_id;

    v_available_balance := GREATEST(0, v_wallet_balance - v_already_allocated);

    IF v_available_balance < v_minimum_amount THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Minimum available balance of ' || v_minimum_amount || ' USDT required. You have ' || 
          ROUND(v_available_balance, 2)::text || ' USDT available (Total: ' || 
          ROUND(v_wallet_balance, 2)::text || ' - Allocated: ' || 
          ROUND(v_already_allocated, 2)::text || ')'
      );
    END IF;

    v_initial_balance := v_available_balance * p_allocation_percentage / 100.0;

    IF v_initial_balance < v_minimum_amount THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Calculated allocation is ' || ROUND(v_initial_balance, 2)::text || 
          ' USDT but minimum is ' || v_minimum_amount || ' USDT. Increase your allocation percentage.'
      );
    END IF;

    -- Check bonus eligibility: $500+ allocation, real mode, not already claimed (only for non-promo users)
    IF v_initial_balance >= 500 AND NOT v_has_promo_bonus THEN
      SELECT COUNT(*) INTO v_existing_claim_count
      FROM copy_trading_bonus_claims
      WHERE user_id = v_follower_id;

      IF v_existing_claim_count = 0 THEN
        v_bonus_eligible := true;
      END IF;
    END IF;
  END IF;

  IF FOUND AND v_existing_relationship.status IN ('stopped', 'paused') THEN
    UPDATE copy_relationships
    SET 
      is_active = true,
      status = 'active',
      allocation_percentage = p_allocation_percentage,
      leverage = p_leverage,
      stop_loss_percent = p_stop_loss_percent,
      take_profit_percent = p_take_profit_percent,
      require_approval = p_require_approval,
      initial_balance = v_initial_balance,
      current_balance = v_initial_balance,
      cumulative_pnl = 0,
      total_pnl = 0,
      ended_at = NULL,
      updated_at = NOW()
    WHERE id = v_existing_relationship.id
    RETURNING id INTO v_relationship_id;

    -- Grant bonus on restart if eligible
    IF v_bonus_eligible AND NOT p_is_mock THEN
      UPDATE wallets
      SET balance = balance + v_bonus_amount, updated_at = now()
      WHERE user_id = v_follower_id AND currency = 'USDT' AND wallet_type = 'copy';

      UPDATE copy_relationships
      SET 
        initial_balance = v_initial_balance + v_bonus_amount,
        current_balance = v_initial_balance + v_bonus_amount,
        bonus_amount = v_bonus_amount,
        bonus_claimed_at = now(),
        bonus_locked_until = now() + (v_lock_days || ' days')::interval
      WHERE id = v_relationship_id;

      INSERT INTO copy_trading_bonus_claims (user_id, relationship_id, amount, claimed_at)
      VALUES (v_follower_id, v_relationship_id, v_bonus_amount, now());

      INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
      VALUES (
        v_follower_id, 'reward', 'Copy Trading Bonus!',
        'You received 100 USDT bonus on your copy trading with ' || COALESCE(v_trader_name, 'trader') || '. Keep it for 30 days to unlock!',
        false,
        jsonb_build_object('bonus_amount', v_bonus_amount, 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
        now()
      );

      INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details, confirmed_at)
      VALUES (v_follower_id, 'reward', 'USDT', v_bonus_amount, 'completed',
        jsonb_build_object('type', 'copy_trading_bonus', 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
        now()
      );

      RETURN jsonb_build_object(
        'success', true,
        'relationship_id', v_relationship_id,
        'message', 'Copy trading restarted with 100 USDT bonus!',
        'initial_balance', v_initial_balance + v_bonus_amount,
        'bonus_granted', true,
        'bonus_amount', v_bonus_amount
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'message', 'Copy trading restarted successfully',
      'initial_balance', v_initial_balance
    );
  END IF;

  -- Ensure copy wallet exists
  SELECT id INTO v_copy_wallet_id
  FROM wallets
  WHERE user_id = v_follower_id 
  AND wallet_type = 'copy'
  AND currency = 'USDT';

  IF v_copy_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
    VALUES (v_follower_id, 'USDT', 'copy', 0, 0)
    ON CONFLICT (user_id, currency, wallet_type) 
    DO UPDATE SET updated_at = NOW()
    RETURNING id INTO v_copy_wallet_id;
  END IF;

  -- Insert new relationship
  INSERT INTO copy_relationships (
    follower_id, trader_id, is_active, allocation_percentage, leverage,
    stop_loss_percent, take_profit_percent, initial_balance, current_balance,
    total_pnl, is_mock, status, require_approval
  ) VALUES (
    v_follower_id, p_trader_id, true, p_allocation_percentage, p_leverage,
    p_stop_loss_percent, p_take_profit_percent, v_initial_balance, v_initial_balance,
    0, p_is_mock, 'active', p_require_approval
  )
  RETURNING id INTO v_relationship_id;

  -- Grant bonus for new relationship if eligible
  IF v_bonus_eligible AND NOT p_is_mock THEN
    UPDATE wallets
    SET balance = balance + v_bonus_amount, updated_at = now()
    WHERE user_id = v_follower_id AND currency = 'USDT' AND wallet_type = 'copy';

    UPDATE copy_relationships
    SET 
      initial_balance = v_initial_balance + v_bonus_amount,
      current_balance = v_initial_balance + v_bonus_amount,
      bonus_amount = v_bonus_amount,
      bonus_claimed_at = now(),
      bonus_locked_until = now() + (v_lock_days || ' days')::interval
    WHERE id = v_relationship_id;

    INSERT INTO copy_trading_bonus_claims (user_id, relationship_id, amount, claimed_at)
    VALUES (v_follower_id, v_relationship_id, v_bonus_amount, now());

    INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
    VALUES (
      v_follower_id, 'reward', 'Copy Trading Bonus!',
      'You received 100 USDT bonus on your copy trading with ' || COALESCE(v_trader_name, 'trader') || '. Keep it for 30 days to unlock!',
      false,
      jsonb_build_object('bonus_amount', v_bonus_amount, 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
      now()
    );

    INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details, confirmed_at)
    VALUES (v_follower_id, 'reward', 'USDT', v_bonus_amount, 'completed',
      jsonb_build_object('type', 'copy_trading_bonus', 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
      now()
    );

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'message', 'Copy trading started with 100 USDT bonus!',
      'initial_balance', v_initial_balance + v_bonus_amount,
      'bonus_granted', true,
      'bonus_amount', v_bonus_amount
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'relationship_id', v_relationship_id,
    'message', 'Copy trading started successfully',
    'initial_balance', v_initial_balance
  );
END;
$$;

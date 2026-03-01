/*
  # Fix Promo Bonus Mixed Funds Withdrawal

  Handle scenario where user has promo bonus ($20) + their own added funds ($X):
  
  - Before 30 days: Lose ONLY the $20 promo bonus portion, keep user's own funds + profits on user funds
  - After 30 days: Promo bonus expires, keep all profits from everything

  The key is to calculate proportional profits based on:
  - user_allocation = total_initial - promo_bonus
  - promo_proportion = promo_bonus / total_initial
  - user_proportion = user_allocation / total_initial
*/

-- Update the preview calculation function
CREATE OR REPLACE FUNCTION calculate_copy_trading_early_withdrawal(p_relationship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_promo_bonus RECORD;
  v_initial_balance numeric;
  v_current_balance numeric;
  v_bonus_amount numeric;
  v_bonus_locked_until timestamptz;
  v_user_allocation numeric;
  v_profit numeric;
  v_total_profit numeric;
  v_user_profit numeric;
  v_promo_profit numeric;
  v_platform_fee numeric := 0;
  v_you_will_receive numeric;
  v_forfeited_amount numeric := 0;
  v_is_bonus_locked boolean := false;
  v_days_remaining integer := 0;
  v_has_promo boolean := false;
  v_promo_proportion numeric;
  v_user_proportion numeric;
BEGIN
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
  AND follower_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Relationship not found');
  END IF;

  -- Check for promo code bonus
  SELECT 
    pcr.bonus_amount,
    pcr.bonus_expires_at,
    pc.bonus_type
  INTO v_promo_bonus
  FROM promo_code_redemptions pcr
  JOIN promo_codes pc ON pc.id = pcr.promo_code_id
  WHERE pcr.user_id = auth.uid()
  AND pcr.status = 'active'
  AND pc.bonus_type = 'copy_trading_only'
  ORDER BY pcr.created_at DESC
  LIMIT 1;

  v_initial_balance := COALESCE(v_relationship.initial_balance::numeric, 0);
  v_current_balance := v_initial_balance + COALESCE(v_relationship.cumulative_pnl::numeric, 0);
  v_bonus_amount := COALESCE(v_relationship.bonus_amount, 0);
  v_bonus_locked_until := v_relationship.bonus_locked_until;
  v_total_profit := v_current_balance - v_initial_balance;

  -- Check if user has a promo bonus
  IF FOUND AND v_promo_bonus.bonus_amount IS NOT NULL THEN
    v_has_promo := true;
    
    -- Calculate user's own allocation (funds they added themselves)
    v_user_allocation := v_initial_balance - v_promo_bonus.bonus_amount;
    
    -- Calculate proportions
    IF v_initial_balance > 0 THEN
      v_promo_proportion := v_promo_bonus.bonus_amount / v_initial_balance;
      v_user_proportion := v_user_allocation / v_initial_balance;
    ELSE
      v_promo_proportion := 1;
      v_user_proportion := 0;
    END IF;
    
    -- Calculate profit split
    v_promo_profit := v_total_profit * v_promo_proportion;
    v_user_profit := v_total_profit * v_user_proportion;
    
    IF v_promo_bonus.bonus_expires_at > now() THEN
      -- WITHIN 30 DAYS: Forfeit promo bonus + promo profits, keep user funds + user profits
      v_is_bonus_locked := true;
      v_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_promo_bonus.bonus_expires_at - now()))::integer);
      
      -- Forfeit promo portion (bonus + its profits)
      v_forfeited_amount := v_promo_bonus.bonus_amount + GREATEST(0, v_promo_profit);
      
      -- User keeps their allocation + their share of profits
      v_profit := v_user_profit;
      
      IF v_profit > 0 THEN
        v_platform_fee := v_profit * 0.20;
        v_you_will_receive := v_user_allocation + v_profit - v_platform_fee;
      ELSE
        -- If user's portion has losses, they still get their allocation minus those losses
        v_you_will_receive := GREATEST(0, v_user_allocation + v_profit);
      END IF;
    ELSE
      -- 30 DAYS PASSED: Promo bonus expires, keep all profits
      v_forfeited_amount := v_promo_bonus.bonus_amount; -- Just the bonus itself expires
      v_profit := v_total_profit; -- All profits belong to user now
      
      IF v_profit > 0 THEN
        v_platform_fee := v_profit * 0.20;
        v_you_will_receive := v_user_allocation + v_profit - v_platform_fee;
      ELSE
        v_you_will_receive := GREATEST(0, v_user_allocation + v_profit);
      END IF;
    END IF;
    
    RETURN jsonb_build_object(
      'success', true,
      'has_promo', true,
      'is_promo_only', v_user_allocation < 1, -- True if user has no own funds
      'is_bonus_locked', v_is_bonus_locked,
      'days_remaining', v_days_remaining,
      'initial_balance', v_initial_balance,
      'current_balance', v_current_balance,
      'promo_bonus_amount', v_promo_bonus.bonus_amount,
      'user_allocation', v_user_allocation,
      'total_profit', v_total_profit,
      'user_profit', v_user_profit,
      'promo_profit', v_promo_profit,
      'profit', v_profit,
      'platform_fee', v_platform_fee,
      'forfeited_amount', v_forfeited_amount,
      'you_will_receive', GREATEST(0, v_you_will_receive)
    );
  END IF;

  -- Standard bonus calculation (for $500+ copy trading bonus, not promo)
  v_user_allocation := v_initial_balance - v_bonus_amount;

  IF v_bonus_amount > 0 AND v_bonus_locked_until IS NOT NULL AND v_bonus_locked_until > now() THEN
    v_is_bonus_locked := true;
    v_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_bonus_locked_until - now()))::integer);
    
    v_promo_proportion := v_bonus_amount / v_initial_balance;
    v_forfeited_amount := v_current_balance * v_promo_proportion;
    v_current_balance := v_current_balance - v_forfeited_amount;
  END IF;

  v_profit := v_current_balance - v_user_allocation;

  IF v_profit > 0 THEN
    v_platform_fee := v_profit * 0.20;
  END IF;

  v_you_will_receive := v_current_balance - v_platform_fee;

  RETURN jsonb_build_object(
    'success', true,
    'has_promo', false,
    'is_promo_only', false,
    'is_bonus_locked', v_is_bonus_locked,
    'days_remaining', v_days_remaining,
    'initial_balance', v_initial_balance,
    'current_balance', v_current_balance + v_forfeited_amount,
    'user_allocation', v_user_allocation,
    'bonus_amount', v_bonus_amount,
    'profit', v_profit,
    'platform_fee', v_platform_fee,
    'forfeited_amount', v_forfeited_amount,
    'you_will_receive', GREATEST(0, v_you_will_receive)
  );
END;
$$;


-- Update the stop and withdraw function
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
  v_current_balance numeric;
  v_total_profit numeric;
  v_user_profit numeric;
  v_promo_profit numeric;
  v_profit numeric;
  v_platform_fee numeric := 0;
  v_withdraw_amount numeric;
  v_copy_wallet_balance numeric;
  v_total_to_deduct numeric;
  v_bonus_amount numeric;
  v_bonus_locked_until timestamptz;
  v_forfeited_amount numeric := 0;
  v_is_bonus_locked boolean := false;
  v_user_allocation numeric;
  v_promo_bonus RECORD;
  v_has_promo boolean := false;
  v_is_promo_only boolean := false;
  v_promo_proportion numeric;
  v_user_proportion numeric;
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
  v_total_profit := v_current_balance - v_initial_balance;

  -- Check for promo code bonus
  SELECT 
    pcr.bonus_amount,
    pcr.bonus_expires_at,
    pc.bonus_type,
    pcr.id as redemption_id
  INTO v_promo_bonus
  FROM promo_code_redemptions pcr
  JOIN promo_codes pc ON pc.id = pcr.promo_code_id
  WHERE pcr.user_id = auth.uid()
  AND pcr.status = 'active'
  AND pc.bonus_type = 'copy_trading_only'
  ORDER BY pcr.created_at DESC
  LIMIT 1;

  -- Check if user has promo bonus
  IF FOUND AND v_promo_bonus.bonus_amount IS NOT NULL THEN
    v_has_promo := true;
    
    -- Calculate user's own allocation
    v_user_allocation := v_initial_balance - v_promo_bonus.bonus_amount;
    v_is_promo_only := v_user_allocation < 1;
    
    -- Calculate proportions
    IF v_initial_balance > 0 THEN
      v_promo_proportion := v_promo_bonus.bonus_amount / v_initial_balance;
      v_user_proportion := v_user_allocation / v_initial_balance;
    ELSE
      v_promo_proportion := 1;
      v_user_proportion := 0;
    END IF;
    
    -- Calculate profit split
    v_promo_profit := v_total_profit * v_promo_proportion;
    v_user_profit := v_total_profit * v_user_proportion;
    
    IF v_promo_bonus.bonus_expires_at > now() THEN
      -- WITHIN 30 DAYS: Forfeit promo portion, keep user portion
      v_is_bonus_locked := true;
      v_forfeited_amount := v_promo_bonus.bonus_amount + GREATEST(0, v_promo_profit);
      v_profit := v_user_profit;
      
      IF v_profit > 0 THEN
        v_platform_fee := v_profit * 0.20;
        v_withdraw_amount := v_user_allocation + v_profit - v_platform_fee;
      ELSE
        v_withdraw_amount := GREATEST(0, v_user_allocation + v_profit);
        v_platform_fee := 0;
      END IF;
    ELSE
      -- 30 DAYS PASSED: Promo expires, keep all profits
      v_forfeited_amount := v_promo_bonus.bonus_amount;
      v_profit := v_total_profit;
      
      IF v_profit > 0 THEN
        v_platform_fee := v_profit * 0.20;
        v_withdraw_amount := v_user_allocation + v_profit - v_platform_fee;
      ELSE
        v_withdraw_amount := GREATEST(0, v_user_allocation + v_profit);
        v_platform_fee := 0;
      END IF;
    END IF;

    -- Mark promo as used/expired
    UPDATE promo_code_redemptions
    SET status = 'used', updated_at = now()
    WHERE id = v_promo_bonus.redemption_id;

    -- Stop the relationship
    UPDATE copy_relationships
    SET 
      is_active = false,
      status = 'stopped',
      current_balance = '0',
      ended_at = now(),
      updated_at = now()
    WHERE id = p_relationship_id;

    -- Deduct from copy wallet
    SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
    FROM wallets
    WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = 'copy'
    FOR UPDATE;

    v_total_to_deduct := LEAST(v_current_balance, COALESCE(v_copy_wallet_balance, 0));

    IF v_total_to_deduct > 0 THEN
      UPDATE wallets
      SET balance = balance - v_total_to_deduct,
          updated_at = now()
      WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = 'copy';
    END IF;

    -- Credit user's portion to main wallet
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
          'type', 'promo_copy_trading_withdrawal',
          'trader_name', v_trader_name,
          'promo_bonus_forfeited', v_promo_bonus.bonus_amount,
          'user_allocation', v_user_allocation,
          'early_withdrawal', v_is_bonus_locked,
          'profit_withdrawn', CASE WHEN v_profit > 0 THEN v_profit - v_platform_fee ELSE 0 END
        ),
        now()
      );
    END IF;

    -- Notification
    IF v_is_bonus_locked THEN
      INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
      VALUES (
        auth.uid(),
        'system',
        'Promo Bonus Forfeited',
        CASE 
          WHEN v_is_promo_only THEN 
            'You withdrew before 30 days. All ' || ROUND(v_current_balance, 2) || ' USDT was forfeited.'
          ELSE 
            'You withdrew before 30 days. Promo bonus of ' || ROUND(v_promo_bonus.bonus_amount, 2) || ' USDT was forfeited. You received ' || ROUND(v_withdraw_amount, 2) || ' USDT (your funds + profits).'
        END,
        false,
        jsonb_build_object(
          'forfeited_amount', v_forfeited_amount,
          'promo_bonus_amount', v_promo_bonus.bonus_amount,
          'user_allocation', v_user_allocation,
          'withdrawn_amount', v_withdraw_amount,
          'relationship_id', p_relationship_id
        ),
        now()
      );
    ELSIF v_withdraw_amount > 0 THEN
      INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
      VALUES (
        auth.uid(),
        'reward',
        'Copy Trading Withdrawn',
        'Promo bonus expired. ' || ROUND(v_withdraw_amount, 2) || ' USDT transferred to your wallet.',
        false,
        jsonb_build_object(
          'profit_amount', v_withdraw_amount,
          'bonus_expired', v_promo_bonus.bonus_amount,
          'relationship_id', p_relationship_id
        ),
        now()
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'is_mock', false,
      'has_promo', true,
      'is_promo_only', v_is_promo_only,
      'user_allocation', v_user_allocation,
      'promo_bonus_amount', v_promo_bonus.bonus_amount,
      'initial_balance', v_initial_balance,
      'final_balance', v_current_balance,
      'total_profit', v_total_profit,
      'user_profit', v_user_profit,
      'profit', v_profit,
      'platform_fee', v_platform_fee,
      'bonus_forfeited', v_is_bonus_locked,
      'forfeited_amount', v_forfeited_amount,
      'withdraw_amount', v_withdraw_amount,
      'message', CASE 
        WHEN v_is_bonus_locked AND v_is_promo_only THEN 
          'Promo bonus forfeited due to early withdrawal. All funds lost.'
        WHEN v_is_bonus_locked THEN 
          'Promo bonus forfeited. ' || ROUND(v_withdraw_amount, 2) || ' USDT (your funds) withdrawn.'
        WHEN v_withdraw_amount > 0 THEN 
          'Promo bonus expired. ' || ROUND(v_withdraw_amount, 2) || ' USDT withdrawn.'
        ELSE 
          'Promo bonus expired with no profits.'
      END
    );
  END IF;

  -- Standard bonus handling (for $500+ copy trading bonus)
  v_user_allocation := v_initial_balance - v_bonus_amount;

  IF v_bonus_amount > 0 AND v_bonus_locked_until IS NOT NULL AND v_bonus_locked_until > now() THEN
    v_is_bonus_locked := true;
    v_promo_proportion := v_bonus_amount / v_initial_balance;
    v_forfeited_amount := v_current_balance * v_promo_proportion;
    v_current_balance := v_current_balance - v_forfeited_amount;
  END IF;

  v_profit := v_current_balance - v_user_allocation;

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
          'user_allocation', v_user_allocation,
          'bonus_amount', v_bonus_amount,
          'bonus_forfeited', v_is_bonus_locked,
          'forfeited_amount', v_forfeited_amount
        ),
        now()
      );
    END IF;
  END IF;

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
    'has_promo', false,
    'is_promo_only', false,
    'user_allocation', v_user_allocation,
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

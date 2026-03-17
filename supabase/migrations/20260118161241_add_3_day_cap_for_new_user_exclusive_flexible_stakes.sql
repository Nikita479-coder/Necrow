/*
  # Add 3-Day Cap for New User Exclusive Flexible Stakes

  ## Summary
  New User Exclusive products with 555% APR are promotional offers that should have
  a time limit even for flexible products. This migration adds a 3-day automatic
  expiration for flexible new user exclusive staking products.

  ## Changes
  1. Updates stake_tokens function to set 3-day end_date for new user exclusive flexible products
  2. Creates auto_unstake_expired_flexible_stakes function to automatically close expired stakes
  3. Ensures promotional high-APR products don't run indefinitely

  ## Business Logic
  - Regular flexible products: No end date (withdraw anytime)
  - Fixed products: End date = duration_days from start
  - New User Exclusive Flexible: End date = 3 days from start (auto-unstake after)
*/

-- Update stake_tokens to add 3-day cap for new user exclusive flexible products
CREATE OR REPLACE FUNCTION stake_tokens(
  user_id_param uuid, 
  product_id_param uuid, 
  amount_param numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product RECORD;
  v_main_wallet RECORD;
  v_assets_wallet RECORD;
  v_stake_id uuid;
  v_end_date timestamptz;
BEGIN
  SELECT * INTO v_product 
  FROM earn_products 
  WHERE id = product_id_param AND is_active = true;
  
  IF NOT FOUND THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Product not found or inactive'); 
  END IF;

  IF amount_param < v_product.min_amount THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Amount below minimum of ' || v_product.min_amount || ' ' || v_product.coin); 
  END IF;

  IF v_product.max_amount IS NOT NULL AND amount_param > v_product.max_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount exceeds maximum of ' || v_product.max_amount || ' ' || v_product.coin);
  END IF;

  IF (v_product.invested_amount + amount_param) > v_product.total_cap THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pool capacity exceeded');
  END IF;

  SELECT * INTO v_main_wallet 
  FROM wallets 
  WHERE user_id = user_id_param 
    AND currency = v_product.coin 
    AND wallet_type = 'main' 
  FOR UPDATE;
  
  IF NOT FOUND OR v_main_wallet.balance < amount_param THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance'); 
  END IF;

  SELECT * INTO v_assets_wallet
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = v_product.coin 
    AND wallet_type = 'assets'
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
    VALUES (user_id_param, v_product.coin, 'assets', 0, 0)
    RETURNING * INTO v_assets_wallet;
  END IF;

  UPDATE wallets 
  SET balance = balance - amount_param, 
      updated_at = now() 
  WHERE id = v_main_wallet.id;

  UPDATE wallets
  SET locked_balance = locked_balance + amount_param,
      updated_at = now()
  WHERE id = v_assets_wallet.id;

  -- Calculate end date with 3-day cap for new user exclusive flexible products
  IF v_product.duration_days > 0 THEN
    -- Fixed duration products: use the specified duration
    v_end_date := now() + (v_product.duration_days || ' days')::interval;
  ELSIF v_product.is_new_user_exclusive = true AND v_product.product_type = 'flexible' THEN
    -- New user exclusive flexible products: 3-day cap
    v_end_date := now() + interval '3 days';
  ELSE
    -- Regular flexible products: no end date
    v_end_date := NULL;
  END IF;

  INSERT INTO user_stakes (
    user_id, 
    product_id, 
    amount, 
    apr_locked, 
    status, 
    start_date, 
    end_date, 
    last_reward_date,
    earned_rewards
  )
  VALUES (
    user_id_param, 
    product_id_param, 
    amount_param, 
    v_product.apr, 
    'active', 
    now(), 
    v_end_date, 
    now(),
    0
  )
  RETURNING id INTO v_stake_id;

  UPDATE earn_products
  SET invested_amount = invested_amount + amount_param,
      updated_at = now()
  WHERE id = product_id_param;

  INSERT INTO transactions (
    user_id, 
    transaction_type, 
    currency, 
    amount, 
    status,
    details
  ) 
  VALUES (
    user_id_param, 
    'stake', 
    v_product.coin, 
    amount_param, 
    'completed',
    'Staked ' || amount_param || ' ' || v_product.coin || ' at ' || v_product.apr || '% APR'
  );

  RETURN jsonb_build_object(
    'success', true, 
    'stake_id', v_stake_id, 
    'message', 'Successfully staked ' || amount_param || ' ' || v_product.coin
  );
END;
$$;

-- Create function to auto-unstake expired flexible stakes
CREATE OR REPLACE FUNCTION auto_unstake_expired_flexible_stakes()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stake RECORD;
  v_product RECORD;
  v_assets_wallet RECORD;
  v_main_wallet RECORD;
  v_total_amount numeric;
  v_unstaked_count int := 0;
  v_errors text[] := '{}';
BEGIN
  -- Find all expired stakes that need to be auto-unstaked
  FOR v_stake IN 
    SELECT us.*, ep.coin, ep.product_type, ep.is_new_user_exclusive
    FROM user_stakes us
    JOIN earn_products ep ON us.product_id = ep.id
    WHERE us.status = 'active'
      AND us.end_date IS NOT NULL
      AND us.end_date <= now()
      AND ep.product_type = 'flexible'
      AND ep.is_new_user_exclusive = true
  LOOP
    BEGIN
      -- Get assets wallet
      SELECT * INTO v_assets_wallet
      FROM wallets
      WHERE user_id = v_stake.user_id 
        AND currency = v_stake.coin 
        AND wallet_type = 'assets'
      FOR UPDATE;

      -- Get or create main wallet
      SELECT * INTO v_main_wallet
      FROM wallets
      WHERE user_id = v_stake.user_id 
        AND currency = v_stake.coin 
        AND wallet_type = 'main'
      FOR UPDATE;

      IF NOT FOUND THEN
        INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
        VALUES (v_stake.user_id, v_stake.coin, 'main', 0, 0)
        RETURNING * INTO v_main_wallet;
      END IF;

      -- Calculate total to return (principal + rewards)
      v_total_amount := v_stake.amount + v_stake.earned_rewards;

      -- Return funds to main wallet
      UPDATE wallets
      SET balance = balance + v_total_amount,
          updated_at = now()
      WHERE id = v_main_wallet.id;

      -- Reduce locked balance in assets wallet
      UPDATE wallets
      SET locked_balance = GREATEST(0, locked_balance - v_stake.amount),
          updated_at = now()
      WHERE id = v_assets_wallet.id;

      -- Mark stake as completed
      UPDATE user_stakes
      SET status = 'completed',
          updated_at = now()
      WHERE id = v_stake.id;

      -- Update product invested amount
      UPDATE earn_products
      SET invested_amount = GREATEST(0, invested_amount - v_stake.amount),
          updated_at = now()
      WHERE id = v_stake.product_id;

      -- Create transaction record
      INSERT INTO transactions (
        user_id,
        transaction_type,
        currency,
        amount,
        status,
        details
      ) VALUES (
        v_stake.user_id,
        'unstake',
        v_stake.coin,
        v_total_amount,
        'completed',
        'Auto-unstaked after 3-day promotional period. Principal: ' || v_stake.amount || ', Rewards: ' || v_stake.earned_rewards
      );

      -- Create notification
      INSERT INTO notifications (user_id, notification_type, title, message, read)
      VALUES (
        v_stake.user_id,
        'system',
        'Staking Period Ended',
        'Your ' || v_stake.amount || ' ' || v_stake.coin || ' stake has completed after the 3-day promotional period. ' || v_total_amount || ' ' || v_stake.coin || ' has been returned to your wallet.',
        false
      );

      v_unstaked_count := v_unstaked_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := array_append(v_errors, 'Stake ' || v_stake.id || ': ' || SQLERRM);
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'unstaked_count', v_unstaked_count,
    'errors', v_errors
  );
END;
$$;

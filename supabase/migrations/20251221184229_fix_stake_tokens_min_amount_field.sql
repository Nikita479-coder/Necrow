/*
  # Fix stake_tokens Function - Correct Field Name

  ## Summary
  The stake_tokens function was referencing a non-existent field 'min_stake'
  instead of the correct 'min_amount' field from the earn_products table.
  This was causing staking to fail with "record has no field" error.

  ## Changes
  - Updates stake_tokens function to use 'min_amount' instead of 'min_stake'
  - Also fixes other missing fields that should be checked
*/

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
  -- Get product details
  SELECT * INTO v_product 
  FROM earn_products 
  WHERE id = product_id_param AND is_active = true;
  
  IF NOT FOUND THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Product not found or inactive'); 
  END IF;

  -- Validate minimum amount (using correct field name: min_amount)
  IF amount_param < v_product.min_amount THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Amount below minimum of ' || v_product.min_amount || ' ' || v_product.coin); 
  END IF;

  -- Validate maximum amount if set
  IF v_product.max_amount IS NOT NULL AND amount_param > v_product.max_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount exceeds maximum of ' || v_product.max_amount || ' ' || v_product.coin);
  END IF;

  -- Check if pool has capacity
  IF (v_product.invested_amount + amount_param) > v_product.total_cap THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pool capacity exceeded');
  END IF;

  -- Get main wallet
  SELECT * INTO v_main_wallet 
  FROM wallets 
  WHERE user_id = user_id_param 
    AND currency = v_product.coin 
    AND wallet_type = 'main' 
  FOR UPDATE;
  
  IF NOT FOUND OR v_main_wallet.balance < amount_param THEN 
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance'); 
  END IF;

  -- Get or create assets wallet
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

  -- Deduct from main wallet
  UPDATE wallets 
  SET balance = balance - amount_param, 
      updated_at = now() 
  WHERE id = v_main_wallet.id;

  -- Lock in assets wallet
  UPDATE wallets
  SET locked_balance = locked_balance + amount_param,
      updated_at = now()
  WHERE id = v_assets_wallet.id;

  -- Calculate end date
  IF v_product.duration_days > 0 THEN
    v_end_date := now() + (v_product.duration_days || ' days')::interval;
  ELSE
    v_end_date := NULL;
  END IF;

  -- Create stake record
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

  -- Update product invested amount
  UPDATE earn_products
  SET invested_amount = invested_amount + amount_param,
      updated_at = now()
  WHERE id = product_id_param;

  -- Create transaction record
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

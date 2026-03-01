/*
  # Fix Staking Functions - Transaction Columns

  ## Summary
  Updates staking functions to use correct transaction table columns:
  - Use `transaction_type` instead of `type`
  - Remove `description` column (not in schema)
  - Add proper fee and network fields where applicable

  ## Changes
  - Fix stake_tokens function
  - Fix unstake_tokens function
  - Fix claim_stake_rewards function
  - Fix transfer_between_wallets function
*/

-- Function to stake tokens (fixed version)
CREATE OR REPLACE FUNCTION stake_tokens(
  user_id_param uuid,
  product_id_param uuid,
  amount_param numeric
)
RETURNS jsonb AS $$
DECLARE
  product_record RECORD;
  main_wallet_record RECORD;
  assets_wallet_record RECORD;
  new_stake_id uuid;
  end_date_calc timestamptz;
BEGIN
  SELECT * INTO product_record
  FROM earn_products
  WHERE id = product_id_param AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Product not found or inactive');
  END IF;

  IF amount_param < product_record.min_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount below minimum');
  END IF;

  IF product_record.max_amount IS NOT NULL AND amount_param > product_record.max_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount exceeds maximum');
  END IF;

  IF (product_record.invested_amount + amount_param) > product_record.total_cap THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pool capacity exceeded');
  END IF;

  SELECT * INTO main_wallet_record
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = product_record.coin 
    AND wallet_type = 'main'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Main wallet not found');
  END IF;

  IF main_wallet_record.balance < amount_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  SELECT * INTO assets_wallet_record
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = product_record.coin 
    AND wallet_type = 'assets'
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (user_id_param, product_record.coin, 'assets', 0)
    RETURNING * INTO assets_wallet_record;
  END IF;

  UPDATE wallets
  SET balance = balance - amount_param,
      updated_at = now()
  WHERE id = main_wallet_record.id;

  UPDATE wallets
  SET locked_balance = locked_balance + amount_param,
      updated_at = now()
  WHERE id = assets_wallet_record.id;

  IF product_record.duration_days > 0 THEN
    end_date_calc := now() + (product_record.duration_days || ' days')::interval;
  ELSE
    end_date_calc := NULL;
  END IF;

  INSERT INTO user_stakes (
    user_id,
    product_id,
    amount,
    apr_locked,
    start_date,
    end_date,
    status,
    earned_rewards,
    last_reward_date
  ) VALUES (
    user_id_param,
    product_id_param,
    amount_param,
    product_record.apr,
    now(),
    end_date_calc,
    'active',
    0,
    now()
  ) RETURNING id INTO new_stake_id;

  UPDATE earn_products
  SET invested_amount = invested_amount + amount_param,
      updated_at = now()
  WHERE id = product_id_param;

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status
  ) VALUES (
    user_id_param,
    'stake',
    product_record.coin,
    amount_param,
    0,
    'completed'
  );

  RETURN jsonb_build_object(
    'success', true,
    'stake_id', new_stake_id,
    'message', 'Successfully staked ' || amount_param || ' ' || product_record.coin
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to unstake tokens (fixed version)
CREATE OR REPLACE FUNCTION unstake_tokens(stake_id_param uuid)
RETURNS jsonb AS $$
DECLARE
  stake_record RECORD;
  product_record RECORD;
  main_wallet_record RECORD;
  assets_wallet_record RECORD;
  pending_rewards numeric;
  total_return numeric;
  early_unstake boolean := false;
BEGIN
  SELECT us.*, ep.coin INTO stake_record
  FROM user_stakes us
  JOIN earn_products ep ON us.product_id = ep.id
  WHERE us.id = stake_id_param AND us.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stake not found or already redeemed');
  END IF;

  IF stake_record.end_date IS NOT NULL AND now() < stake_record.end_date THEN
    early_unstake := true;
  END IF;

  pending_rewards := calculate_stake_rewards(stake_id_param);
  total_return := stake_record.amount + pending_rewards;

  SELECT * INTO main_wallet_record
  FROM wallets
  WHERE user_id = stake_record.user_id 
    AND currency = stake_record.coin 
    AND wallet_type = 'main'
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (stake_record.user_id, stake_record.coin, 'main', 0)
    RETURNING * INTO main_wallet_record;
  END IF;

  SELECT * INTO assets_wallet_record
  FROM wallets
  WHERE user_id = stake_record.user_id 
    AND currency = stake_record.coin 
    AND wallet_type = 'assets'
  FOR UPDATE;

  UPDATE wallets
  SET balance = balance + total_return,
      updated_at = now()
  WHERE id = main_wallet_record.id;

  UPDATE wallets
  SET locked_balance = locked_balance - stake_record.amount,
      updated_at = now()
  WHERE id = assets_wallet_record.id;

  UPDATE user_stakes
  SET status = 'redeemed',
      earned_rewards = earned_rewards + pending_rewards,
      updated_at = now()
  WHERE id = stake_id_param;

  UPDATE earn_products
  SET invested_amount = GREATEST(invested_amount - stake_record.amount, 0),
      updated_at = now()
  WHERE id = stake_record.product_id;

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status
  ) VALUES (
    stake_record.user_id,
    'unstake',
    stake_record.coin,
    total_return,
    0,
    'completed'
  );

  IF pending_rewards > 0 THEN
    INSERT INTO stake_rewards (stake_id, amount, reward_date)
    VALUES (stake_id_param, pending_rewards, now());
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'principal', stake_record.amount,
    'rewards', pending_rewards,
    'total', total_return,
    'early_unstake', early_unstake,
    'message', 'Successfully unstaked with total return: ' || total_return || ' ' || stake_record.coin
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to claim rewards (fixed version)
CREATE OR REPLACE FUNCTION claim_stake_rewards(stake_id_param uuid)
RETURNS jsonb AS $$
DECLARE
  stake_record RECORD;
  main_wallet_record RECORD;
  pending_rewards numeric;
BEGIN
  SELECT us.*, ep.coin INTO stake_record
  FROM user_stakes us
  JOIN earn_products ep ON us.product_id = ep.id
  WHERE us.id = stake_id_param AND us.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stake not found or not active');
  END IF;

  pending_rewards := calculate_stake_rewards(stake_id_param);

  IF pending_rewards <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'No rewards to claim');
  END IF;

  SELECT * INTO main_wallet_record
  FROM wallets
  WHERE user_id = stake_record.user_id 
    AND currency = stake_record.coin 
    AND wallet_type = 'main'
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (stake_record.user_id, stake_record.coin, 'main', 0)
    RETURNING * INTO main_wallet_record;
  END IF;

  UPDATE wallets
  SET balance = balance + pending_rewards,
      updated_at = now()
  WHERE id = main_wallet_record.id;

  UPDATE user_stakes
  SET earned_rewards = earned_rewards + pending_rewards,
      last_reward_date = now(),
      updated_at = now()
  WHERE id = stake_id_param;

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status
  ) VALUES (
    stake_record.user_id,
    'reward',
    stake_record.coin,
    pending_rewards,
    0,
    'completed'
  );

  INSERT INTO stake_rewards (stake_id, amount, reward_date)
  VALUES (stake_id_param, pending_rewards, now());

  RETURN jsonb_build_object(
    'success', true,
    'rewards', pending_rewards,
    'message', 'Successfully claimed ' || pending_rewards || ' ' || stake_record.coin
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to transfer between wallets (fixed version)
CREATE OR REPLACE FUNCTION transfer_between_wallets(
  user_id_param uuid,
  currency_param text,
  amount_param numeric,
  from_wallet_type_param text,
  to_wallet_type_param text
)
RETURNS jsonb AS $$
DECLARE
  from_wallet_record RECORD;
  to_wallet_record RECORD;
BEGIN
  IF from_wallet_type_param = to_wallet_type_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to same wallet type');
  END IF;

  IF amount_param <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  IF from_wallet_type_param NOT IN ('main', 'assets', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF to_wallet_type_param NOT IN ('main', 'assets', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  SELECT * INTO from_wallet_record
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = currency_param 
    AND wallet_type = from_wallet_type_param
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
  END IF;

  IF from_wallet_record.balance < amount_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  SELECT * INTO to_wallet_record
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = currency_param 
    AND wallet_type = to_wallet_type_param
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (user_id_param, currency_param, to_wallet_type_param, 0)
    RETURNING * INTO to_wallet_record;
  END IF;

  UPDATE wallets
  SET balance = balance - amount_param,
      updated_at = now()
  WHERE id = from_wallet_record.id;

  UPDATE wallets
  SET balance = balance + amount_param,
      updated_at = now()
  WHERE id = to_wallet_record.id;

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status
  ) VALUES (
    user_id_param,
    'transfer',
    currency_param,
    amount_param,
    0,
    'completed'
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Successfully transferred ' || amount_param || ' ' || currency_param || ' from ' || from_wallet_type_param || ' to ' || to_wallet_type_param
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

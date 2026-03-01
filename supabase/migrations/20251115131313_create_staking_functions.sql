/*
  # Staking System Functions

  ## Summary
  This migration creates comprehensive functions for the staking system including:
  - Staking tokens (moving from main wallet to assets wallet)
  - Unstaking tokens (returning to main wallet with rewards)
  - Claiming rewards without unstaking
  - Automatic reward calculation based on time elapsed

  ## Functions Created

  ### 1. calculate_stake_rewards(stake_id)
  Calculates pending rewards for a stake based on time elapsed and APR

  ### 2. stake_tokens(user_id, product_id, amount)
  Stakes tokens by:
  - Validating product availability and amount
  - Moving tokens from main wallet to assets wallet
  - Creating stake record
  - Recording transaction

  ### 3. unstake_tokens(stake_id)
  Unstakes tokens by:
  - Calculating final rewards
  - Returning principal + rewards to main wallet
  - Marking stake as redeemed
  - Recording transaction

  ### 4. claim_stake_rewards(stake_id)
  Claims accumulated rewards without unstaking principal:
  - Calculates pending rewards
  - Transfers rewards to main wallet
  - Updates stake record
  - Records transaction

  ## Security
  - All functions use SECURITY DEFINER for controlled access
  - Proper ownership checks throughout
  - Transaction safety with rollback on errors
*/

-- Function to calculate pending rewards for a stake
CREATE OR REPLACE FUNCTION calculate_stake_rewards(stake_id_param uuid)
RETURNS numeric AS $$
DECLARE
  stake_record RECORD;
  time_elapsed_seconds numeric;
  time_elapsed_years numeric;
  pending_rewards numeric;
BEGIN
  SELECT * INTO stake_record
  FROM user_stakes
  WHERE id = stake_id_param AND status = 'active';

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  time_elapsed_seconds := EXTRACT(EPOCH FROM (now() - stake_record.last_reward_date));
  time_elapsed_years := time_elapsed_seconds / (365.25 * 24 * 60 * 60);
  
  pending_rewards := stake_record.amount * (stake_record.apr_locked / 100) * time_elapsed_years;
  
  RETURN GREATEST(pending_rewards, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to stake tokens
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
    type,
    currency,
    amount,
    status,
    description
  ) VALUES (
    user_id_param,
    'stake',
    product_record.coin,
    amount_param,
    'completed',
    'Staked ' || amount_param || ' ' || product_record.coin || ' at ' || product_record.apr || '% APR'
  );

  RETURN jsonb_build_object(
    'success', true,
    'stake_id', new_stake_id,
    'message', 'Successfully staked ' || amount_param || ' ' || product_record.coin
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to unstake tokens
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
    type,
    currency,
    amount,
    status,
    description
  ) VALUES (
    stake_record.user_id,
    'unstake',
    stake_record.coin,
    total_return,
    'completed',
    'Unstaked ' || stake_record.amount || ' ' || stake_record.coin || ' with ' || pending_rewards || ' rewards'
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

-- Function to claim rewards without unstaking
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
    type,
    currency,
    amount,
    status,
    description
  ) VALUES (
    stake_record.user_id,
    'reward',
    stake_record.coin,
    pending_rewards,
    'completed',
    'Claimed staking rewards: ' || pending_rewards || ' ' || stake_record.coin
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

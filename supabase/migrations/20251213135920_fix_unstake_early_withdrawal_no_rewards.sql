/*
  # Fix Unstake Function for Early Withdrawal

  1. Changes
    - For flexible stakes: Return principal + earned rewards
    - For fixed stakes withdrawn early (before end_date): Return only principal, no rewards
    - For fixed stakes at maturity: Return principal + earned rewards

  2. Logic
    - Check if stake has an end_date (fixed term)
    - If end_date exists and current time is before end_date, it's early withdrawal
    - Early withdrawal on fixed term = principal only, no rewards
*/

CREATE OR REPLACE FUNCTION unstake_tokens(stake_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  stake_record RECORD;
  product_record RECORD;
  main_wallet_record RECORD;
  assets_wallet_record RECORD;
  pending_rewards numeric;
  total_return numeric;
  early_unstake boolean := false;
  is_fixed_term boolean := false;
BEGIN
  SELECT us.*, ep.coin, ep.product_type, ep.duration_days INTO stake_record
  FROM user_stakes us
  JOIN earn_products ep ON us.product_id = ep.id
  WHERE us.id = stake_id_param AND us.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stake not found or already redeemed');
  END IF;

  is_fixed_term := stake_record.product_type = 'fixed';

  IF stake_record.end_date IS NOT NULL AND now() < stake_record.end_date THEN
    early_unstake := true;
  END IF;

  IF early_unstake AND is_fixed_term THEN
    pending_rewards := 0;
    total_return := stake_record.amount;
  ELSE
    pending_rewards := calculate_stake_rewards(stake_id_param);
    total_return := stake_record.amount + pending_rewards;
  END IF;

  SELECT * INTO main_wallet_record
  FROM wallets
  WHERE user_id = stake_record.user_id 
    AND currency = stake_record.coin 
    AND wallet_type = 'main'
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
    VALUES (stake_record.user_id, stake_record.coin, 'main', 0, 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;
    
    SELECT * INTO main_wallet_record
    FROM wallets
    WHERE user_id = stake_record.user_id 
      AND currency = stake_record.coin 
      AND wallet_type = 'main';
  END IF;

  SELECT * INTO assets_wallet_record
  FROM wallets
  WHERE user_id = stake_record.user_id 
    AND currency = stake_record.coin 
    AND wallet_type = 'assets'
  FOR UPDATE;

  UPDATE wallets
  SET balance = balance + total_return, updated_at = now()
  WHERE id = main_wallet_record.id;

  IF assets_wallet_record.id IS NOT NULL THEN
    UPDATE wallets
    SET locked_balance = GREATEST(locked_balance - stake_record.amount, 0), updated_at = now()
    WHERE id = assets_wallet_record.id;
  END IF;

  UPDATE user_stakes
  SET 
    status = 'redeemed', 
    earned_rewards = CASE WHEN early_unstake AND is_fixed_term THEN 0 ELSE earned_rewards + pending_rewards END,
    updated_at = now()
  WHERE id = stake_id_param;

  UPDATE earn_products
  SET invested_amount = GREATEST(invested_amount - stake_record.amount, 0), updated_at = now()
  WHERE id = stake_record.product_id;

  INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, confirmed_at)
  VALUES (stake_record.user_id, 'unstake', stake_record.coin, total_return, 0, 'completed', now());

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
    'is_fixed_term', is_fixed_term,
    'rewards_forfeited', early_unstake AND is_fixed_term,
    'message', CASE 
      WHEN early_unstake AND is_fixed_term THEN 
        'Early withdrawal on fixed term - principal returned without rewards: ' || stake_record.amount || ' ' || stake_record.coin
      ELSE 
        'Successfully unstaked with total return: ' || total_return || ' ' || stake_record.coin
    END
  );
END;
$$;

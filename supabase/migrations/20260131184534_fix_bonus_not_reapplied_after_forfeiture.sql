/*
  # Fix Bonus Not Re-applied After Forfeiture

  ## Problem
  When a user stops copy trading and forfeits their bonus, then restarts copying
  the same trader, the bonus was being re-applied. This is incorrect - once
  forfeited, the bonus should not be re-granted.

  ## Solution
  1. Check if user has previously forfeited a bonus for this trader
  2. If so, don't apply the bonus to the new relationship
  3. Clear bonus fields on relationships where bonus was already forfeited
*/

-- First, clear bonus fields on any active relationships where the bonus was already forfeited
UPDATE copy_relationships cr
SET 
  bonus_amount = 0,
  bonus_locked_until = NULL,
  updated_at = now()
FROM copy_trading_bonus_claims ctbc
WHERE ctbc.relationship_id = cr.id
  AND ctbc.forfeited = true
  AND cr.bonus_amount > 0;

-- Update the start_copy_trading function to check for previous forfeitures
CREATE OR REPLACE FUNCTION start_copy_trading(
  p_trader_id uuid,
  p_amount numeric,
  p_allocation_percentage numeric DEFAULT 100,
  p_is_mock boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_relationship_id uuid;
  v_existing_relationship RECORD;
  v_wallet RECORD;
  v_trader RECORD;
  v_bonus_amount numeric := 0;
  v_total_amount numeric;
  v_has_existing_bonus boolean := false;
  v_has_forfeited_bonus boolean := false;
  v_promo_bonus RECORD;
  v_min_allocation numeric := 500;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_trader FROM traders WHERE id = p_trader_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trader not found');
  END IF;

  -- Check if user has any promo bonus with minimum copy trading requirement
  SELECT * INTO v_promo_bonus
  FROM promo_code_redemptions pcr
  JOIN promo_codes pc ON pc.id = pcr.promo_code_id
  WHERE pcr.user_id = v_user_id
    AND pc.min_copy_trading_allocation IS NOT NULL
    AND pc.min_copy_trading_allocation > 0
  ORDER BY pcr.redeemed_at DESC
  LIMIT 1;

  IF FOUND AND v_promo_bonus.min_copy_trading_allocation IS NOT NULL THEN
    v_min_allocation := v_promo_bonus.min_copy_trading_allocation;
  END IF;

  IF p_amount < v_min_allocation THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', format('Minimum allocation is %s USDT', v_min_allocation)
    );
  END IF;

  -- Check for existing active relationship
  SELECT * INTO v_existing_relationship
  FROM copy_relationships
  WHERE follower_id = v_user_id
    AND trader_id = p_trader_id
    AND is_mock = p_is_mock
    AND is_active = true
    AND status = 'active';

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You are already copying this trader'
    );
  END IF;

  -- Check if user has EVER forfeited a bonus for this trader (prevents re-granting)
  SELECT EXISTS(
    SELECT 1 
    FROM copy_trading_bonus_claims ctbc
    JOIN copy_relationships cr ON cr.id = ctbc.relationship_id
    WHERE cr.follower_id = v_user_id
      AND cr.trader_id = p_trader_id
      AND cr.is_mock = p_is_mock
      AND ctbc.forfeited = true
  ) INTO v_has_forfeited_bonus;

  -- Check if user already has an active (non-forfeited) bonus for this trader
  SELECT EXISTS(
    SELECT 1 
    FROM copy_trading_bonus_claims ctbc
    JOIN copy_relationships cr ON cr.id = ctbc.relationship_id
    WHERE cr.follower_id = v_user_id
      AND cr.trader_id = p_trader_id
      AND cr.is_mock = p_is_mock
      AND ctbc.forfeited = false
  ) INTO v_has_existing_bonus;

  -- Only award bonus if: not mock, no forfeited bonus, no existing active bonus
  IF NOT p_is_mock AND NOT v_has_forfeited_bonus AND NOT v_has_existing_bonus THEN
    v_bonus_amount := 100;
  END IF;

  v_total_amount := p_amount + v_bonus_amount;

  IF p_is_mock THEN
    v_relationship_id := gen_random_uuid();
    
    INSERT INTO copy_relationships (
      id, follower_id, trader_id, is_mock, is_active, status,
      allocation_percentage, initial_balance, current_balance,
      cumulative_pnl, bonus_amount, bonus_locked_until, created_at, updated_at
    )
    VALUES (
      v_relationship_id, v_user_id, p_trader_id, true, true, 'active',
      p_allocation_percentage, v_total_amount, v_total_amount,
      0, 0, NULL, now(), now()
    );

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'is_mock', true,
      'initial_balance', v_total_amount,
      'message', 'Mock copy trading started'
    );
  END IF;

  -- Real copy trading - check wallet balance
  SELECT * INTO v_wallet
  FROM wallets
  WHERE user_id = v_user_id
    AND currency = 'USDT'
    AND wallet_type = 'main'
  FOR UPDATE;

  IF NOT FOUND OR COALESCE(v_wallet.balance, 0) < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance'
    );
  END IF;

  -- Deduct from main wallet
  UPDATE wallets
  SET balance = balance - p_amount, updated_at = now()
  WHERE user_id = v_user_id
    AND currency = 'USDT'
    AND wallet_type = 'main';

  -- Add to copy wallet
  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
  VALUES (v_user_id, 'USDT', 'copy', v_total_amount, v_total_amount, now(), now())
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET
    balance = wallets.balance + v_total_amount,
    locked_balance = wallets.locked_balance + v_total_amount,
    updated_at = now();

  -- Create relationship
  v_relationship_id := gen_random_uuid();
  
  INSERT INTO copy_relationships (
    id, follower_id, trader_id, is_mock, is_active, status,
    allocation_percentage, initial_balance, current_balance,
    cumulative_pnl, bonus_amount, bonus_locked_until, created_at, updated_at
  )
  VALUES (
    v_relationship_id, v_user_id, p_trader_id, false, true, 'active',
    p_allocation_percentage, v_total_amount, v_total_amount,
    0, v_bonus_amount, 
    CASE WHEN v_bonus_amount > 0 THEN now() + interval '30 days' ELSE NULL END,
    now(), now()
  );

  -- Create bonus claim record only if bonus was awarded
  IF v_bonus_amount > 0 THEN
    INSERT INTO copy_trading_bonus_claims (
      id, user_id, relationship_id, bonus_amount, 
      locked_until, claimed_at, forfeited, created_at, updated_at
    )
    VALUES (
      gen_random_uuid(), v_user_id, v_relationship_id, v_bonus_amount,
      now() + interval '30 days', now(), false, now(), now()
    );
  END IF;

  -- Log transaction
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details, confirmed_at)
  VALUES (
    v_user_id, 'transfer', 'USDT', p_amount, 'completed',
    jsonb_build_object(
      'type', 'copy_trading_allocation',
      'trader_id', p_trader_id,
      'trader_name', v_trader.name,
      'bonus_amount', v_bonus_amount,
      'bonus_forfeited_previously', v_has_forfeited_bonus
    ),
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'relationship_id', v_relationship_id,
    'is_mock', false,
    'amount_allocated', p_amount,
    'bonus_amount', v_bonus_amount,
    'initial_balance', v_total_amount,
    'bonus_previously_forfeited', v_has_forfeited_bonus,
    'message', CASE 
      WHEN v_has_forfeited_bonus THEN 'Copy trading started (bonus not applied - previously forfeited)'
      WHEN v_bonus_amount > 0 THEN 'Copy trading started with ' || v_bonus_amount || ' USDT bonus!'
      ELSE 'Copy trading started'
    END
  );
END;
$$;

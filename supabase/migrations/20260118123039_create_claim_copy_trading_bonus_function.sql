/*
  # Create Claim Copy Trading Bonus Function

  ## Overview
  Function to claim the one-time 100 USDT copy trading bonus.
  
  ## Requirements
  - User must have an active, real (non-mock) copy relationship
  - The relationship must have initial_balance >= 500 USDT
  - User must not have already claimed this bonus (one per lifetime)
  - Only applies to the FIRST eligible relationship
  
  ## What it does
  1. Verifies eligibility
  2. Adds 100 USDT to the copy wallet
  3. Updates the relationship's initial_balance to include bonus
  4. Sets bonus_amount, bonus_claimed_at, bonus_locked_until on relationship
  5. Records claim in copy_trading_bonus_claims table

  ## Returns
  - success: boolean
  - message: string
  - relationship_id: uuid (if successful)
  - new_balance: numeric (if successful)
*/

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
  -- Order by created_at to get the first one
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

  -- Create a notification
  INSERT INTO notifications (user_id, notification_type, title, message, read, data, created_at)
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

-- Helper function to check bonus eligibility and status
CREATE OR REPLACE FUNCTION get_copy_trading_bonus_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_existing_claim RECORD;
  v_eligible_relationship RECORD;
  v_active_bonus RECORD;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'already_claimed', false,
      'error', 'Not authenticated'
    );
  END IF;

  -- Check if user already claimed
  SELECT * INTO v_existing_claim
  FROM copy_trading_bonus_claims
  WHERE user_id = v_user_id;
  
  IF FOUND THEN
    -- Get the relationship with the bonus
    SELECT cr.*, t.name as trader_name
    INTO v_active_bonus
    FROM copy_relationships cr
    LEFT JOIN traders t ON t.id = cr.trader_id
    WHERE cr.id = v_existing_claim.relationship_id;

    RETURN jsonb_build_object(
      'eligible', false,
      'already_claimed', true,
      'claimed_at', v_existing_claim.claimed_at,
      'claim_amount', v_existing_claim.amount,
      'forfeited', v_existing_claim.forfeited,
      'forfeited_at', v_existing_claim.forfeited_at,
      'forfeited_amount', v_existing_claim.forfeited_amount,
      'relationship_id', v_existing_claim.relationship_id,
      'trader_name', v_active_bonus.trader_name,
      'bonus_locked_until', v_active_bonus.bonus_locked_until,
      'is_vested', v_active_bonus.bonus_locked_until IS NOT NULL AND v_active_bonus.bonus_locked_until <= now()
    );
  END IF;

  -- Check for eligible relationship
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
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'eligible', true,
      'already_claimed', false,
      'eligible_relationship_id', v_eligible_relationship.id,
      'eligible_trader_name', v_eligible_relationship.trader_name,
      'current_allocation', v_eligible_relationship.initial_balance
    );
  END IF;

  -- Not eligible and not claimed
  RETURN jsonb_build_object(
    'eligible', false,
    'already_claimed', false,
    'reason', 'No active copy trading relationship with 500+ USDT allocation found'
  );
END;
$$;
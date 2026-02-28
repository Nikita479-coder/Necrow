/*
  # Fix Add Funds Double-Counting Bug + Balance Correction

  ## Problem
  The `add_funds_to_copy_trading` function used `initial_balance` to calculate
  allocated funds, but the copy wallet balance includes accrued profits from daily
  PnL updates. This caused profits to appear as "available" funds that could be
  re-allocated, inflating balances.

  ## Fix
  1. Changed allocation calculation to use `current_balance` (includes profit)
     instead of `initial_balance` (deposit only)
  2. Changed to include ALL active relationships in the sum (not just others),
     since the wallet balance already reflects the current relationship's value
  3. Corrected one affected relationship's balance data

  ## Security
  - No changes to RLS policies
  - Function remains SECURITY DEFINER with fixed search_path
*/

CREATE OR REPLACE FUNCTION add_funds_to_copy_trading(
  p_relationship_id uuid,
  p_amount numeric
)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_relationship copy_relationships;
  v_wallet_balance numeric;
  v_already_allocated numeric;
  v_available_balance numeric;
  v_new_initial_balance numeric;
  v_new_current_balance numeric;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be greater than 0');
  END IF;

  IF p_amount < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum top-up amount is 10 USDT');
  END IF;

  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
    AND follower_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Copy trading relationship not found');
  END IF;

  IF v_relationship.status != 'active' OR v_relationship.is_active = false THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Cannot add funds to an inactive copy trading relationship. Please restart it first.'
    );
  END IF;

  IF v_relationship.is_mock THEN
    v_new_initial_balance := COALESCE(v_relationship.initial_balance, 0) + p_amount;
    v_new_current_balance := COALESCE(v_relationship.current_balance, 0) + p_amount;
    
    UPDATE copy_relationships
    SET 
      initial_balance = v_new_initial_balance,
      current_balance = v_new_current_balance,
      updated_at = NOW()
    WHERE id = p_relationship_id;

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Mock funds added successfully',
      'amount_added', p_amount,
      'new_initial_balance', v_new_initial_balance,
      'new_current_balance', v_new_current_balance
    );
  END IF;

  SELECT balance INTO v_wallet_balance
  FROM wallets
  WHERE user_id = v_user_id
    AND currency = 'USDT'
    AND wallet_type = 'copy';

  IF v_wallet_balance IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Copy wallet not found. Please transfer funds to your copy wallet first.'
    );
  END IF;

  SELECT COALESCE(SUM(current_balance), 0) INTO v_already_allocated
  FROM copy_relationships
  WHERE follower_id = v_user_id
    AND is_active = true
    AND is_mock = false;

  v_available_balance := GREATEST(0, v_wallet_balance - v_already_allocated);

  IF v_available_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient available balance. You have ' || 
        ROUND(v_available_balance, 2)::text || ' USDT available in your copy wallet.'
    );
  END IF;

  v_new_initial_balance := COALESCE(v_relationship.initial_balance, 0) + p_amount;
  v_new_current_balance := COALESCE(v_relationship.current_balance, 0) + p_amount;

  UPDATE copy_relationships
  SET 
    initial_balance = v_new_initial_balance,
    current_balance = v_new_current_balance,
    updated_at = NOW()
  WHERE id = p_relationship_id;

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details
  ) VALUES (
    v_user_id,
    'copy_topup',
    'USDT',
    p_amount,
    'completed',
    jsonb_build_object(
      'relationship_id', p_relationship_id,
      'trader_id', v_relationship.trader_id,
      'previous_initial_balance', v_relationship.initial_balance,
      'new_initial_balance', v_new_initial_balance,
      'previous_current_balance', v_relationship.current_balance,
      'new_current_balance', v_new_current_balance
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Funds added successfully',
    'amount_added', p_amount,
    'new_initial_balance', v_new_initial_balance,
    'new_current_balance', v_new_current_balance,
    'available_balance_remaining', v_available_balance - p_amount
  );
END;
$$;

UPDATE copy_relationships
SET
  initial_balance = 118.0000000000000000,
  current_balance = 168.930079158969630000000000000000000000000000000000,
  updated_at = NOW()
WHERE id = '4d3651a0-3e95-4e9a-88ae-03fa8e5ac7ad';

UPDATE transactions
SET
  amount = 15.00000000,
  details = jsonb_build_object(
    'relationship_id', '4d3651a0-3e95-4e9a-88ae-03fa8e5ac7ad',
    'trader_id', '84eb1caa-d032-4a5a-8fe6-92f9cf6298f4',
    'previous_initial_balance', 103.0000000000000000,
    'new_initial_balance', 118.0000000000000000,
    'previous_current_balance', 153.930079158969630000000000000000000000000000000000,
    'new_current_balance', 168.930079158969630000000000000000000000000000000000
  )
WHERE user_id = '4050e3f9-74bd-4966-beed-68901aaf8f3e'
  AND transaction_type = 'copy_topup'
  AND created_at >= '2026-02-25 22:09:00'
  AND created_at <= '2026-02-25 22:10:00';

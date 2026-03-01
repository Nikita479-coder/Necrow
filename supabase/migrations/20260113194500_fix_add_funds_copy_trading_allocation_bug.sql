/*
  # Fix Add Funds Copy Trading Allocation Bug

  ## Problem
  The previous implementation excluded the CURRENT relationship when calculating
  allocated funds, which allowed users to add infinite funds by re-allocating
  already allocated money.

  ## Fix
  Now includes ALL active relationships when calculating total allocated funds,
  so the available balance is correctly computed as:
  available = copy_wallet_balance - total_allocated_to_all_traders

  ## Security
  - Prevents over-allocation exploit
  - Maintains proper balance checks
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
  v_total_allocated numeric;
  v_available_balance numeric;
  v_new_initial_balance numeric;
  v_new_current_balance numeric;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Validate amount
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be greater than 0');
  END IF;

  IF p_amount < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum top-up amount is 10 USDT');
  END IF;

  -- Get the relationship and verify ownership
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
    AND follower_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Copy trading relationship not found');
  END IF;

  -- Check if relationship is active
  IF v_relationship.status != 'active' OR v_relationship.is_active = false THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Cannot add funds to an inactive copy trading relationship. Please restart it first.'
    );
  END IF;

  -- Mock trading doesn't need balance checks - just add funds
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

  -- For real trading, check copy wallet balance
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

  -- FIXED: Calculate total allocated across ALL active relationships (not excluding current one)
  -- This prevents the infinite allocation bug
  SELECT COALESCE(SUM(initial_balance), 0) INTO v_total_allocated
  FROM copy_relationships
  WHERE follower_id = v_user_id
    AND is_active = true
    AND is_mock = false;

  -- Calculate truly available balance (unallocated funds in copy wallet)
  v_available_balance := GREATEST(0, v_wallet_balance - v_total_allocated);

  IF v_available_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient available balance. You have ' || 
        ROUND(v_available_balance, 2)::text || ' USDT available in your copy wallet. ' ||
        '(Total: ' || ROUND(v_wallet_balance, 2)::text || 
        ' - Already allocated: ' || ROUND(v_total_allocated, 2)::text || ')'
    );
  END IF;

  -- Calculate new balances
  v_new_initial_balance := COALESCE(v_relationship.initial_balance, 0) + p_amount;
  v_new_current_balance := COALESCE(v_relationship.current_balance, 0) + p_amount;

  -- Update the copy relationship with new balances
  UPDATE copy_relationships
  SET 
    initial_balance = v_new_initial_balance,
    current_balance = v_new_current_balance,
    updated_at = NOW()
  WHERE id = p_relationship_id;

  -- Log the transaction for audit purposes
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

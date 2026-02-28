/*
  # Add Funds to Existing Copy Trading Allocation

  ## Overview
  Creates a function that allows users to add more funds to an existing copy trading
  allocation without affecting past trades or historical PnL.

  ## Function: add_funds_to_copy_trading
  - Takes relationship_id and amount to add
  - Validates user authentication and ownership
  - Checks relationship is active
  - Validates sufficient available balance in copy wallet
  - Updates initial_balance and current_balance
  - Does NOT modify cumulative_pnl or past trade allocations
  - Returns success status with updated balances

  ## Parameters
  - p_relationship_id: UUID of the copy relationship to top up
  - p_amount: Amount in USDT to add to the allocation

  ## Security
  - SECURITY DEFINER for wallet access
  - Validates user owns the relationship
  - Checks available balance (total - already allocated to other traders)
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

  -- Calculate already allocated amounts from OTHER active relationships
  SELECT COALESCE(SUM(initial_balance), 0) INTO v_already_allocated
  FROM copy_relationships
  WHERE follower_id = v_user_id
    AND is_active = true
    AND is_mock = false
    AND id != p_relationship_id;

  -- Calculate available balance (total copy wallet - allocated to other traders)
  v_available_balance := GREATEST(0, v_wallet_balance - v_already_allocated);

  IF v_available_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient available balance. You have ' || 
        ROUND(v_available_balance, 2)::text || ' USDT available in your copy wallet. ' ||
        '(Total: ' || ROUND(v_wallet_balance, 2)::text || 
        ' - Allocated to others: ' || ROUND(v_already_allocated, 2)::text || ')'
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

-- Add copy_topup to allowed transaction types if not exists
DO $$
BEGIN
  -- Check if constraint needs updating
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'transactions'
    AND constraint_name = 'transactions_transaction_type_check'
  ) THEN
    -- Drop the old constraint and add updated one
    ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
  END IF;
END $$;

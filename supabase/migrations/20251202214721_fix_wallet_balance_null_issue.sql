/*
  # Fix Wallet Balance NULL Issue
  
  ## Changes
  1. Ensure all wallet inserts explicitly set balance and other numeric fields
  2. Add COALESCE checks to prevent NULL balance updates
  3. Fix execute_accepted_trade to handle edge cases
*/

-- Fix execute_accepted_trade function
CREATE OR REPLACE FUNCTION execute_accepted_trade(
  p_trade_id uuid,
  p_follower_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade RECORD;
  v_response RECORD;
  v_relationship RECORD;
  v_wallet_type text;
  v_allocation_id uuid;
  v_trader_trade_id uuid;
  v_follower_balance numeric;
  v_allocated_amount numeric;
  v_effective_trader_id uuid;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id;

  IF v_trade IS NULL THEN
    RAISE EXCEPTION 'Trade not found';
  END IF;

  -- Get response details
  SELECT * INTO v_response
  FROM copy_trade_responses
  WHERE pending_trade_id = p_trade_id
  AND follower_id = p_follower_id
  AND response = 'accepted';

  IF v_response IS NULL THEN
    RAISE EXCEPTION 'No accepted response found';
  END IF;

  -- Get relationship
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = v_response.copy_relationship_id;

  -- Determine effective trader ID (could be admin trader or regular)
  v_effective_trader_id := COALESCE(v_trade.admin_trader_id, v_trade.trader_id);

  -- Check if trader_trades entry exists, if not create it
  SELECT id INTO v_trader_trade_id
  FROM trader_trades
  WHERE trader_id = v_effective_trader_id
  AND symbol = v_trade.pair
  AND entry_price = v_trade.entry_price
  AND status = 'open'
  AND ABS(EXTRACT(EPOCH FROM (opened_at - v_trade.created_at))) < 60;

  -- If no trader_trade exists, create one
  IF v_trader_trade_id IS NULL THEN
    INSERT INTO trader_trades (
      trader_id,
      symbol,
      side,
      entry_price,
      quantity,
      leverage,
      margin_used,
      status,
      opened_at
    ) VALUES (
      v_effective_trader_id,
      v_trade.pair,
      v_trade.side,
      v_trade.entry_price,
      v_trade.quantity,
      v_trade.leverage,
      v_trade.margin_used,
      'open',
      v_trade.created_at
    ) RETURNING id INTO v_trader_trade_id;
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'copy' END;

  -- Ensure wallet exists with proper defaults
  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, total_deposited, total_withdrawn)
  VALUES (p_follower_id, 'USDT', v_wallet_type, 0, 0, 0, 0)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET 
    balance = COALESCE(wallets.balance, 0),
    locked_balance = COALESCE(wallets.locked_balance, 0),
    total_deposited = COALESCE(wallets.total_deposited, 0),
    total_withdrawn = COALESCE(wallets.total_withdrawn, 0);

  -- Get follower's balance with NULL handling
  SELECT COALESCE(balance, 0) INTO v_follower_balance
  FROM wallets
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_follower_balance IS NULL THEN
    v_follower_balance := 0;
  END IF;

  -- Calculate allocated amount using margin percentage
  v_allocated_amount := (v_follower_balance * COALESCE(v_trade.margin_percentage, 0)) / 100.0;

  -- Validate sufficient balance
  IF v_follower_balance < v_allocated_amount THEN
    RAISE EXCEPTION 'Insufficient balance to accept trade';
  END IF;

  -- Deduct allocated amount from wallet with NULL safety
  UPDATE wallets
  SET 
    balance = GREATEST(0, COALESCE(balance, 0) - v_allocated_amount),
    updated_at = NOW()
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  -- Create allocation in copy_trade_allocations
  INSERT INTO copy_trade_allocations (
    trader_trade_id,
    follower_id,
    copy_relationship_id,
    allocated_amount,
    follower_leverage,
    entry_price,
    status,
    source_type
  ) VALUES (
    v_trader_trade_id,
    p_follower_id,
    v_relationship.id,
    v_allocated_amount,
    v_response.follower_leverage,
    v_trade.entry_price,
    'open',
    'pending_accepted'
  ) RETURNING id INTO v_allocation_id;

  -- Update copy relationship
  UPDATE copy_relationships
  SET 
    total_trades_copied = COALESCE(total_trades_copied, 0) + 1,
    current_balance = COALESCE(current_balance, '0')::numeric + v_allocated_amount
  WHERE id = v_relationship.id;

  -- Log transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status
  ) VALUES (
    p_follower_id,
    'copy_trade_allocation',
    'USDT',
    v_allocated_amount,
    'completed'
  );
END;
$$;

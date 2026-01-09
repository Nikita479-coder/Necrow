/*
  # Fix start_copy_trading to Use Available Balance

  ## Problem
  When a user copies trader A with $100 and then copies trader B with 100% allocation,
  the function was showing $200 for trader B because it used the TOTAL wallet balance
  instead of the AVAILABLE balance (total - already allocated).

  ## Solution
  Calculate available balance by subtracting the sum of initial_balance from all
  OTHER active copy relationships before calculating the allocation amount.

  ## Example
  - User has 200 USDT in copy wallet
  - User copies Trader A for 100 USDT (100% of 100 available)
  - Now available = 200 - 100 = 100 USDT
  - User copies Trader B with 100% -> should get 100 USDT, not 200 USDT

  ## Changes
  - Add calculation of already-allocated balance from other active relationships
  - Use available_balance instead of total wallet_balance for allocation calculation
*/

CREATE OR REPLACE FUNCTION start_copy_trading(
  p_trader_id uuid,
  p_allocation_percentage integer,
  p_leverage integer DEFAULT 1,
  p_stop_loss_percent numeric DEFAULT NULL,
  p_take_profit_percent numeric DEFAULT NULL,
  p_is_mock boolean DEFAULT false,
  p_require_approval boolean DEFAULT false
)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_follower_id uuid;
  v_existing_relationship copy_relationships;
  v_relationship_id uuid;
  v_trader_exists boolean;
  v_copy_wallet_id uuid;
  v_wallet_balance numeric;
  v_already_allocated numeric;
  v_available_balance numeric;
  v_initial_balance numeric;
BEGIN
  v_follower_id := auth.uid();
  
  IF v_follower_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_allocation_percentage < 1 OR p_allocation_percentage > 100 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Allocation percentage must be between 1 and 100'
    );
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Leverage must be between 1 and 125'
    );
  END IF;

  SELECT EXISTS(SELECT 1 FROM traders WHERE id = p_trader_id) INTO v_trader_exists;
  IF NOT v_trader_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trader not found');
  END IF;

  SELECT * INTO v_existing_relationship
  FROM copy_relationships
  WHERE follower_id = v_follower_id
    AND trader_id = p_trader_id
    AND is_mock = p_is_mock;

  IF FOUND AND v_existing_relationship.status = 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You are already copying this trader in ' || 
        CASE WHEN p_is_mock THEN 'mock' ELSE 'real' END || ' mode'
    );
  END IF;

  -- Calculate initial balance based on mode
  IF p_is_mock THEN
    -- Mock trading uses $10,000 demo balance
    v_initial_balance := 10000.0 * p_allocation_percentage / 100.0;
  ELSE
    -- For real trading, check copy wallet balance
    SELECT balance INTO v_wallet_balance
    FROM wallets
    WHERE user_id = v_follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';

    IF v_wallet_balance IS NULL THEN
      -- Create copy wallet if it doesn't exist
      INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
      VALUES (v_follower_id, 'USDT', 'copy', 0, 0)
      ON CONFLICT (user_id, currency, wallet_type) 
      DO UPDATE SET updated_at = NOW()
      RETURNING balance INTO v_wallet_balance;
    END IF;

    -- Calculate already allocated amounts from OTHER active relationships
    -- (exclude the current trader in case of restarting)
    SELECT COALESCE(SUM(initial_balance), 0) INTO v_already_allocated
    FROM copy_relationships
    WHERE follower_id = v_follower_id
      AND is_active = true
      AND is_mock = false
      AND trader_id != p_trader_id;

    -- Calculate available balance
    v_available_balance := GREATEST(0, v_wallet_balance - v_already_allocated);

    IF v_available_balance < 100 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Minimum available balance of 100 USDT required. You have ' || 
          ROUND(v_available_balance, 2)::text || ' USDT available (Total: ' || 
          ROUND(v_wallet_balance, 2)::text || ' - Allocated: ' || 
          ROUND(v_already_allocated, 2)::text || ')'
      );
    END IF;
    
    -- Use AVAILABLE balance for allocation, not total wallet balance
    v_initial_balance := v_available_balance * p_allocation_percentage / 100.0;
    
    -- Ensure minimum of 100 USDT
    IF v_initial_balance < 100 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Calculated allocation is ' || ROUND(v_initial_balance, 2)::text || 
          ' USDT but minimum is 100 USDT. Increase your allocation percentage.'
      );
    END IF;
  END IF;

  IF FOUND AND v_existing_relationship.status IN ('stopped', 'paused') THEN
    -- Update initial and current balance when restarting
    UPDATE copy_relationships
    SET 
      is_active = true,
      status = 'active',
      allocation_percentage = p_allocation_percentage,
      leverage = p_leverage,
      stop_loss_percent = p_stop_loss_percent,
      take_profit_percent = p_take_profit_percent,
      require_approval = p_require_approval,
      initial_balance = v_initial_balance,
      current_balance = v_initial_balance,
      cumulative_pnl = 0,
      total_pnl = 0,
      ended_at = NULL,
      updated_at = NOW()
    WHERE id = v_existing_relationship.id
    RETURNING id INTO v_relationship_id;

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'message', 'Copy trading restarted successfully',
      'initial_balance', v_initial_balance
    );
  END IF;

  -- Ensure copy wallet exists
  SELECT id INTO v_copy_wallet_id
  FROM wallets
  WHERE user_id = v_follower_id 
    AND wallet_type = 'copy'
    AND currency = 'USDT';

  IF v_copy_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
    VALUES (v_follower_id, 'USDT', 'copy', 0, 0)
    ON CONFLICT (user_id, currency, wallet_type) 
    DO UPDATE SET updated_at = NOW()
    RETURNING id INTO v_copy_wallet_id;
  END IF;

  INSERT INTO copy_relationships (
    follower_id,
    trader_id,
    is_active,
    allocation_percentage,
    leverage,
    stop_loss_percent,
    take_profit_percent,
    initial_balance,
    current_balance,
    total_pnl,
    is_mock,
    status,
    require_approval
  ) VALUES (
    v_follower_id,
    p_trader_id,
    true,
    p_allocation_percentage,
    p_leverage,
    p_stop_loss_percent,
    p_take_profit_percent,
    v_initial_balance,
    v_initial_balance,
    0,
    p_is_mock,
    'active',
    p_require_approval
  )
  RETURNING id INTO v_relationship_id;

  RETURN jsonb_build_object(
    'success', true,
    'relationship_id', v_relationship_id,
    'message', 'Copy trading started successfully',
    'initial_balance', v_initial_balance
  );
END;
$$;

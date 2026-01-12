/*
  # Fix Restart Copy Trading - Reset Cumulative PNL
  
  ## Problem
  When a user restarts copy trading after stopping, the `cumulative_pnl` from 
  the previous session carries over, making it appear they have profits when 
  they actually don't.
  
  ## Changes
  - Add `cumulative_pnl = 0` to the UPDATE statement when restarting copy trading
  - Also reset `total_trades_copied = 0` for a clean slate
  
  ## Example
  - User stops copy trading with +23.55 USDT cumulative PNL
  - User restarts with new balance
  - Old cumulative PNL should be reset to 0, not carried over
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

    IF v_wallet_balance < 100 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Minimum balance of 100 USDT required in copy wallet'
      );
    END IF;
    
    v_initial_balance := v_wallet_balance * p_allocation_percentage / 100.0;
  END IF;

  IF FOUND AND v_existing_relationship.status IN ('stopped', 'paused') THEN
    -- Reset all metrics when restarting for a clean slate
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
      total_pnl = 0,
      cumulative_pnl = 0,
      total_trades_copied = 0,
      ended_at = NULL,
      updated_at = NOW()
    WHERE id = v_existing_relationship.id
    RETURNING id INTO v_relationship_id;

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'message', 'Copy trading restarted successfully'
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
    cumulative_pnl,
    total_trades_copied,
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
    0,
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

/*
  # Fix start_copy_trading to Use Copy Wallet

  ## Overview
  Updates the `start_copy_trading` function to check the 'copy' wallet instead of 'spot' wallet.
  The system uses dedicated wallet types: main, copy, futures, and assets.

  ## Changes
  - Change wallet_type check from 'spot' to 'copy' for real trading
  - Ensure the function works with the actual wallet structure
*/

CREATE OR REPLACE FUNCTION start_copy_trading(
  p_trader_id uuid,
  p_allocation_percentage integer,
  p_leverage integer,
  p_stop_loss_percent numeric DEFAULT NULL,
  p_take_profit_percent numeric DEFAULT NULL,
  p_is_mock boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship_id uuid;
  v_wallet_balance numeric;
  v_existing_relationship RECORD;
BEGIN
  -- Validate inputs
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

  -- Check for existing relationship WITH SAME MODE
  SELECT * INTO v_existing_relationship
  FROM copy_relationships
  WHERE follower_id = auth.uid()
  AND trader_id = p_trader_id
  AND is_mock = p_is_mock;

  -- If active relationship exists in same mode, return error
  IF FOUND AND v_existing_relationship.status = 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You are already copying this trader in ' || 
        CASE WHEN p_is_mock THEN 'mock' ELSE 'real' END || ' mode'
    );
  END IF;

  -- For mock trading, no wallet check needed
  -- For real trading, check actual 'copy' wallet balance
  IF NOT p_is_mock THEN
    SELECT balance INTO v_wallet_balance
    FROM wallets
    WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = 'copy';

    IF v_wallet_balance IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Copy wallet not found. Please transfer funds to your copy trading wallet first.'
      );
    END IF;

    -- Check minimum balance for percentage allocation
    IF v_wallet_balance < 100 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Minimum balance of 100 USDT required in copy wallet'
      );
    END IF;
  END IF;

  -- If stopped relationship exists in same mode, reactivate it
  IF FOUND AND v_existing_relationship.status = 'stopped' THEN
    UPDATE copy_relationships
    SET 
      allocation_percentage = p_allocation_percentage,
      leverage = p_leverage,
      stop_loss_percent = p_stop_loss_percent,
      take_profit_percent = p_take_profit_percent,
      status = 'active',
      ended_at = NULL,
      updated_at = now()
    WHERE id = v_existing_relationship.id
    RETURNING id INTO v_relationship_id;

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'message', 'Successfully restarted ' || CASE WHEN p_is_mock THEN 'mock ' ELSE '' END || 'copy trading'
    );
  END IF;

  -- Create new copy trading relationship
  INSERT INTO copy_relationships (
    follower_id,
    trader_id,
    allocation_percentage,
    leverage,
    is_mock,
    stop_loss_percent,
    take_profit_percent,
    status
  ) VALUES (
    auth.uid(),
    p_trader_id,
    p_allocation_percentage,
    p_leverage,
    p_is_mock,
    p_stop_loss_percent,
    p_take_profit_percent,
    'active'
  )
  RETURNING id INTO v_relationship_id;

  RETURN jsonb_build_object(
    'success', true,
    'relationship_id', v_relationship_id,
    'message', 'Successfully started ' || CASE WHEN p_is_mock THEN 'mock ' ELSE '' END || 'copy trading'
  );
END;
$$;

-- Also update other functions that reference 'spot' wallet for copy trading
CREATE OR REPLACE FUNCTION mirror_trader_position(
  p_relationship_id uuid,
  p_trader_position_id uuid,
  p_symbol text,
  p_side text,
  p_entry_price numeric,
  p_leverage integer,
  p_is_mock boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship record;
  v_position_size numeric;
  v_margin numeric;
  v_liquidation_price numeric;
  v_position_id uuid;
  v_wallet_type text;
  v_available_balance numeric;
BEGIN
  -- Get relationship details
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
  AND follower_id = auth.uid()
  AND is_active = true;

  IF v_relationship IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Active copy trading relationship not found'
    );
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN p_is_mock THEN 'mock' ELSE 'copy' END;

  -- Get available balance
  SELECT balance INTO v_available_balance
  FROM wallets
  WHERE user_id = auth.uid()
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  -- Calculate margin based on percentage of available balance
  v_margin := (v_available_balance * v_relationship.allocation_percentage / 100.0) * 0.1;
  v_position_size := v_margin * p_leverage / p_entry_price;

  -- Calculate liquidation price
  IF p_side = 'long' THEN
    v_liquidation_price := p_entry_price * (1 - (1 / p_leverage::numeric) * 0.9);
  ELSE
    v_liquidation_price := p_entry_price * (1 + (1 / p_leverage::numeric) * 0.9);
  END IF;

  -- Check available balance
  IF v_available_balance < v_margin THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance to open position'
    );
  END IF;

  -- Create copy position
  INSERT INTO copy_positions (
    follower_id,
    trader_id,
    relationship_id,
    is_mock,
    symbol,
    side,
    size,
    entry_price,
    current_price,
    leverage,
    margin,
    liquidation_price,
    trader_position_id,
    stop_loss_price,
    take_profit_price
  ) VALUES (
    auth.uid(),
    v_relationship.trader_id,
    p_relationship_id,
    p_is_mock,
    p_symbol,
    p_side,
    v_position_size,
    p_entry_price,
    p_entry_price,
    p_leverage,
    v_margin,
    v_liquidation_price,
    p_trader_position_id,
    CASE
      WHEN v_relationship.stop_loss_percent IS NOT NULL AND p_side = 'long'
        THEN p_entry_price * (1 - v_relationship.stop_loss_percent / 100)
      WHEN v_relationship.stop_loss_percent IS NOT NULL AND p_side = 'short'
        THEN p_entry_price * (1 + v_relationship.stop_loss_percent / 100)
      ELSE NULL
    END,
    CASE
      WHEN v_relationship.take_profit_percent IS NOT NULL AND p_side = 'long'
        THEN p_entry_price * (1 + v_relationship.take_profit_percent / 100)
      WHEN v_relationship.take_profit_percent IS NOT NULL AND p_side = 'short'
        THEN p_entry_price * (1 - v_relationship.take_profit_percent / 100)
      ELSE NULL
    END
  )
  RETURNING id INTO v_position_id;

  -- Create mirror mapping
  INSERT INTO copy_trade_mirrors (
    follower_position_id,
    trader_position_id,
    mirror_ratio
  ) VALUES (
    v_position_id,
    p_trader_position_id,
    1.0
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', v_position_id,
    'message', 'Position mirrored successfully'
  );
END;
$$;

CREATE OR REPLACE FUNCTION open_copy_position(
  p_relationship_id uuid,
  p_symbol text,
  p_side text,
  p_entry_price numeric,
  p_leverage integer,
  p_is_mock boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_position_id uuid;
  v_margin numeric;
  v_size numeric;
  v_liquidation_price numeric;
  v_wallet_type text;
  v_available_balance numeric;
BEGIN
  -- Get relationship details
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
  AND follower_id = auth.uid()
  AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Active copy trading relationship not found'
    );
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN p_is_mock THEN 'mock' ELSE 'copy' END;

  -- Get available balance
  SELECT balance INTO v_available_balance
  FROM wallets
  WHERE user_id = auth.uid()
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_available_balance IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Wallet not found'
    );
  END IF;

  -- Calculate position size based on percentage of available balance
  v_margin := (v_available_balance * v_relationship.allocation_percentage / 100.0) * 0.1;
  v_size := v_margin * p_leverage / p_entry_price;

  -- Calculate liquidation price
  IF p_side = 'long' THEN
    v_liquidation_price := p_entry_price * (1 - (1 / p_leverage::numeric) * 0.9);
  ELSE
    v_liquidation_price := p_entry_price * (1 + (1 / p_leverage::numeric) * 0.9);
  END IF;

  -- Check available balance
  IF v_available_balance < v_margin THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance to open position'
    );
  END IF;

  -- Create position
  INSERT INTO copy_positions (
    follower_id,
    trader_id,
    relationship_id,
    is_mock,
    symbol,
    side,
    entry_price,
    current_price,
    size,
    leverage,
    margin,
    liquidation_price,
    stop_loss_price,
    take_profit_price
  ) VALUES (
    auth.uid(),
    v_relationship.trader_id,
    p_relationship_id,
    p_is_mock,
    p_symbol,
    p_side,
    p_entry_price,
    p_entry_price,
    v_size,
    p_leverage,
    v_margin,
    v_liquidation_price,
    CASE WHEN v_relationship.stop_loss_percent IS NOT NULL 
      THEN p_entry_price * (1 - v_relationship.stop_loss_percent / 100) 
      ELSE NULL END,
    CASE WHEN v_relationship.take_profit_percent IS NOT NULL 
      THEN p_entry_price * (1 + v_relationship.take_profit_percent / 100) 
      ELSE NULL END
  )
  RETURNING id INTO v_position_id;

  RETURN jsonb_build_object(
    'success', true,
    'position_id', v_position_id,
    'message', 'Successfully opened copy position'
  );
END;
$$;

-- Update create_follower_allocations to use 'copy' wallet
CREATE OR REPLACE FUNCTION create_follower_allocations(
  p_trader_trade_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader_trade RECORD;
  v_follower RECORD;
  v_allocated_amount numeric;
  v_follower_wallet_id uuid;
  v_follower_balance numeric;
BEGIN
  -- Get trader trade details
  SELECT * INTO v_trader_trade
  FROM trader_trades
  WHERE id = p_trader_trade_id;

  -- Loop through all active followers
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.allocation_percentage,
      cr.leverage as leverage_multiplier,
      cr.is_mock
    FROM copy_relationships cr
    WHERE cr.trader_id = v_trader_trade.trader_id
    AND cr.status = 'active'
  LOOP
    -- Get follower's wallet and balance
    IF v_follower.is_mock THEN
      SELECT id, balance INTO v_follower_wallet_id, v_follower_balance
      FROM wallets
      WHERE user_id = v_follower.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'mock';

      IF v_follower_wallet_id IS NULL THEN
        INSERT INTO wallets (user_id, currency, balance, wallet_type)
        VALUES (v_follower.follower_id, 'USDT', 10000, 'mock')
        RETURNING id, balance INTO v_follower_wallet_id, v_follower_balance;
      END IF;
    ELSE
      SELECT id, balance INTO v_follower_wallet_id, v_follower_balance
      FROM wallets
      WHERE user_id = v_follower.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';
    END IF;

    -- Calculate allocated amount based on follower's balance percentage
    v_allocated_amount := (v_follower_balance * v_follower.allocation_percentage) / 100.0;
    
    -- Apply same proportion as trader used
    v_allocated_amount := v_allocated_amount * (v_trader_trade.margin_used / 1000.0);

    -- Skip if allocated amount is too small
    IF v_allocated_amount < 1 THEN
      CONTINUE;
    END IF;

    -- Check if follower has sufficient balance
    IF v_follower_balance >= v_allocated_amount THEN
      -- Create allocation record
      INSERT INTO copy_trade_allocations (
        trader_trade_id,
        follower_id,
        copy_relationship_id,
        allocated_amount,
        follower_leverage,
        entry_price,
        status
      ) VALUES (
        p_trader_trade_id,
        v_follower.follower_id,
        v_follower.relationship_id,
        v_allocated_amount,
        v_trader_trade.leverage * v_follower.leverage_multiplier,
        v_trader_trade.entry_price,
        'open'
      );

      -- Deduct allocated amount from follower's wallet
      UPDATE wallets
      SET balance = balance - v_allocated_amount,
          updated_at = NOW()
      WHERE id = v_follower_wallet_id;
    END IF;
  END LOOP;
END;
$$;

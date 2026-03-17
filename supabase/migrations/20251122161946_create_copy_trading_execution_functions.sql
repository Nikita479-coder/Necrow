/*
  # Copy Trading Execution Functions

  1. Functions
    - `log_trader_position_open()` - Records when a trader opens a position
    - `log_trader_position_close()` - Records when a trader closes a position and updates followers
    - `create_follower_allocations()` - Creates allocations for all active followers
    - `update_follower_balances()` - Updates follower wallet balances based on P&L

  2. Features
    - Automatic logging of trader positions
    - Proportional allocation to followers based on copy amount
    - Real-time balance updates for followers
    - Handles both mock and real trading modes
*/

-- Function to log when a trader opens a position
CREATE OR REPLACE FUNCTION log_trader_position_open(
  p_trader_id uuid,
  p_position_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade_id uuid;
BEGIN
  -- Insert trader trade record
  INSERT INTO trader_trades (
    trader_id,
    position_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    status,
    opened_at
  ) VALUES (
    p_trader_id,
    p_position_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    'open',
    NOW()
  ) RETURNING id INTO v_trade_id;

  -- Create allocations for all active followers
  PERFORM create_follower_allocations(v_trade_id);

  RETURN v_trade_id;
END;
$$;

-- Function to create allocations for followers
CREATE OR REPLACE FUNCTION create_follower_allocations(p_trader_trade_id uuid)
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
      cr.copy_amount,
      cr.leverage_multiplier,
      cr.is_mock,
      cr.wallet_type
    FROM copy_relationships cr
    WHERE cr.trader_id = v_trader_trade.trader_id
    AND cr.status = 'active'
  LOOP
    -- Calculate allocated amount (proportional to copy amount)
    v_allocated_amount := v_follower.copy_amount * (v_trader_trade.margin_used / 1000.0);
    
    -- Skip if allocated amount is too small
    IF v_allocated_amount < 1 THEN
      CONTINUE;
    END IF;

    -- Get or create follower's wallet
    IF v_follower.is_mock THEN
      SELECT id INTO v_follower_wallet_id
      FROM wallets
      WHERE user_id = v_follower.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'mock';
      
      IF v_follower_wallet_id IS NULL THEN
        INSERT INTO wallets (user_id, currency, balance, wallet_type)
        VALUES (v_follower.follower_id, 'USDT', 10000, 'mock')
        RETURNING id INTO v_follower_wallet_id;
      END IF;
    ELSE
      SELECT id INTO v_follower_wallet_id
      FROM wallets
      WHERE user_id = v_follower.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'spot';
    END IF;

    -- Check if follower has sufficient balance
    IF EXISTS (
      SELECT 1 FROM wallets
      WHERE id = v_follower_wallet_id
      AND balance >= v_allocated_amount
    ) THEN
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

-- Function to log when a trader closes a position
CREATE OR REPLACE FUNCTION log_trader_position_close(
  p_trader_trade_id uuid,
  p_exit_price numeric,
  p_realized_pnl numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pnl_percentage numeric;
BEGIN
  -- Calculate P&L percentage
  SELECT 
    CASE 
      WHEN margin_used > 0 THEN (p_realized_pnl / margin_used) * 100
      ELSE 0
    END INTO v_pnl_percentage
  FROM trader_trades
  WHERE id = p_trader_trade_id;

  -- Update trader trade
  UPDATE trader_trades
  SET 
    exit_price = p_exit_price,
    realized_pnl = p_realized_pnl,
    pnl_percentage = v_pnl_percentage,
    status = 'closed',
    closed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trader_trade_id;

  -- Update all follower allocations and balances
  PERFORM update_follower_balances(p_trader_trade_id, v_pnl_percentage);
END;
$$;

-- Function to update follower balances based on P&L
CREATE OR REPLACE FUNCTION update_follower_balances(
  p_trader_trade_id uuid,
  p_pnl_percentage numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allocation RECORD;
  v_follower_pnl numeric;
  v_return_amount numeric;
  v_wallet_type text;
BEGIN
  -- Loop through all allocations for this trade
  FOR v_allocation IN
    SELECT 
      cta.*,
      cr.is_mock
    FROM copy_trade_allocations cta
    JOIN copy_relationships cr ON cr.id = cta.copy_relationship_id
    WHERE cta.trader_trade_id = p_trader_trade_id
    AND cta.status = 'open'
  LOOP
    -- Calculate follower's P&L based on percentage
    v_follower_pnl := v_allocation.allocated_amount * (p_pnl_percentage / 100.0);
    v_return_amount := v_allocation.allocated_amount + v_follower_pnl;

    -- Determine wallet type
    v_wallet_type := CASE WHEN v_allocation.is_mock THEN 'mock' ELSE 'spot' END;

    -- Update allocation record
    UPDATE copy_trade_allocations
    SET 
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      status = 'closed',
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    -- Return funds to follower's wallet
    UPDATE wallets
    SET 
      balance = balance + v_return_amount,
      updated_at = NOW()
    WHERE user_id = v_allocation.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    -- Record transaction
    INSERT INTO transactions (
      user_id,
      type,
      currency,
      amount,
      status,
      description
    ) VALUES (
      v_allocation.follower_id,
      'copy_trade_pnl',
      'USDT',
      v_follower_pnl,
      'completed',
      format('Copy trade P&L from trader trade %s: %s%%', p_trader_trade_id, ROUND(p_pnl_percentage, 2))
    );
  END LOOP;
END;
$$;

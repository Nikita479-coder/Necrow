/*
  # Create Mock Trading Functions

  ## Description
  Functions for placing and managing mock/paper trades.
  These mirror real trading functions but operate on mock tables.

  ## Functions
  1. place_mock_futures_order - Place a mock market order
  2. close_mock_position - Close a mock position
  3. get_mock_positions - Get all open mock positions
  4. stop_mock_trading - Stop mock trading and reset everything
*/

-- Place mock futures order (market order only for simplicity)
CREATE OR REPLACE FUNCTION place_mock_futures_order(
  p_pair text,
  p_side text,
  p_quantity numeric,
  p_leverage integer,
  p_current_price numeric,
  p_take_profit numeric DEFAULT NULL,
  p_stop_loss numeric DEFAULT NULL
)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_wallet mock_wallets;
  v_margin_required numeric;
  v_position_size numeric;
  v_liquidation_price numeric;
  v_position_id uuid;
  v_order_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Validate inputs
  IF p_side NOT IN ('long', 'short') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid side. Must be long or short');
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Leverage must be between 1 and 125');
  END IF;

  IF p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be positive');
  END IF;

  IF p_current_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid price');
  END IF;

  -- Get or create mock wallet
  SELECT * INTO v_wallet FROM mock_wallets WHERE user_id = v_user_id;
  IF NOT FOUND THEN
    INSERT INTO mock_wallets (user_id, balance, locked_balance)
    VALUES (v_user_id, 10000, 0)
    RETURNING * INTO v_wallet;
  END IF;

  -- Calculate margin required
  v_position_size := p_quantity * p_current_price;
  v_margin_required := v_position_size / p_leverage;

  -- Check sufficient balance
  IF v_wallet.balance < v_margin_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Required: $%.2f, Available: $%.2f', v_margin_required, v_wallet.balance)
    );
  END IF;

  -- Calculate liquidation price (simplified: 80% loss of margin)
  IF p_side = 'long' THEN
    v_liquidation_price := p_current_price * (1 - 0.8 / p_leverage);
  ELSE
    v_liquidation_price := p_current_price * (1 + 0.8 / p_leverage);
  END IF;

  -- Deduct margin from balance
  UPDATE mock_wallets
  SET 
    balance = balance - v_margin_required,
    locked_balance = locked_balance + v_margin_required,
    updated_at = now()
  WHERE user_id = v_user_id;

  -- Create order record
  INSERT INTO mock_futures_orders (
    user_id, pair, side, order_type, order_status,
    price, quantity, filled_quantity, leverage, margin_amount, filled_at
  ) VALUES (
    v_user_id, p_pair, p_side, 'market', 'filled',
    p_current_price, p_quantity, p_quantity, p_leverage, v_margin_required, now()
  )
  RETURNING order_id INTO v_order_id;

  -- Create position
  INSERT INTO mock_futures_positions (
    user_id, pair, side, quantity, entry_price, current_price,
    leverage, margin_allocated, liquidation_price, take_profit, stop_loss, status
  ) VALUES (
    v_user_id, p_pair, p_side, p_quantity, p_current_price, p_current_price,
    p_leverage, v_margin_required, v_liquidation_price, p_take_profit, p_stop_loss, 'open'
  )
  RETURNING position_id INTO v_position_id;

  RETURN jsonb_build_object(
    'success', true,
    'position_id', v_position_id,
    'order_id', v_order_id,
    'entry_price', p_current_price,
    'margin_used', v_margin_required,
    'position_size', v_position_size,
    'liquidation_price', v_liquidation_price,
    'message', 'Mock position opened successfully'
  );
END;
$$;

-- Close mock position
CREATE OR REPLACE FUNCTION close_mock_position(
  p_position_id uuid,
  p_close_price numeric
)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_position mock_futures_positions;
  v_pnl numeric;
  v_return_amount numeric;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get position
  SELECT * INTO v_position
  FROM mock_futures_positions
  WHERE position_id = p_position_id
    AND user_id = v_user_id
    AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  -- Calculate PnL
  IF v_position.side = 'long' THEN
    v_pnl := (p_close_price - v_position.entry_price) * v_position.quantity;
  ELSE
    v_pnl := (v_position.entry_price - p_close_price) * v_position.quantity;
  END IF;

  -- Calculate return amount (margin + pnl, minimum 0)
  v_return_amount := GREATEST(0, v_position.margin_allocated + v_pnl);

  -- Update wallet
  UPDATE mock_wallets
  SET 
    balance = balance + v_return_amount,
    locked_balance = locked_balance - v_position.margin_allocated,
    updated_at = now()
  WHERE user_id = v_user_id;

  -- Close position
  UPDATE mock_futures_positions
  SET 
    status = 'closed',
    close_price = p_close_price,
    realized_pnl = v_pnl,
    closed_at = now(),
    updated_at = now()
  WHERE position_id = p_position_id;

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'close_price', p_close_price,
    'pnl', v_pnl,
    'return_amount', v_return_amount,
    'message', CASE WHEN v_pnl >= 0 THEN 'Position closed with profit' ELSE 'Position closed with loss' END
  );
END;
$$;

-- Get mock trading summary
CREATE OR REPLACE FUNCTION get_mock_trading_summary()
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_wallet mock_wallets;
  v_open_positions integer;
  v_total_margin numeric;
  v_total_trades integer;
  v_winning_trades integer;
  v_total_pnl numeric;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get or create wallet
  SELECT * INTO v_wallet FROM mock_wallets WHERE user_id = v_user_id;
  IF NOT FOUND THEN
    INSERT INTO mock_wallets (user_id, balance, locked_balance)
    VALUES (v_user_id, 10000, 0)
    RETURNING * INTO v_wallet;
  END IF;

  -- Count open positions
  SELECT COUNT(*), COALESCE(SUM(margin_allocated), 0)
  INTO v_open_positions, v_total_margin
  FROM mock_futures_positions
  WHERE user_id = v_user_id AND status = 'open';

  -- Count total closed trades and winning trades
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE realized_pnl > 0),
    COALESCE(SUM(realized_pnl), 0)
  INTO v_total_trades, v_winning_trades, v_total_pnl
  FROM mock_futures_positions
  WHERE user_id = v_user_id AND status IN ('closed', 'liquidated');

  RETURN jsonb_build_object(
    'success', true,
    'wallet', jsonb_build_object(
      'balance', v_wallet.balance,
      'locked_balance', v_wallet.locked_balance,
      'total_equity', v_wallet.balance + v_wallet.locked_balance
    ),
    'positions', jsonb_build_object(
      'open_count', v_open_positions,
      'total_margin', v_total_margin
    ),
    'performance', jsonb_build_object(
      'total_trades', v_total_trades,
      'winning_trades', v_winning_trades,
      'win_rate', CASE WHEN v_total_trades > 0 THEN round((v_winning_trades::numeric / v_total_trades) * 100, 2) ELSE 0 END,
      'total_pnl', v_total_pnl,
      'roi', round(((v_wallet.balance + v_wallet.locked_balance - 10000) / 10000) * 100, 2)
    )
  );
END;
$$;

-- Stop mock trading (resets everything)
CREATE OR REPLACE FUNCTION stop_mock_trading()
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_closed_positions integer;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Count positions being closed
  SELECT COUNT(*) INTO v_closed_positions
  FROM mock_futures_positions
  WHERE user_id = v_user_id;

  -- Delete all mock positions
  DELETE FROM mock_futures_positions WHERE user_id = v_user_id;
  
  -- Delete all mock orders
  DELETE FROM mock_futures_orders WHERE user_id = v_user_id;
  
  -- Reset wallet to 10,000 USDT
  INSERT INTO mock_wallets (user_id, balance, locked_balance)
  VALUES (v_user_id, 10000, 0)
  ON CONFLICT (user_id) DO UPDATE SET
    balance = 10000,
    locked_balance = 0,
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Mock trading stopped and reset',
    'positions_closed', v_closed_positions,
    'new_balance', 10000
  );
END;
$$;

-- Update mock position TP/SL
CREATE OR REPLACE FUNCTION update_mock_position_tpsl(
  p_position_id uuid,
  p_take_profit numeric DEFAULT NULL,
  p_stop_loss numeric DEFAULT NULL
)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE mock_futures_positions
  SET 
    take_profit = p_take_profit,
    stop_loss = p_stop_loss,
    updated_at = now()
  WHERE position_id = p_position_id
    AND user_id = v_user_id
    AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'TP/SL updated successfully'
  );
END;
$$;

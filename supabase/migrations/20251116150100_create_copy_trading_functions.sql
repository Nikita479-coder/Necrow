/*
  # Copy Trading Functions

  ## Functions
  1. `start_copy_trading()` - Start copying a trader
  2. `stop_copy_trading()` - Stop copying and close positions
  3. `mirror_trader_position()` - Mirror a trader's new position
  4. `close_copy_position()` - Close a specific copy position
  5. `update_copy_position_prices()` - Update prices and PnL
  6. `calculate_daily_copy_stats()` - Calculate daily statistics
*/

-- Function to start copy trading relationship
CREATE OR REPLACE FUNCTION start_copy_trading(
  p_trader_id uuid,
  p_copy_amount numeric,
  p_leverage integer DEFAULT 1,
  p_is_mock boolean DEFAULT false,
  p_stop_loss_percent numeric DEFAULT NULL,
  p_take_profit_percent numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship_id uuid;
  v_wallet_balance numeric;
  v_wallet_type text;
BEGIN
  -- Validate inputs
  IF p_copy_amount < 100 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Minimum copy amount is 100 USDT'
    );
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Leverage must be between 1 and 125'
    );
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN p_is_mock THEN 'mock_copy' ELSE 'copy_trading' END;

  -- Check if user has sufficient balance
  SELECT balance INTO v_wallet_balance
  FROM wallets
  WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

  IF v_wallet_balance IS NULL THEN
    -- Create wallet if it doesn't exist
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (auth.uid(), 'USDT', v_wallet_type, CASE WHEN p_is_mock THEN 10000 ELSE 0 END)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

    SELECT balance INTO v_wallet_balance
    FROM wallets
    WHERE user_id = auth.uid()
      AND currency = 'USDT'
      AND wallet_type = v_wallet_type;
  END IF;

  IF v_wallet_balance < p_copy_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance in ' || v_wallet_type || ' wallet'
    );
  END IF;

  -- Check if relationship already exists
  SELECT id INTO v_relationship_id
  FROM copy_relationships
  WHERE follower_id = auth.uid()
    AND trader_id = p_trader_id
    AND is_active = true;

  IF v_relationship_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already copying this trader'
    );
  END IF;

  -- Create or reactivate relationship
  INSERT INTO copy_relationships (
    follower_id,
    trader_id,
    is_active,
    copy_amount,
    leverage,
    stop_loss_percent,
    take_profit_percent
  ) VALUES (
    auth.uid(),
    p_trader_id,
    true,
    p_copy_amount,
    p_leverage,
    p_stop_loss_percent,
    p_take_profit_percent
  )
  ON CONFLICT (follower_id, trader_id)
  DO UPDATE SET
    is_active = true,
    copy_amount = p_copy_amount,
    leverage = p_leverage,
    stop_loss_percent = p_stop_loss_percent,
    take_profit_percent = p_take_profit_percent,
    updated_at = now()
  RETURNING id INTO v_relationship_id;

  -- Deduct copy amount from wallet
  UPDATE wallets
  SET balance = balance - p_copy_amount,
      updated_at = now()
  WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

  -- Create initial daily stats entry
  INSERT INTO copy_trading_stats (
    relationship_id,
    follower_id,
    trader_id,
    is_mock,
    stat_date,
    starting_balance,
    ending_balance
  ) VALUES (
    v_relationship_id,
    auth.uid(),
    p_trader_id,
    p_is_mock,
    CURRENT_DATE,
    p_copy_amount,
    p_copy_amount
  )
  ON CONFLICT (relationship_id, stat_date) DO NOTHING;

  -- Update trader's follower count
  UPDATE traders
  SET followers_count = followers_count + 1,
      updated_at = now()
  WHERE id = p_trader_id;

  RETURN jsonb_build_object(
    'success', true,
    'relationship_id', v_relationship_id,
    'message', 'Copy trading started successfully'
  );
END;
$$;

-- Function to stop copy trading
CREATE OR REPLACE FUNCTION stop_copy_trading(
  p_relationship_id uuid,
  p_close_positions boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship record;
  v_position record;
  v_total_pnl numeric := 0;
  v_wallet_type text;
  v_final_balance numeric;
BEGIN
  -- Get relationship details
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = p_relationship_id
    AND follower_id = auth.uid();

  IF v_relationship IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Copy trading relationship not found'
    );
  END IF;

  -- Determine wallet type based on positions
  SELECT is_mock INTO v_wallet_type
  FROM copy_positions
  WHERE relationship_id = p_relationship_id
  LIMIT 1;

  v_wallet_type := CASE WHEN v_wallet_type THEN 'mock_copy' ELSE 'copy_trading' END;

  -- Close all open positions if requested
  IF p_close_positions THEN
    FOR v_position IN
      SELECT * FROM copy_positions
      WHERE relationship_id = p_relationship_id
        AND follower_id = auth.uid()
    LOOP
      -- Calculate final PnL
      v_total_pnl := v_total_pnl + v_position.unrealized_pnl;

      -- Move to history
      INSERT INTO copy_position_history (
        follower_id,
        trader_id,
        relationship_id,
        is_mock,
        symbol,
        side,
        size,
        entry_price,
        exit_price,
        leverage,
        margin,
        realized_pnl,
        opened_at,
        closed_at,
        close_reason
      ) VALUES (
        v_position.follower_id,
        v_position.trader_id,
        v_position.relationship_id,
        v_position.is_mock,
        v_position.symbol,
        v_position.side,
        v_position.size,
        v_position.entry_price,
        v_position.current_price,
        v_position.leverage,
        v_position.margin,
        v_position.unrealized_pnl,
        v_position.opened_at,
        now(),
        'manual'
      );

      -- Delete from active positions
      DELETE FROM copy_positions WHERE id = v_position.id;
    END LOOP;
  END IF;

  -- Calculate final balance
  v_final_balance := v_relationship.copy_amount + v_total_pnl;

  -- Return balance to wallet
  UPDATE wallets
  SET balance = balance + v_final_balance,
      updated_at = now()
  WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

  -- Deactivate relationship
  UPDATE copy_relationships
  SET is_active = false,
      updated_at = now()
  WHERE id = p_relationship_id;

  -- Update trader's follower count
  UPDATE traders
  SET followers_count = GREATEST(followers_count - 1, 0),
      updated_at = now()
  WHERE id = v_relationship.trader_id;

  RETURN jsonb_build_object(
    'success', true,
    'final_balance', v_final_balance,
    'total_pnl', v_total_pnl,
    'message', 'Copy trading stopped successfully'
  );
END;
$$;

-- Function to mirror a trader's position
CREATE OR REPLACE FUNCTION mirror_trader_position(
  p_relationship_id uuid,
  p_trader_position_id uuid,
  p_symbol text,
  p_side text,
  p_entry_price numeric,
  p_leverage integer,
  p_is_mock boolean DEFAULT false
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
  v_wallet_type := CASE WHEN p_is_mock THEN 'mock_copy' ELSE 'copy_trading' END;

  -- Calculate position size based on copy amount and leverage
  v_margin := v_relationship.copy_amount * 0.1;
  v_position_size := v_margin * p_leverage / p_entry_price;

  -- Calculate liquidation price
  IF p_side = 'long' THEN
    v_liquidation_price := p_entry_price * (1 - (1 / p_leverage::numeric) * 0.9);
  ELSE
    v_liquidation_price := p_entry_price * (1 + (1 / p_leverage::numeric) * 0.9);
  END IF;

  -- Check available balance
  SELECT balance INTO v_available_balance
  FROM wallets
  WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

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

-- Function to update copy position prices and PnL
CREATE OR REPLACE FUNCTION update_copy_position_prices(
  p_symbol text,
  p_current_price numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_pnl numeric;
BEGIN
  -- Update all positions for this symbol
  FOR v_position IN
    SELECT * FROM copy_positions WHERE symbol = p_symbol
  LOOP
    -- Calculate PnL
    IF v_position.side = 'long' THEN
      v_pnl := (p_current_price - v_position.entry_price) * v_position.size;
    ELSE
      v_pnl := (v_position.entry_price - p_current_price) * v_position.size;
    END IF;

    -- Update position
    UPDATE copy_positions
    SET
      current_price = p_current_price,
      unrealized_pnl = v_pnl,
      last_update = now()
    WHERE id = v_position.id;

    -- Check stop loss
    IF v_position.stop_loss_price IS NOT NULL THEN
      IF (v_position.side = 'long' AND p_current_price <= v_position.stop_loss_price) OR
         (v_position.side = 'short' AND p_current_price >= v_position.stop_loss_price) THEN
        PERFORM close_copy_position(v_position.id, 'stop_loss');
      END IF;
    END IF;

    -- Check take profit
    IF v_position.take_profit_price IS NOT NULL THEN
      IF (v_position.side = 'long' AND p_current_price >= v_position.take_profit_price) OR
         (v_position.side = 'short' AND p_current_price <= v_position.take_profit_price) THEN
        PERFORM close_copy_position(v_position.id, 'take_profit');
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- Function to close a copy position
CREATE OR REPLACE FUNCTION close_copy_position(
  p_position_id uuid,
  p_close_reason text DEFAULT 'manual'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_wallet_type text;
  v_return_amount numeric;
BEGIN
  -- Get position
  SELECT * INTO v_position
  FROM copy_positions
  WHERE id = p_position_id
    AND follower_id = auth.uid();

  IF v_position IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Position not found'
    );
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_position.is_mock THEN 'mock_copy' ELSE 'copy_trading' END;

  -- Calculate return amount (margin + PnL)
  v_return_amount := v_position.margin + v_position.unrealized_pnl;

  -- Move to history
  INSERT INTO copy_position_history (
    follower_id,
    trader_id,
    relationship_id,
    is_mock,
    symbol,
    side,
    size,
    entry_price,
    exit_price,
    leverage,
    margin,
    realized_pnl,
    opened_at,
    closed_at,
    close_reason
  ) VALUES (
    v_position.follower_id,
    v_position.trader_id,
    v_position.relationship_id,
    v_position.is_mock,
    v_position.symbol,
    v_position.side,
    v_position.size,
    v_position.entry_price,
    v_position.current_price,
    v_position.leverage,
    v_position.margin,
    v_position.unrealized_pnl,
    v_position.opened_at,
    now(),
    p_close_reason
  );

  -- Return funds to wallet
  UPDATE wallets
  SET balance = balance + v_return_amount,
      updated_at = now()
  WHERE user_id = auth.uid()
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

  -- Update daily stats
  UPDATE copy_trading_stats
  SET
    total_trades = total_trades + 1,
    winning_trades = winning_trades + CASE WHEN v_position.unrealized_pnl > 0 THEN 1 ELSE 0 END,
    losing_trades = losing_trades + CASE WHEN v_position.unrealized_pnl < 0 THEN 1 ELSE 0 END,
    daily_pnl = daily_pnl + v_position.unrealized_pnl
  WHERE relationship_id = v_position.relationship_id
    AND stat_date = CURRENT_DATE;

  -- Delete position
  DELETE FROM copy_positions WHERE id = p_position_id;

  RETURN jsonb_build_object(
    'success', true,
    'realized_pnl', v_position.unrealized_pnl,
    'message', 'Position closed successfully'
  );
END;
$$;

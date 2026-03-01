/*
  # Fix Execute Accepted Trade - Create Real Positions

  ## Overview
  When a follower accepts a pending trade, this creates:
  1. A trader_trades record (the trader's position)
  2. A copy_positions record (the follower's mirrored position)
  3. Deducts margin from follower's wallet
  4. Creates transaction log
  
  ## Changes
  - Creates actual positions that show up on trader profiles
  - Properly links trader and follower positions
  - Uses correct wallet types (copy/main)
  - Calculates liquidation prices
  
  ## Security
  - No security changes
*/

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
  v_trader_position_id uuid;
  v_copy_position_id uuid;
  v_liquidation_price numeric;
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

  -- Determine wallet type: copy for real, main for mock
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'main' ELSE 'copy' END;

  -- Ensure wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_follower_id, 'USDT', v_wallet_type, 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Deduct allocated amount from wallet
  UPDATE wallets
  SET 
    balance = balance - v_response.allocated_amount,
    updated_at = NOW()
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  -- Calculate liquidation price
  IF v_trade.side = 'long' THEN
    v_liquidation_price := v_trade.entry_price * (1 - (1.0 / v_response.follower_leverage));
  ELSE
    v_liquidation_price := v_trade.entry_price * (1 + (1.0 / v_response.follower_leverage));
  END IF;

  -- Create trader's position in trader_trades table
  INSERT INTO trader_trades (
    trader_id,
    symbol,
    side,
    entry_price,
    exit_price,
    quantity,
    leverage,
    pnl,
    pnl_percent,
    status,
    opened_at,
    closed_at,
    created_at
  ) VALUES (
    v_trade.trader_id,
    v_trade.pair,
    v_trade.side,
    v_trade.entry_price,
    NULL,
    v_trade.quantity,
    v_trade.leverage,
    0,
    0,
    'open',
    NOW(),
    NULL,
    NOW()
  ) RETURNING id INTO v_trader_position_id;

  -- Create follower's copy position
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
    unrealized_pnl,
    realized_pnl,
    stop_loss_price,
    take_profit_price,
    opened_at,
    last_update,
    trader_position_id,
    created_at
  ) VALUES (
    p_follower_id,
    v_trade.trader_id,
    v_relationship.id,
    v_relationship.is_mock,
    v_trade.pair,
    v_trade.side,
    v_trade.quantity,
    v_trade.entry_price,
    v_trade.entry_price,
    v_response.follower_leverage,
    v_response.allocated_amount,
    v_liquidation_price,
    0,
    0,
    NULL,
    NULL,
    NOW(),
    NOW(),
    v_trader_position_id,
    NOW()
  ) RETURNING id INTO v_copy_position_id;

  -- Log transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    description,
    metadata
  ) VALUES (
    p_follower_id,
    'copy_trade_open',
    'USDT',
    -v_response.allocated_amount,
    'completed',
    format('Opened copy position: %s %s at %s', v_trade.side, v_trade.pair, v_trade.entry_price),
    jsonb_build_object(
      'pending_trade_id', p_trade_id,
      'trader_position_id', v_trader_position_id,
      'copy_position_id', v_copy_position_id,
      'pair', v_trade.pair,
      'side', v_trade.side,
      'entry_price', v_trade.entry_price,
      'leverage', v_response.follower_leverage,
      'margin', v_response.allocated_amount
    )
  );

  -- Update copy relationship balance
  UPDATE copy_relationships
  SET 
    current_balance = current_balance - v_response.allocated_amount,
    updated_at = NOW()
  WHERE id = v_relationship.id;

END;
$$;

/*
  # Complete Affiliate Integration - All Fee Collection Points

  ## Overview
  Integrates affiliate commission distribution into ALL fee collection points:
  1. Position Opening (trading fee + spread)
  2. Position Closing (trading fee)
  3. Funding/Overnight Fees (every 8 hours)
  4. Liquidation Fees

  ## Changes
  - Updates place_market_order to distribute affiliate commissions
  - Updates close_position_market to distribute affiliate commissions
  - Updates apply_funding_payment to distribute affiliate commissions
  - Updates liquidation functions to distribute affiliate commissions
  - Creates a unified fee tracking trigger for any missed fees

  ## Security
  All functions maintain SECURITY DEFINER with restricted search_path
*/

-- Updated place_market_order with affiliate commission distribution
CREATE OR REPLACE FUNCTION place_market_order(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text DEFAULT 'cross',
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_price numeric;
  v_entry_price numeric;
  v_margin_required numeric;
  v_notional_value numeric;
  v_liquidation_price numeric;
  v_wallet_balance numeric;
  v_position_id uuid;
  v_max_leverage integer;
  v_mmr numeric := 0.005;
  v_trading_fee numeric;
  v_spread_cost numeric;
  v_total_cost numeric;
  v_total_fees numeric;
BEGIN
  SELECT price INTO v_current_price
  FROM market_prices WHERE pair = p_pair;

  IF v_current_price IS NULL THEN
    SELECT price INTO v_current_price
    FROM (VALUES 
      ('BTCUSDT', 96000::numeric),
      ('ETHUSDT', 3600::numeric),
      ('BNBUSDT', 680::numeric),
      ('SOLUSDT', 220::numeric),
      ('XRPUSDT', 2.30::numeric)
    ) AS prices(pair, price)
    WHERE pair = p_pair;
  END IF;

  IF v_current_price IS NULL THEN
    RAISE EXCEPTION 'Invalid trading pair: %', p_pair;
  END IF;

  v_entry_price := get_effective_entry_price(p_pair, v_current_price, p_side);
  v_notional_value := v_entry_price * p_quantity;
  v_margin_required := v_notional_value / p_leverage;
  v_trading_fee := calculate_trading_fee(p_user_id, v_notional_value, false);
  v_spread_cost := calculate_spread_cost(p_pair, v_current_price, p_quantity);
  v_total_cost := v_margin_required + v_trading_fee;
  v_total_fees := v_trading_fee + v_spread_cost;

  SELECT balance INTO v_wallet_balance
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'futures';

  IF v_wallet_balance IS NULL OR v_wallet_balance < v_total_cost THEN
    RAISE EXCEPTION 'Insufficient balance. Required: %, Available: %', v_total_cost, COALESCE(v_wallet_balance, 0);
  END IF;

  SELECT COALESCE(max_leverage, 125) INTO v_max_leverage
  FROM user_leverage_limits
  WHERE user_id = p_user_id;

  IF v_max_leverage IS NULL THEN
    v_max_leverage := 125;
  END IF;

  IF p_leverage > v_max_leverage THEN
    RAISE EXCEPTION 'Leverage % exceeds maximum allowed (%)', p_leverage, v_max_leverage;
  END IF;

  IF p_side = 'long' THEN
    IF p_margin_mode = 'isolated' THEN
      v_liquidation_price := v_entry_price * (1 - (1.0 / p_leverage) + v_mmr);
    ELSE
      v_liquidation_price := v_entry_price * (1 - (v_margin_required / v_notional_value) + v_mmr);
    END IF;
  ELSE
    IF p_margin_mode = 'isolated' THEN
      v_liquidation_price := v_entry_price * (1 + (1.0 / p_leverage) - v_mmr);
    ELSE
      v_liquidation_price := v_entry_price * (1 + (v_margin_required / v_notional_value) - v_mmr);
    END IF;
  END IF;

  UPDATE wallets
  SET 
    balance = balance - v_total_cost,
    updated_at = NOW()
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'futures';

  INSERT INTO futures_positions (
    user_id, pair, side, entry_price, mark_price, quantity, leverage, margin_mode,
    margin_allocated, liquidation_price, unrealized_pnl, realized_pnl, cumulative_fees,
    stop_loss, take_profit, status, maintenance_margin_rate, opened_at, last_price_update
  ) VALUES (
    p_user_id, p_pair, p_side, v_entry_price, v_entry_price, p_quantity, p_leverage, p_margin_mode,
    v_margin_required, v_liquidation_price, 0, 0, v_trading_fee,
    p_stop_loss, p_take_profit, 'open', v_mmr, NOW(), NOW()
  ) RETURNING position_id INTO v_position_id;

  PERFORM record_trading_fee(p_user_id, v_position_id, p_pair, v_notional_value, false);

  INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount)
  VALUES (p_user_id, v_position_id, 'spread', p_pair, v_notional_value, (v_spread_cost / v_notional_value), v_spread_cost);

  INSERT INTO transactions (user_id, transaction_type, amount, currency, status, metadata)
  VALUES (p_user_id, 'open_position', v_margin_required, 'USDT', 'completed',
    jsonb_build_object('pair', p_pair, 'side', p_side, 'quantity', p_quantity, 'entry_price', v_entry_price,
      'leverage', p_leverage, 'trading_fee', v_trading_fee, 'spread_cost', v_spread_cost, 'position_id', v_position_id));

  -- Distribute affiliate commissions for opening fees (trading fee + spread)
  PERFORM distribute_multi_tier_commissions(
    p_trader_id := p_user_id,
    p_trade_amount := v_notional_value,
    p_fee_amount := v_total_fees,
    p_trade_id := v_position_id
  );

  RETURN jsonb_build_object(
    'success', true, 'position_id', v_position_id, 'entry_price', v_entry_price,
    'margin_used', v_margin_required, 'trading_fee', v_trading_fee,
    'spread_cost', v_spread_cost, 'liquidation_price', v_liquidation_price
  );
END;
$$;

-- Updated close_position_market with affiliate commission distribution
CREATE OR REPLACE FUNCTION close_position_market(
  p_user_id uuid,
  p_position_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_exit_price numeric;
  v_pnl numeric;
  v_notional_value numeric;
  v_return_amount numeric;
  v_trading_fee numeric;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND user_id = p_user_id
    AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found or already closed';
  END IF;

  v_exit_price := get_effective_entry_price(
    v_position.pair, 
    v_position.mark_price,
    CASE WHEN v_position.side = 'long' THEN 'short' ELSE 'long' END
  );

  v_notional_value := v_exit_price * v_position.quantity;
  v_trading_fee := calculate_trading_fee(p_user_id, v_notional_value, false);

  IF v_position.side = 'long' THEN
    v_pnl := (v_exit_price - v_position.entry_price) * v_position.quantity;
  ELSE
    v_pnl := (v_position.entry_price - v_exit_price) * v_position.quantity;
  END IF;

  v_pnl := v_pnl - v_position.cumulative_fees - v_trading_fee;
  v_return_amount := v_position.margin_allocated + v_pnl;

  IF v_return_amount < 0 THEN
    v_return_amount := 0;
  END IF;

  UPDATE futures_positions
  SET mark_price = v_exit_price, realized_pnl = v_pnl, cumulative_fees = cumulative_fees + v_trading_fee,
      status = 'closed', closed_at = NOW(), last_price_update = NOW()
  WHERE position_id = p_position_id;

  UPDATE wallets
  SET balance = balance + v_return_amount, updated_at = NOW()
  WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'futures';

  PERFORM record_trading_fee(p_user_id, p_position_id, v_position.pair, v_notional_value, false);

  INSERT INTO transactions (user_id, transaction_type, amount, currency, status, metadata)
  VALUES (p_user_id, 'close_position', v_return_amount, 'USDT', 'completed',
    jsonb_build_object('pair', v_position.pair, 'side', v_position.side, 'entry_price', v_position.entry_price,
      'exit_price', v_exit_price, 'pnl', v_pnl, 'trading_fee', v_trading_fee, 'position_id', p_position_id));

  -- Distribute affiliate commissions for closing fee
  PERFORM distribute_multi_tier_commissions(
    p_trader_id := p_user_id,
    p_trade_amount := v_notional_value,
    p_fee_amount := v_trading_fee,
    p_trade_id := p_position_id
  );

  RETURN jsonb_build_object(
    'success', true, 'exit_price', v_exit_price, 'pnl', v_pnl,
    'return_amount', v_return_amount, 'trading_fee', v_trading_fee
  );
END;
$$;

-- Updated apply_funding_payment with affiliate commission distribution
CREATE OR REPLACE FUNCTION apply_funding_payment(p_pair text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_funding_rate numeric;
  v_mark_price numeric;
  v_index_price numeric;
  v_position_record RECORD;
  v_payment_amount numeric;
  v_notional_size numeric;
BEGIN
  SELECT mark_price INTO v_mark_price
  FROM futures_positions
  WHERE pair = p_pair AND status = 'open'
  ORDER BY last_price_update DESC
  LIMIT 1;

  IF v_mark_price IS NULL THEN
    RETURN;
  END IF;

  v_index_price := v_mark_price;
  v_funding_rate := calculate_funding_rate(p_pair, v_mark_price, v_index_price);

  FOR v_position_record IN
    SELECT * FROM futures_positions
    WHERE pair = p_pair AND status = 'open'
  LOOP
    v_notional_size := v_position_record.quantity * v_mark_price;

    IF v_position_record.side = 'long' THEN
      v_payment_amount := v_notional_size * v_funding_rate;
    ELSE
      v_payment_amount := -1 * v_notional_size * v_funding_rate;
    END IF;

    UPDATE futures_positions
    SET 
      unrealized_pnl = unrealized_pnl - v_payment_amount,
      overnight_fees_accrued = COALESCE(overnight_fees_accrued, 0) + ABS(v_payment_amount),
      cumulative_fees = cumulative_fees + ABS(v_payment_amount),
      last_price_update = now()
    WHERE position_id = v_position_record.position_id;

    INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount)
    VALUES (v_position_record.user_id, v_position_record.position_id, 'funding', p_pair,
      v_notional_size, ABS(v_funding_rate), ABS(v_payment_amount));

    -- Distribute affiliate commissions for funding fees
    IF ABS(v_payment_amount) > 0 THEN
      PERFORM distribute_multi_tier_commissions(
        p_trader_id := v_position_record.user_id,
        p_trade_amount := v_notional_size,
        p_fee_amount := ABS(v_payment_amount),
        p_trade_id := v_position_record.position_id
      );
    END IF;
  END LOOP;
END;
$$;

-- Updated liquidate_position with affiliate commission distribution
CREATE OR REPLACE FUNCTION liquidate_position(p_position_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_liquidation_fee numeric;
  v_notional_value numeric;
  v_insurance_fund_amount numeric;
  v_exchange_amount numeric;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  v_notional_value := v_position.mark_price * v_position.quantity;
  
  -- Liquidation fee is typically 0.5% of notional
  v_liquidation_fee := v_notional_value * 0.005;
  v_insurance_fund_amount := v_liquidation_fee * 0.5;
  v_exchange_amount := v_liquidation_fee * 0.5;

  -- Update position to liquidated status
  UPDATE futures_positions
  SET 
    status = 'liquidated',
    realized_pnl = -v_position.margin_allocated,
    cumulative_fees = cumulative_fees + v_liquidation_fee,
    closed_at = NOW(),
    last_price_update = NOW()
  WHERE position_id = p_position_id;

  -- Record liquidation fee
  INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount)
  VALUES (v_position.user_id, p_position_id, 'liquidation', v_position.pair, v_notional_value, 0.005, v_liquidation_fee);

  -- Record transaction
  INSERT INTO transactions (user_id, transaction_type, amount, currency, status, metadata)
  VALUES (v_position.user_id, 'liquidation', -v_position.margin_allocated, 'USDT', 'completed',
    jsonb_build_object('pair', v_position.pair, 'side', v_position.side, 'liquidation_price', v_position.mark_price,
      'liquidation_fee', v_liquidation_fee, 'position_id', p_position_id));

  -- Send notification
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (v_position.user_id, 'liquidation', 'Position Liquidated',
    'Your ' || v_position.pair || ' ' || UPPER(v_position.side) || ' position has been liquidated.',
    jsonb_build_object('position_id', p_position_id, 'pair', v_position.pair, 'margin_lost', v_position.margin_allocated));

  -- Distribute affiliate commissions for liquidation fee
  PERFORM distribute_multi_tier_commissions(
    p_trader_id := v_position.user_id,
    p_trade_amount := v_notional_value,
    p_fee_amount := v_liquidation_fee,
    p_trade_id := p_position_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'margin_lost', v_position.margin_allocated,
    'liquidation_fee', v_liquidation_fee
  );
END;
$$;

-- Create a trigger function to catch any fee collections and distribute affiliate commissions
CREATE OR REPLACE FUNCTION distribute_affiliate_on_fee_collection()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only distribute if fee amount is positive
  IF NEW.fee_amount > 0 THEN
    PERFORM distribute_multi_tier_commissions(
      p_trader_id := NEW.user_id,
      p_trade_amount := COALESCE(NEW.notional_size, NEW.fee_amount * 100),
      p_fee_amount := NEW.fee_amount,
      p_trade_id := NEW.position_id
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Note: We don't add the trigger by default since the functions already call distribute_multi_tier_commissions
-- This is available as a backup if needed:
-- DROP TRIGGER IF EXISTS trigger_affiliate_on_fee ON fee_collections;
-- CREATE TRIGGER trigger_affiliate_on_fee
--   AFTER INSERT ON fee_collections
--   FOR EACH ROW
--   EXECUTE FUNCTION distribute_affiliate_on_fee_collection();

-- Create function to retroactively distribute commissions for past fees
CREATE OR REPLACE FUNCTION process_missed_affiliate_commissions(p_since TIMESTAMPTZ DEFAULT NOW() - INTERVAL '24 hours')
RETURNS TABLE(processed_count INTEGER, total_distributed NUMERIC)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fee RECORD;
  v_count INTEGER := 0;
  v_total NUMERIC := 0;
BEGIN
  -- Find fee collections that don't have corresponding tier commissions
  FOR v_fee IN
    SELECT fc.*
    FROM fee_collections fc
    LEFT JOIN tier_commissions tc ON tc.trade_id = fc.position_id
    WHERE fc.created_at >= p_since
      AND fc.fee_amount > 0
      AND tc.id IS NULL
  LOOP
    PERFORM distribute_multi_tier_commissions(
      p_trader_id := v_fee.user_id,
      p_trade_amount := COALESCE(v_fee.notional_size, v_fee.fee_amount * 100),
      p_fee_amount := v_fee.fee_amount,
      p_trade_id := v_fee.position_id
    );
    
    v_count := v_count + 1;
    v_total := v_total + v_fee.fee_amount;
  END LOOP;

  processed_count := v_count;
  total_distributed := v_total;
  RETURN NEXT;
END;
$$;

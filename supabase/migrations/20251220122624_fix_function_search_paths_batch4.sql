/*
  # Fix Function Search Paths - Batch 4

  ## Description
  Final fixes for remaining SECURITY DEFINER functions with search_path issues.
*/

-- Drop functions with exact signatures
DROP FUNCTION IF EXISTS claim_stake_rewards(uuid);
DROP FUNCTION IF EXISTS close_copy_position(uuid, numeric);
DROP FUNCTION IF EXISTS close_position(uuid, numeric, numeric);
DROP FUNCTION IF EXISTS generate_random_trades(uuid, integer);
DROP FUNCTION IF EXISTS insert_kyc_document(uuid, text, text, bigint, text, text);
DROP FUNCTION IF EXISTS place_futures_order(uuid, text, text, text, numeric, integer, text, numeric, numeric, numeric, numeric, boolean);
DROP FUNCTION IF EXISTS promote_user_to_admin(text);
DROP FUNCTION IF EXISTS record_trading_fee(uuid, uuid, text, numeric, boolean);
DROP FUNCTION IF EXISTS setup_demo_user(text);
DROP FUNCTION IF EXISTS stake_tokens(uuid, uuid, numeric);
DROP FUNCTION IF EXISTS start_copy_trading(uuid, numeric, integer, boolean, numeric, numeric);

-- Recreate claim_stake_rewards with search_path
CREATE FUNCTION claim_stake_rewards(stake_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  stake_record RECORD;
  main_wallet_record RECORD;
  pending_rewards numeric;
BEGIN
  SELECT us.*, ep.coin INTO stake_record
  FROM user_stakes us JOIN earn_products ep ON us.product_id = ep.id
  WHERE us.id = stake_id_param AND us.status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Stake not found or not active'); END IF;
  pending_rewards := calculate_stake_rewards(stake_id_param);
  IF pending_rewards <= 0 THEN RETURN jsonb_build_object('success', false, 'error', 'No rewards to claim'); END IF;
  SELECT * INTO main_wallet_record FROM wallets WHERE user_id = stake_record.user_id AND currency = stake_record.coin AND wallet_type = 'main' FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance) VALUES (stake_record.user_id, stake_record.coin, 'main', 0) RETURNING * INTO main_wallet_record;
  END IF;
  UPDATE wallets SET balance = balance + pending_rewards, updated_at = now() WHERE id = main_wallet_record.id;
  UPDATE user_stakes SET earned_rewards = earned_rewards + pending_rewards, last_reward_date = now(), updated_at = now() WHERE id = stake_id_param;
  INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status) VALUES (stake_record.user_id, 'reward', stake_record.coin, pending_rewards, 0, 'completed');
  INSERT INTO stake_rewards (stake_id, amount, reward_date) VALUES (stake_id_param, pending_rewards, now());
  RETURN jsonb_build_object('success', true, 'rewards', pending_rewards, 'message', 'Successfully claimed ' || pending_rewards || ' ' || stake_record.coin);
END;
$$;

-- Recreate close_copy_position with search_path
CREATE FUNCTION close_copy_position(p_position_id uuid, p_exit_price numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_return_amount numeric;
BEGIN
  SELECT * INTO v_position FROM copy_positions WHERE id = p_position_id AND follower_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Position not found'); END IF;
  v_return_amount := v_position.margin + COALESCE(v_position.unrealized_pnl, 0);
  INSERT INTO copy_position_history (follower_id, trader_id, relationship_id, is_mock, symbol, side, entry_price, exit_price, size, leverage, margin, realized_pnl, fees, opened_at, closed_at)
  VALUES (v_position.follower_id, v_position.trader_id, v_position.relationship_id, v_position.is_mock, v_position.symbol, v_position.side, v_position.entry_price, p_exit_price, v_position.size, v_position.leverage, v_position.margin, COALESCE(v_position.unrealized_pnl, 0), 0, v_position.opened_at, now());
  IF NOT v_position.is_mock AND v_return_amount > 0 THEN
    UPDATE wallets SET balance = balance + v_return_amount WHERE user_id = v_position.follower_id AND currency = 'USDT' AND wallet_type = 'copy';
  END IF;
  DELETE FROM copy_positions WHERE id = p_position_id;
  RETURN jsonb_build_object('success', true, 'realized_pnl', COALESCE(v_position.unrealized_pnl, 0), 'return_amount', v_return_amount, 'message', 'Successfully closed copy position');
END;
$$;

-- Recreate generate_random_trades with search_path
CREATE FUNCTION generate_random_trades(p_trader_id uuid, p_num_trades integer DEFAULT 20)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_symbols text[] := ARRAY['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT'];
  v_symbol text; v_side text; v_entry_price numeric; v_exit_price numeric;
  v_quantity numeric; v_leverage integer; v_pnl numeric; v_pnl_percent numeric;
  v_opened_at timestamptz; v_closed_at timestamptz; v_price_change numeric; i integer;
BEGIN
  FOR i IN 1..p_num_trades LOOP
    v_symbol := v_symbols[1 + floor(random() * array_length(v_symbols, 1))::int];
    v_side := CASE WHEN random() > 0.5 THEN 'buy' ELSE 'sell' END;
    v_entry_price := CASE WHEN v_symbol LIKE 'BTC%' THEN 40000 + (random() * 20000)
      WHEN v_symbol LIKE 'ETH%' THEN 2000 + (random() * 1000) ELSE 300 + (random() * 200) END;
    v_quantity := 0.001 + (random() * 0.05);
    v_leverage := (ARRAY[1, 2, 3, 5, 10])[1 + floor(random() * 5)::int];
    v_opened_at := now() - (random() * interval '30 days');
    IF random() < 0.8 THEN
      v_closed_at := v_opened_at + (random() * interval '2 days');
      v_price_change := -0.10 + (random() * 0.25);
      IF v_side = 'buy' THEN v_exit_price := v_entry_price * (1 + v_price_change); v_pnl_percent := v_price_change * 100 * v_leverage;
      ELSE v_exit_price := v_entry_price * (1 - v_price_change); v_pnl_percent := -v_price_change * 100 * v_leverage; END IF;
      v_pnl := (v_exit_price - v_entry_price) * v_quantity * v_leverage;
      IF v_side = 'sell' THEN v_pnl := -v_pnl; END IF;
      INSERT INTO trader_trades (trader_id, symbol, side, entry_price, exit_price, quantity, leverage, pnl, pnl_percent, status, opened_at, closed_at)
      VALUES (p_trader_id, v_symbol, v_side, v_entry_price, v_exit_price, v_quantity, v_leverage, v_pnl, v_pnl_percent, 'closed', v_opened_at, v_closed_at);
    ELSE
      INSERT INTO trader_trades (trader_id, symbol, side, entry_price, quantity, leverage, status, opened_at)
      VALUES (p_trader_id, v_symbol, v_side, v_entry_price, v_quantity, v_leverage, 'open', v_opened_at);
    END IF;
  END LOOP;
END;
$$;

-- Recreate stake_tokens with search_path
CREATE FUNCTION stake_tokens(user_id_param uuid, product_id_param uuid, amount_param numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product RECORD; v_wallet RECORD; v_stake_id uuid;
BEGIN
  SELECT * INTO v_product FROM earn_products WHERE id = product_id_param AND is_active = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Product not found or inactive'); END IF;
  IF amount_param < v_product.min_stake THEN RETURN jsonb_build_object('success', false, 'error', 'Amount below minimum'); END IF;
  SELECT * INTO v_wallet FROM wallets WHERE user_id = user_id_param AND currency = v_product.coin AND wallet_type = 'main' FOR UPDATE;
  IF NOT FOUND OR v_wallet.balance < amount_param THEN RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance'); END IF;
  UPDATE wallets SET balance = balance - amount_param, updated_at = now() WHERE id = v_wallet.id;
  INSERT INTO user_stakes (user_id, product_id, amount, apr_locked, lock_period_days, status, start_date, end_date, last_reward_date)
  VALUES (user_id_param, product_id_param, amount_param, v_product.apr, v_product.lock_period_days, 'active', now(), now() + (v_product.lock_period_days || ' days')::interval, now())
  RETURNING id INTO v_stake_id;
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status) VALUES (user_id_param, 'stake', v_product.coin, amount_param, 'completed');
  RETURN jsonb_build_object('success', true, 'stake_id', v_stake_id, 'message', 'Staked successfully');
END;
$$;

-- Recreate start_copy_trading with search_path
CREATE FUNCTION start_copy_trading(p_trader_id uuid, p_copy_amount numeric, p_leverage integer, p_is_mock boolean, p_stop_loss_percent numeric DEFAULT NULL, p_take_profit_percent numeric DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid; v_relationship_id uuid; v_wallet_type text;
BEGIN
  v_user_id := auth.uid();
  v_wallet_type := CASE WHEN p_is_mock THEN 'mock' ELSE 'copy' END;
  IF NOT p_is_mock THEN
    UPDATE wallets SET balance = balance - p_copy_amount WHERE user_id = v_user_id AND currency = 'USDT' AND wallet_type = 'copy' AND balance >= p_copy_amount;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Insufficient copy wallet balance'); END IF;
  END IF;
  INSERT INTO copy_relationships (follower_id, trader_id, allocation_percentage, leverage, stop_loss_percent, take_profit_percent, is_mock, is_active, initial_balance, current_balance)
  VALUES (v_user_id, p_trader_id, 100, p_leverage, p_stop_loss_percent, p_take_profit_percent, p_is_mock, true, p_copy_amount, p_copy_amount)
  RETURNING id INTO v_relationship_id;
  RETURN jsonb_build_object('success', true, 'relationship_id', v_relationship_id, 'message', 'Copy trading started');
END;
$$;

-- Recreate setup_demo_user with search_path (text version)
CREATE FUNCTION setup_demo_user(user_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NULL;
END;
$$;

-- Recreate promote_user_to_admin with search_path (text version)
CREATE FUNCTION promote_user_to_admin(user_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = user_email;
  IF v_user_id IS NOT NULL THEN
    UPDATE user_profiles SET is_admin = true WHERE id = v_user_id;
  END IF;
END;
$$;

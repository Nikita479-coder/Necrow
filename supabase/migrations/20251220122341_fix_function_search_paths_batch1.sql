/*
  # Fix Function Search Paths - Batch 1

  ## Description
  Adds SET search_path = public to SECURITY DEFINER functions that were missing it.
  This prevents search_path manipulation attacks.
*/

-- Fix add_test_crypto_assets
CREATE OR REPLACE FUNCTION add_test_crypto_assets(user_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
  v_assets_added integer := 0;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = user_email;
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', format('User not found with email: %s', user_email));
  END IF;

  INSERT INTO wallets (user_id, currency, balance, locked_balance, wallet_type)
  VALUES
    (v_user_id, 'USDT', 50000, 0, 'main'),
    (v_user_id, 'BTC', 0.5, 0, 'main'),
    (v_user_id, 'ETH', 5, 0, 'main'),
    (v_user_id, 'BNB', 25, 0, 'main')
  ON CONFLICT (user_id, currency, wallet_type) DO UPDATE SET balance = wallets.balance + EXCLUDED.balance;
  v_assets_added := v_assets_added + 4;

  INSERT INTO wallets (user_id, currency, balance, locked_balance, wallet_type)
  VALUES
    (v_user_id, 'USDT', 75000, 0, 'assets'),
    (v_user_id, 'USDC', 30000, 0, 'assets'),
    (v_user_id, 'BTC', 1.25, 0, 'assets'),
    (v_user_id, 'ETH', 12, 0, 'assets'),
    (v_user_id, 'BNB', 80, 0, 'assets'),
    (v_user_id, 'SOL', 250, 0, 'assets'),
    (v_user_id, 'XRP', 15000, 0, 'assets'),
    (v_user_id, 'ADA', 10000, 0, 'assets'),
    (v_user_id, 'MATIC', 5000, 0, 'assets'),
    (v_user_id, 'LINK', 500, 0, 'assets'),
    (v_user_id, 'DOT', 800, 0, 'assets'),
    (v_user_id, 'AVAX', 300, 0, 'assets'),
    (v_user_id, 'ATOM', 1200, 0, 'assets'),
    (v_user_id, 'LTC', 100, 0, 'assets'),
    (v_user_id, 'TRX', 50000, 0, 'assets'),
    (v_user_id, 'DOGE', 100000, 0, 'assets'),
    (v_user_id, 'ALGO', 8000, 0, 'assets'),
    (v_user_id, 'VET', 75000, 0, 'assets')
  ON CONFLICT (user_id, currency, wallet_type) DO UPDATE SET balance = wallets.balance + EXCLUDED.balance;
  v_assets_added := v_assets_added + 18;

  INSERT INTO wallets (user_id, currency, balance, locked_balance, wallet_type)
  VALUES (v_user_id, 'USDT', 25000, 0, 'copy')
  ON CONFLICT (user_id, currency, wallet_type) DO UPDATE SET balance = wallets.balance + EXCLUDED.balance;
  v_assets_added := v_assets_added + 1;

  INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
  VALUES (v_user_id, 100000, 0)
  ON CONFLICT (user_id) DO UPDATE SET available_balance = futures_margin_wallets.available_balance + 100000;
  v_assets_added := v_assets_added + 1;

  RETURN jsonb_build_object('success', true, 'message', format('Added %s crypto assets to user %s', v_assets_added, user_email), 'user_id', v_user_id, 'assets_added', v_assets_added);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', format('Error adding assets: %s', SQLERRM));
END;
$$;

-- Fix auto_populate_new_user_data
CREATE OR REPLACE FUNCTION auto_populate_new_user_data()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    PERFORM setup_demo_user(NEW.id);
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to populate demo data for user %: %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$;

-- Fix auto_setup_new_user
CREATE OR REPLACE FUNCTION auto_setup_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NEW;
END;
$$;

-- Fix calculate_funding_rate
CREATE OR REPLACE FUNCTION calculate_funding_rate(p_pair text, p_mark_price numeric, p_index_price numeric)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_premium numeric;
  v_funding_rate numeric;
  v_base_rate numeric := 0.0001;
  v_max_rate numeric := 0.0005;
BEGIN
  v_premium := (p_mark_price - p_index_price) / NULLIF(p_index_price, 0);
  v_funding_rate := v_base_rate + v_premium;
  v_funding_rate := GREATEST(LEAST(v_funding_rate, v_max_rate), -v_max_rate);
  IF ABS(v_funding_rate) < 0.00005 THEN
    v_funding_rate := 0.0001;
  END IF;
  RETURN v_funding_rate;
END;
$$;

-- Fix calculate_spread_cost
CREATE OR REPLACE FUNCTION calculate_spread_cost(p_pair text, p_entry_price numeric, p_quantity numeric)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spread_markup numeric := 0;
  v_notional numeric;
  v_spread_cost numeric;
BEGIN
  SELECT COALESCE(spread_markup_percent, 0.0001) INTO v_spread_markup
  FROM spread_config WHERE pair = p_pair AND is_active = true;
  v_notional := p_entry_price * p_quantity;
  v_spread_cost := v_notional * v_spread_markup;
  RETURN v_spread_cost;
END;
$$;

-- Fix calculate_stake_rewards
CREATE OR REPLACE FUNCTION calculate_stake_rewards(stake_id_param uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  stake_record RECORD;
  time_elapsed_seconds numeric;
  time_elapsed_years numeric;
  pending_rewards numeric;
BEGIN
  SELECT * INTO stake_record FROM user_stakes WHERE id = stake_id_param AND status = 'active';
  IF NOT FOUND THEN RETURN 0; END IF;
  time_elapsed_seconds := EXTRACT(EPOCH FROM (now() - stake_record.last_reward_date));
  time_elapsed_years := time_elapsed_seconds / (365.25 * 24 * 60 * 60);
  pending_rewards := stake_record.amount * (stake_record.apr_locked / 100) * time_elapsed_years;
  RETURN GREATEST(pending_rewards, 0);
END;
$$;

-- Fix calculate_trading_fee
CREATE OR REPLACE FUNCTION calculate_trading_fee(p_user_id uuid, p_notional_size numeric, p_is_maker boolean)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fee_rate numeric;
  v_fee_amount numeric;
BEGIN
  IF p_is_maker THEN
    SELECT maker_fee INTO v_fee_rate FROM get_user_fee_rates(p_user_id);
  ELSE
    SELECT taker_fee INTO v_fee_rate FROM get_user_fee_rates(p_user_id);
  END IF;
  v_fee_amount := p_notional_size * v_fee_rate;
  RETURN v_fee_amount;
END;
$$;

-- Fix calculate_user_30d_volume
CREATE OR REPLACE FUNCTION calculate_user_30d_volume(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_volume numeric := 0;
  v_futures_volume numeric := 0;
  v_swap_volume numeric := 0;
BEGIN
  SELECT COALESCE(SUM(quantity * entry_price), 0) INTO v_futures_volume
  FROM futures_positions WHERE user_id = p_user_id AND opened_at >= NOW() - INTERVAL '30 days';

  SELECT COALESCE(SUM(ABS(amount)), 0) INTO v_swap_volume
  FROM transactions WHERE user_id = p_user_id AND created_at >= NOW() - INTERVAL '30 days' AND transaction_type = 'swap';

  v_total_volume := v_futures_volume + v_swap_volume;
  RETURN v_total_volume;
END;
$$;

-- Fix check_new_user_eligibility
CREATE OR REPLACE FUNCTION check_new_user_eligibility(p_user_id uuid, p_eligibility_hours integer)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_created_at timestamptz;
  hours_since_creation numeric;
BEGIN
  SELECT created_at INTO user_created_at FROM auth.users WHERE id = p_user_id;
  IF user_created_at IS NULL THEN RETURN false; END IF;
  hours_since_creation := EXTRACT(EPOCH FROM (now() - user_created_at)) / 3600;
  RETURN hours_since_creation <= p_eligibility_hours;
END;
$$;

-- Fix get_document_base64
CREATE OR REPLACE FUNCTION get_document_base64(doc_id uuid)
RETURNS TABLE(file_data_base64 text, mime_type text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY SELECT encode(file_data, 'base64') as file_data_base64, kyc_documents.mime_type FROM kyc_documents WHERE id = doc_id;
END;
$$;

-- Fix get_effective_entry_price
CREATE OR REPLACE FUNCTION get_effective_entry_price(p_pair text, p_market_price numeric, p_side text)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_spread_markup numeric := 0;
  v_effective_price numeric;
BEGIN
  SELECT COALESCE(spread_markup_percent, 0.0001) INTO v_spread_markup
  FROM spread_config WHERE pair = p_pair AND is_active = true;
  IF p_side = 'long' THEN
    v_effective_price := p_market_price * (1 + v_spread_markup);
  ELSE
    v_effective_price := p_market_price * (1 - v_spread_markup);
  END IF;
  RETURN v_effective_price;
END;
$$;

-- Fix get_user_30d_volume
CREATE OR REPLACE FUNCTION get_user_30d_volume(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_futures_volume numeric;
  v_swap_volume numeric;
  v_total_volume numeric;
BEGIN
  SELECT COALESCE(SUM(ABS(entry_price * quantity * leverage)), 0) INTO v_futures_volume
  FROM futures_positions WHERE user_id = p_user_id AND opened_at >= NOW() - INTERVAL '30 days';

  SELECT COALESCE(SUM(from_amount), 0) INTO v_swap_volume
  FROM swap_history WHERE user_id = p_user_id AND created_at >= NOW() - INTERVAL '30 days' AND status = 'completed';

  v_total_volume := v_futures_volume + v_swap_volume;
  RETURN v_total_volume;
END;
$$;

-- Fix get_user_fee_rates
CREATE OR REPLACE FUNCTION get_user_fee_rates(p_user_id uuid)
RETURNS TABLE(maker_fee numeric, taker_fee numeric, vip_level integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_vip_level integer := 1;
BEGIN
  SELECT COALESCE(rs.vip_level, 1) INTO v_vip_level FROM referral_stats rs WHERE rs.user_id = p_user_id;
  RETURN QUERY SELECT tft.maker_fee_rate, tft.taker_fee_rate, tft.vip_level FROM trading_fee_tiers tft WHERE tft.vip_level = v_vip_level;
END;
$$;

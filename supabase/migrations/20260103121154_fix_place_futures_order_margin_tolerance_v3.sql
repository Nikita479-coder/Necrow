/*
  # Fix Futures Order Margin Tolerance

  ## Problem
  When opening a trade with 100% of balance, small price fluctuations between
  UI calculation and order execution can cause "Insufficient margin" errors.

  ## Solution
  - Drop all existing function versions
  - Add 0.5% tolerance when checking margin requirements
  - If requested margin is within 1% of available balance, auto-adjust to use available balance
*/

-- Drop all existing versions with exact signatures
DROP FUNCTION IF EXISTS place_futures_order(uuid, text, text, text, integer, numeric, numeric, numeric, numeric, numeric, numeric);
DROP FUNCTION IF EXISTS place_futures_order(p_user_id uuid, p_pair text, p_side text, p_quantity numeric, p_leverage integer, p_margin_mode text, p_order_type text, p_price numeric, p_take_profit numeric, p_stop_loss numeric);
DROP FUNCTION IF EXISTS place_futures_order(p_user_id uuid, p_pair text, p_side text, p_order_type text, p_quantity numeric, p_leverage integer, p_margin_mode text, p_price numeric, p_stop_loss numeric, p_take_profit numeric, p_reduce_only boolean, p_market_price numeric);

CREATE OR REPLACE FUNCTION place_futures_order(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_order_type text,
  p_leverage integer,
  p_margin numeric,
  p_quantity numeric DEFAULT NULL,
  p_limit_price numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL,
  p_stop_loss numeric DEFAULT NULL,
  p_current_price numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_balance numeric;
  v_locked_bonus_balance numeric := 0;
  v_total_available numeric;
  v_position_margin numeric;
  v_current_price numeric;
  v_position_size numeric;
  v_fee_rate numeric;
  v_fee_amount numeric;
  v_liquidation_price numeric;
  v_new_position_id uuid;
  v_new_order_id uuid;
  v_max_leverage integer;
  v_pair_config record;
  v_fee_collection_id uuid;
  v_transaction_id uuid;
  v_margin_tolerance numeric := 0.005;
  v_auto_adjust_threshold numeric := 0.01;
  v_adjusted_margin numeric;
BEGIN
  SELECT tpc.max_leverage, tpc.min_order_size, tpc.tick_size
  INTO v_pair_config
  FROM trading_pairs_config tpc
  WHERE tpc.symbol = p_pair AND tpc.is_active = true;

  IF v_pair_config IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trading pair not available');
  END IF;

  IF p_leverage > v_pair_config.max_leverage THEN
    RETURN jsonb_build_object('success', false, 'error', 'Leverage exceeds maximum allowed for this pair');
  END IF;

  IF p_current_price IS NOT NULL AND p_current_price > 0 THEN
    v_current_price := p_current_price;
  ELSE
    SELECT mp.price INTO v_current_price
    FROM market_prices mp
    WHERE mp.symbol = p_pair;
  END IF;

  IF v_current_price IS NULL OR v_current_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Could not get current market price');
  END IF;

  SELECT COALESCE(fmw.available_balance, 0) INTO v_wallet_balance
  FROM futures_margin_wallets fmw
  WHERE fmw.user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_balance IS NULL THEN
    v_wallet_balance := 0;
  END IF;

  SELECT COALESCE(SUM(lb.current_balance), 0) INTO v_locked_bonus_balance
  FROM locked_bonuses lb
  WHERE lb.user_id = p_user_id 
    AND lb.status = 'active'
    AND lb.can_trade = true;

  v_total_available := v_wallet_balance + v_locked_bonus_balance;

  IF p_margin > v_total_available AND p_margin <= v_total_available * (1 + v_auto_adjust_threshold) THEN
    v_adjusted_margin := v_total_available;
  ELSIF p_margin > v_total_available * (1 + v_margin_tolerance) THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Insufficient margin available',
      'available', v_total_available,
      'requested', p_margin
    );
  ELSE
    v_adjusted_margin := p_margin;
  END IF;

  v_position_margin := v_adjusted_margin;
  v_position_size := v_position_margin * p_leverage;

  IF v_position_size < v_pair_config.min_order_size THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position size below minimum');
  END IF;

  SELECT COALESCE(fc.taker_fee_rate, 0.0006) INTO v_fee_rate
  FROM fee_configurations fc
  WHERE fc.fee_type = 'futures_open';

  v_fee_amount := v_position_margin * v_fee_rate;

  IF p_side = 'long' THEN
    v_liquidation_price := v_current_price * (1 - (0.9 / p_leverage));
  ELSE
    v_liquidation_price := v_current_price * (1 + (0.9 / p_leverage));
  END IF;

  IF p_order_type = 'market' THEN
    DECLARE
      v_locked_bonus_used numeric := 0;
      v_wallet_used numeric := 0;
      v_locked_bonus_record record;
      v_remaining_margin numeric := v_position_margin;
    BEGIN
      FOR v_locked_bonus_record IN 
        SELECT lb.id, lb.current_balance 
        FROM locked_bonuses lb
        WHERE lb.user_id = p_user_id 
          AND lb.status = 'active' 
          AND lb.can_trade = true
          AND lb.current_balance > 0
        ORDER BY lb.created_at ASC
      LOOP
        IF v_remaining_margin <= 0 THEN
          EXIT;
        END IF;

        IF v_locked_bonus_record.current_balance >= v_remaining_margin THEN
          UPDATE locked_bonuses
          SET current_balance = current_balance - v_remaining_margin,
              updated_at = now()
          WHERE id = v_locked_bonus_record.id;

          v_locked_bonus_used := v_locked_bonus_used + v_remaining_margin;
          v_remaining_margin := 0;
        ELSE
          UPDATE locked_bonuses
          SET current_balance = 0,
              updated_at = now()
          WHERE id = v_locked_bonus_record.id;

          v_locked_bonus_used := v_locked_bonus_used + v_locked_bonus_record.current_balance;
          v_remaining_margin := v_remaining_margin - v_locked_bonus_record.current_balance;
        END IF;
      END LOOP;

      v_wallet_used := v_remaining_margin;

      IF v_wallet_used > 0 THEN
        UPDATE futures_margin_wallets
        SET available_balance = available_balance - v_wallet_used,
            updated_at = now()
        WHERE user_id = p_user_id;
      END IF;

      INSERT INTO futures_positions (
        user_id, pair, side, leverage, margin, locked_bonus_margin,
        entry_price, quantity, liquidation_price, 
        take_profit, stop_loss, status, margin_type, opened_at
      ) VALUES (
        p_user_id, p_pair, p_side, p_leverage, v_position_margin, v_locked_bonus_used,
        v_current_price, v_position_size / v_current_price, v_liquidation_price,
        p_take_profit, p_stop_loss, 'open', 'cross', now()
      )
      RETURNING id INTO v_new_position_id;

      INSERT INTO transactions (
        user_id, transaction_type, currency, amount, fee, status, confirmed_at
      ) VALUES (
        p_user_id, 'futures_open', 'USDT', v_position_margin, v_fee_amount, 'completed', now()
      )
      RETURNING id INTO v_transaction_id;

      IF v_fee_amount > 0 THEN
        INSERT INTO fee_collections (
          user_id, fee_type, base_amount, fee_rate, fee_amount, 
          source_type, source_id, collected_at
        ) VALUES (
          p_user_id, 'futures_open', v_position_margin, v_fee_rate, v_fee_amount,
          'futures_position', v_new_position_id, now()
        )
        RETURNING id INTO v_fee_collection_id;

        PERFORM distribute_trading_commissions(
          p_user_id,
          v_fee_amount,
          'futures_open',
          v_transaction_id
        );
      END IF;

      UPDATE user_vip_tracking
      SET period_volume = period_volume + v_position_size,
          all_time_volume = all_time_volume + v_position_size,
          updated_at = now()
      WHERE user_id = p_user_id;

      IF NOT FOUND THEN
        INSERT INTO user_vip_tracking (user_id, period_volume, all_time_volume)
        VALUES (p_user_id, v_position_size, v_position_size);
      END IF;

      RETURN jsonb_build_object(
        'success', true,
        'position_id', v_new_position_id,
        'entry_price', v_current_price,
        'position_size', v_position_size,
        'margin', v_position_margin,
        'fee', v_fee_amount,
        'liquidation_price', v_liquidation_price,
        'locked_bonus_used', v_locked_bonus_used
      );
    END;
  ELSE
    INSERT INTO futures_orders (
      user_id, pair, side, order_type, leverage, margin, quantity,
      limit_price, take_profit, stop_loss, status, created_at
    ) VALUES (
      p_user_id, p_pair, p_side, p_order_type, p_leverage, v_position_margin, 
      v_position_size / v_current_price, p_limit_price, p_take_profit, p_stop_loss,
      'pending', now()
    )
    RETURNING id INTO v_new_order_id;

    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_new_order_id,
      'order_type', p_order_type,
      'limit_price', p_limit_price,
      'margin', v_position_margin
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION place_futures_order TO authenticated;
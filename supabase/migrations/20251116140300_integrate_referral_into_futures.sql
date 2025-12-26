/*
  # Integrate Referral System into Futures Trading

  ## Description
  Updates futures trading to include referral commission distribution.
  Trading volume is calculated as margin * leverage for VIP level progression.

  ## Changes
  - Add referral fee distribution when futures orders are executed
  - Volume counts as (margin_amount * leverage) for VIP calculations
  - Track only last 30 days of volume
  - Automatic commission and rebate distribution

  ## Impact
  - Referrers earn commissions on futures trading fees
  - Leverage multiplies the volume counted toward VIP levels
  - New users get fee rebates for their first 30 days
*/

-- Update distribute_trading_fees to handle leverage multiplier
CREATE OR REPLACE FUNCTION distribute_trading_fees(
  p_user_id uuid,
  p_transaction_id uuid,
  p_trade_amount numeric,
  p_fee_amount numeric,
  p_leverage integer DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id uuid;
  v_referee_signup_date timestamptz;
  v_referrer_stats record;
  v_commission_rate numeric;
  v_rebate_rate numeric;
  v_commission_amount numeric;
  v_rebate_amount numeric;
  v_new_volume numeric;
  v_new_vip_level integer;
  v_leveraged_volume numeric;
BEGIN
  -- Check if user was referred by someone
  SELECT referred_by, created_at INTO v_referrer_id, v_referee_signup_date
  FROM user_profiles
  WHERE id = p_user_id;

  -- If no referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  -- Get referrer stats (or create if doesn't exist)
  SELECT * INTO v_referrer_stats
  FROM referral_stats
  WHERE user_id = v_referrer_id;

  IF v_referrer_stats IS NULL THEN
    -- Initialize referrer stats
    INSERT INTO referral_stats (user_id, total_referrals)
    VALUES (v_referrer_id, 1)
    RETURNING * INTO v_referrer_stats;
  END IF;

  -- Get commission and rebate rates based on VIP level
  v_commission_rate := get_commission_rate(v_referrer_stats.vip_level);
  v_rebate_rate := get_rebate_rate(v_referrer_stats.vip_level);

  -- Calculate commission amount (percentage of trading fee)
  v_commission_amount := (p_fee_amount * v_commission_rate) / 100;

  -- Calculate leveraged volume (margin * leverage)
  v_leveraged_volume := p_trade_amount * p_leverage;

  -- Record the commission
  INSERT INTO referral_commissions (
    referrer_id,
    referee_id,
    transaction_id,
    trade_amount,
    fee_amount,
    commission_rate,
    commission_amount,
    vip_level
  ) VALUES (
    v_referrer_id,
    p_user_id,
    p_transaction_id,
    v_leveraged_volume,
    p_fee_amount,
    v_commission_rate,
    v_commission_amount,
    v_referrer_stats.vip_level
  );

  -- Update referrer's earnings and volume (with leverage multiplier)
  v_new_volume := v_referrer_stats.total_volume_30d + v_leveraged_volume;
  v_new_vip_level := calculate_vip_level(v_new_volume);

  UPDATE referral_stats
  SET
    total_earnings = total_earnings + v_commission_amount,
    total_volume_30d = v_new_volume,
    total_volume_all_time = total_volume_all_time + v_leveraged_volume,
    this_month_earnings = this_month_earnings + v_commission_amount,
    vip_level = v_new_vip_level,
    updated_at = now()
  WHERE user_id = v_referrer_id;

  -- Add commission to referrer's wallet
  UPDATE wallets
  SET balance = balance + v_commission_amount,
      updated_at = now()
  WHERE user_id = v_referrer_id
    AND currency = 'USDT'
    AND wallet_type = 'spot';

  -- Record transaction for commission
  INSERT INTO transactions (
    user_id,
    type,
    currency,
    amount,
    status,
    created_at
  ) VALUES (
    v_referrer_id,
    'referral_commission',
    'USDT',
    v_commission_amount,
    'completed',
    now()
  );

  -- Handle rebate for referee (if within 30 days of signup)
  IF v_referee_signup_date + INTERVAL '30 days' > now() THEN
    v_rebate_amount := (p_fee_amount * v_rebate_rate) / 100;

    -- Record the rebate
    INSERT INTO referral_rebates (
      user_id,
      transaction_id,
      original_fee,
      rebate_rate,
      rebate_amount,
      expires_at
    ) VALUES (
      p_user_id,
      p_transaction_id,
      p_fee_amount,
      v_rebate_rate,
      v_rebate_amount,
      v_referee_signup_date + INTERVAL '30 days'
    );

    -- Add rebate to referee's wallet
    UPDATE wallets
    SET balance = balance + v_rebate_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND currency = 'USDT'
      AND wallet_type = 'spot';

    -- Record transaction for rebate
    INSERT INTO transactions (
      user_id,
      type,
      currency,
      amount,
      status,
      created_at
    ) VALUES (
      p_user_id,
      'fee_rebate',
      'USDT',
      v_rebate_amount,
      'completed',
      now()
    );
  END IF;

END;
$$;

-- Update execute_market_order to include referral fee distribution
CREATE OR REPLACE FUNCTION execute_market_order(p_order_id uuid)
RETURNS boolean AS $$
DECLARE
  v_order record;
  v_mark_price numeric;
  v_fee numeric;
  v_position_id uuid;
  v_transaction_id uuid;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM futures_orders
  WHERE order_id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR v_order.order_status != 'pending' THEN
    RETURN false;
  END IF;

  -- Get current mark price
  SELECT mark_price INTO v_mark_price
  FROM market_prices
  WHERE pair = v_order.pair;

  IF v_mark_price IS NULL THEN
    v_mark_price := COALESCE(v_order.price, 50000);
  END IF;

  -- Calculate taker fee
  v_fee := calculate_trading_fee(v_order.pair, v_order.quantity, v_mark_price, false);

  -- Update order as filled
  UPDATE futures_orders
  SET order_status = 'filled',
      filled_quantity = quantity,
      remaining_quantity = 0,
      average_fill_price = v_mark_price,
      maker_or_taker = 'taker',
      fee_paid = v_fee,
      filled_at = now(),
      updated_at = now()
  WHERE order_id = p_order_id;

  -- Create transaction record for referral tracking
  INSERT INTO transactions (
    user_id,
    type,
    currency,
    amount,
    status,
    fee,
    created_at
  ) VALUES (
    v_order.user_id,
    'futures_trade',
    'USDT',
    v_order.margin_amount,
    'completed',
    v_fee,
    now()
  ) RETURNING id INTO v_transaction_id;

  -- Distribute referral fees with leverage multiplier
  PERFORM distribute_trading_fees(
    v_order.user_id,
    v_transaction_id,
    v_order.margin_amount,
    v_fee,
    v_order.leverage
  );

  -- Create or update position
  v_position_id := create_or_update_position(
    v_order.user_id,
    v_order.pair,
    v_order.side,
    v_mark_price,
    v_order.quantity,
    v_order.leverage,
    v_order.margin_mode,
    v_order.margin_amount - v_fee,
    v_order.stop_loss,
    v_order.take_profit
  );

  RETURN v_position_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Update execute_instant_swap to use new function signature
CREATE OR REPLACE FUNCTION execute_instant_swap(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric
)
RETURNS jsonb AS $$
DECLARE
  v_from_wallet record;
  v_to_wallet record;
  v_exchange_rate numeric;
  v_to_amount numeric;
  v_order_id uuid;
  v_fee_amount numeric;
  v_transaction_id uuid;
BEGIN
  -- Validate inputs
  IF p_from_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  IF p_from_currency = p_to_currency THEN
    RAISE EXCEPTION 'Cannot swap same currency';
  END IF;

  -- Get current exchange rate
  v_exchange_rate := get_swap_rate(p_from_currency, p_to_currency);

  IF v_exchange_rate <= 0 THEN
    RAISE EXCEPTION 'Exchange rate not available for % to %', p_from_currency, p_to_currency;
  END IF;

  -- Calculate to_amount and fee (0.1% trading fee)
  v_to_amount := p_from_amount * v_exchange_rate;
  v_fee_amount := v_to_amount * 0.001;
  v_to_amount := v_to_amount - v_fee_amount;

  -- Ensure from wallet exists
  INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
  VALUES (p_user_id, p_from_currency, 0, 0, 0, 0)
  ON CONFLICT (user_id, currency) DO NOTHING;

  -- Get from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency
  FOR UPDATE;

  -- Check sufficient balance
  IF (v_from_wallet.balance - v_from_wallet.locked_balance) < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient available balance';
  END IF;

  -- Ensure to wallet exists
  INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
  VALUES (p_user_id, p_to_currency, 0, 0, 0, 0)
  ON CONFLICT (user_id, currency) DO NOTHING;

  -- Update wallets
  UPDATE wallets
  SET balance = balance - p_from_amount, updated_at = now()
  WHERE user_id = p_user_id AND currency = p_from_currency;

  UPDATE wallets
  SET balance = balance + v_to_amount, updated_at = now()
  WHERE user_id = p_user_id AND currency = p_to_currency;

  -- Create swap order
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    order_type, execution_rate, status, fee_amount, executed_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, v_to_amount,
    'instant', v_exchange_rate, 'executed', v_fee_amount, now()
  )
  RETURNING order_id INTO v_order_id;

  -- Record transaction
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, fee, confirmed_at)
  VALUES (p_user_id, 'swap', p_to_currency, v_to_amount, 'completed', v_fee_amount, now())
  RETURNING id INTO v_transaction_id;

  -- Distribute referral fees (leverage = 1 for spot trading)
  PERFORM distribute_trading_fees(
    p_user_id,
    v_transaction_id,
    p_from_amount,
    v_fee_amount,
    1
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'from_amount', p_from_amount,
    'to_amount', v_to_amount,
    'exchange_rate', v_exchange_rate,
    'fee', v_fee_amount
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION distribute_trading_fees(uuid, uuid, numeric, numeric, integer) TO authenticated;

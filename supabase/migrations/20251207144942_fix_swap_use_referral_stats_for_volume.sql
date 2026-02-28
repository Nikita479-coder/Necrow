/*
  # Fix swap to use referral_stats for volume tracking
  
  1. Changes
    - Updates execute_instant_swap to use referral_stats table instead of non-existent user_volume_tracking
    - Removes references to user_volume_tracking
    
  2. Notes
    - Volume tracking is already handled in referral_stats.total_volume_30d
    - This fix ensures swap functions work correctly
*/

-- Fix execute_instant_swap to use referral_stats
CREATE OR REPLACE FUNCTION execute_instant_swap(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from_wallet record;
  v_to_wallet record;
  v_exchange_rate numeric;
  v_to_amount numeric;
  v_order_id uuid;
  v_fee_amount numeric;
  v_transaction_id uuid;
  v_to_usd_rate numeric;
  v_volume_usd numeric;
BEGIN
  IF p_from_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  IF p_from_currency = p_to_currency THEN
    RAISE EXCEPTION 'Cannot swap same currency';
  END IF;

  v_exchange_rate := get_swap_rate(p_from_currency, p_to_currency);

  IF v_exchange_rate <= 0 THEN
    RAISE EXCEPTION 'Exchange rate not available for % to %', p_from_currency, p_to_currency;
  END IF;

  v_to_amount := p_from_amount * v_exchange_rate;
  v_fee_amount := v_to_amount * 0.001;
  v_to_amount := v_to_amount - v_fee_amount;

  -- Ensure from wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, p_from_currency, 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Lock and check from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'main'
  FOR UPDATE;

  IF (v_from_wallet.balance) < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient available balance';
  END IF;

  -- Ensure to wallet exists
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, p_to_currency, 'main', 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Deduct from source wallet
  UPDATE wallets
  SET balance = balance - p_from_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_from_currency
    AND wallet_type = 'main';

  -- Add to destination wallet
  UPDATE wallets
  SET balance = balance + v_to_amount, updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_to_currency
    AND wallet_type = 'main';

  -- Record swap order with 'executed' status
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    order_type, execution_rate, status, fee_amount, executed_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, v_to_amount,
    'instant', v_exchange_rate, 'executed', v_fee_amount, now()
  )
  RETURNING order_id INTO v_order_id;

  -- Calculate volume in USD
  v_to_usd_rate := get_swap_rate(p_to_currency, 'USDT');
  v_volume_usd := v_to_amount * v_to_usd_rate;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    fee,
    confirmed_at
  ) VALUES (
    p_user_id,
    'swap',
    p_to_currency,
    v_to_amount,
    'completed',
    v_fee_amount,
    now()
  ) RETURNING id INTO v_transaction_id;

  -- Update volume tracking in referral_stats
  INSERT INTO referral_stats (user_id, total_volume_30d, total_volume_all_time, updated_at)
  VALUES (p_user_id, v_volume_usd, v_volume_usd, now())
  ON CONFLICT (user_id) DO UPDATE SET
    total_volume_30d = referral_stats.total_volume_30d + v_volume_usd,
    total_volume_all_time = referral_stats.total_volume_all_time + v_volume_usd,
    updated_at = now();

  -- Distribute fees and referral commissions
  PERFORM distribute_trading_fees(
    p_user_id,
    v_transaction_id,
    v_volume_usd,
    v_fee_amount,
    1
  );

  -- Recalculate VIP level immediately after swap
  PERFORM calculate_user_vip_level(p_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'to_amount', v_to_amount,
    'fee_amount', v_fee_amount,
    'execution_rate', v_exchange_rate
  );
END;
$$;

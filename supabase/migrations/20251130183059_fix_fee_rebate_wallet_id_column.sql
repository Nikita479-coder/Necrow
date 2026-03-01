/*
  # Fix Fee Rebate Function Wallet ID Column

  1. Changes
    - Update apply_fee_rebate to use 'id' instead of 'wallet_id'
    - Fix wallet lookup query

  2. Purpose
    - Fix column name mismatch error
    - Enable fee rebates to work correctly
*/

CREATE OR REPLACE FUNCTION apply_fee_rebate(
  p_user_id uuid,
  p_fee_amount numeric,
  p_fee_type text,
  p_related_entity_id text DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rebate_rate numeric;
  v_rebate_amount numeric;
  v_wallet_id uuid;
BEGIN
  -- Get user's rebate rate
  SELECT rebate_rate INTO v_rebate_rate
  FROM user_vip_status
  WHERE user_id = p_user_id;

  -- If no VIP status found, use VIP 1 default (5%)
  IF v_rebate_rate IS NULL THEN
    v_rebate_rate := 5;
  END IF;

  -- Calculate rebate amount
  v_rebate_amount := p_fee_amount * (v_rebate_rate / 100);

  -- Get or create user's spot wallet for USDT
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, 'USDT', 'spot', 0)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO NOTHING
  RETURNING id INTO v_wallet_id;

  IF v_wallet_id IS NULL THEN
    SELECT id INTO v_wallet_id
    FROM wallets
    WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'spot';
  END IF;

  -- Credit rebate to user's wallet
  UPDATE wallets
  SET balance = balance + v_rebate_amount,
      updated_at = now()
  WHERE id = v_wallet_id;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    p_user_id,
    'fee_rebate',
    v_rebate_amount,
    'USDT',
    'completed',
    jsonb_build_object(
      'original_fee', p_fee_amount,
      'rebate_rate', v_rebate_rate,
      'fee_type', p_fee_type,
      'related_entity_id', p_related_entity_id
    )
  );

  RETURN v_rebate_amount;
END;
$$;
/*
  # Fix Fee Rebate - Credit to Futures Wallet

  ## Problem
  Fee rebates from futures trading were being credited to the main wallet,
  causing unexpected balance changes in the main wallet when closing futures positions.

  ## Solution
  Modify apply_fee_rebate to:
  1. Detect if the fee is from futures trading (futures_open, futures_close, funding, liquidation)
  2. If from futures, credit the rebate to futures_margin wallet
  3. If from other sources (swap/spot), credit to main wallet as before

  ## Impact
  - Futures fee rebates now go directly to futures wallet
  - Main wallet stays unchanged when closing futures positions
  - Swap/spot fee rebates still go to main wallet
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
  v_wallet_type text;
BEGIN
  SELECT rebate_rate INTO v_rebate_rate
  FROM user_vip_status
  WHERE user_id = p_user_id;

  IF v_rebate_rate IS NULL THEN
    v_rebate_rate := 5;
  END IF;

  v_rebate_amount := p_fee_amount * (v_rebate_rate / 100);

  IF p_fee_type IN ('futures_open', 'futures_close', 'funding', 'liquidation', 'maker', 'taker') THEN
    v_wallet_type := 'futures_margin';
  ELSE
    v_wallet_type := 'main';
  END IF;

  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, 'USDT', v_wallet_type, 0)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO NOTHING
  RETURNING id INTO v_wallet_id;

  IF v_wallet_id IS NULL THEN
    SELECT id INTO v_wallet_id
    FROM wallets
    WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = v_wallet_type;
  END IF;

  UPDATE wallets
  SET balance = balance + v_rebate_amount,
      updated_at = now()
  WHERE id = v_wallet_id;

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
      'related_entity_id', p_related_entity_id,
      'credited_to', v_wallet_type
    )
  );

  RETURN v_rebate_amount;
END;
$$;

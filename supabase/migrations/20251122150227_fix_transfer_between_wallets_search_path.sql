/*
  # Fix Transfer Between Wallets Search Path

  1. Problem
    - transfer_between_wallets is SECURITY DEFINER without SET search_path
    - Could cause issues with table lookups
    
  2. Solution
    - Add SET search_path = public
*/

CREATE OR REPLACE FUNCTION public.transfer_between_wallets(
  user_id_param uuid,
  currency_param text,
  amount_param numeric,
  from_wallet_type_param text,
  to_wallet_type_param text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  from_wallet_record RECORD;
  to_wallet_record RECORD;
BEGIN
  IF from_wallet_type_param = to_wallet_type_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to same wallet type');
  END IF;

  IF amount_param <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  IF from_wallet_type_param NOT IN ('main', 'assets', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF to_wallet_type_param NOT IN ('main', 'assets', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  SELECT * INTO from_wallet_record
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = currency_param 
    AND wallet_type = from_wallet_type_param
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
  END IF;

  IF from_wallet_record.balance < amount_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  SELECT * INTO to_wallet_record
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = currency_param 
    AND wallet_type = to_wallet_type_param
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (user_id_param, currency_param, to_wallet_type_param, 0)
    RETURNING * INTO to_wallet_record;
  END IF;

  UPDATE wallets
  SET balance = balance - amount_param,
      updated_at = now()
  WHERE id = from_wallet_record.id;

  UPDATE wallets
  SET balance = balance + amount_param,
      updated_at = now()
  WHERE id = to_wallet_record.id;

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status
  ) VALUES (
    user_id_param,
    'transfer',
    currency_param,
    amount_param,
    0,
    'completed'
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Successfully transferred ' || amount_param || ' ' || currency_param || ' from ' || from_wallet_type_param || ' to ' || to_wallet_type_param
  );
END;
$$;

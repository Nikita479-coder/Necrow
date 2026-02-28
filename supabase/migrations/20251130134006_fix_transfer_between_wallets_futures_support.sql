/*
  # Fix transfer_between_wallets to Support Futures Wallet

  ## Summary
  Updates the transfer_between_wallets function to properly handle transfers 
  to/from the futures wallet by using the dedicated futures_margin_wallets table
  and transfer functions instead of the generic wallets table.

  ## Changes
  1. When transferring to/from futures wallet, use the dedicated functions:
     - transfer_to_futures_wallet() - for transfers TO futures
     - transfer_from_futures_wallet() - for transfers FROM futures
  2. For other wallet types, continue using the existing wallets table logic
  3. Futures transfers only work with USDT (futures wallet is USDT-only)

  ## Important Notes
  - Futures wallet uses futures_margin_wallets table (USDT only)
  - Other wallets use the wallets table (supports multiple currencies)
  - This prevents funds from "disappearing" when transferring to futures
*/

CREATE OR REPLACE FUNCTION transfer_between_wallets(
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
  -- Validate inputs
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

  -- Special handling for futures wallet (only supports USDT)
  IF from_wallet_type_param = 'futures' OR to_wallet_type_param = 'futures' THEN
    IF currency_param != 'USDT' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Futures wallet only supports USDT');
    END IF;

    -- Transfer FROM futures wallet
    IF from_wallet_type_param = 'futures' THEN
      -- Use dedicated futures withdrawal function
      RETURN transfer_from_futures_wallet(user_id_param, amount_param);
    END IF;

    -- Transfer TO futures wallet
    IF to_wallet_type_param = 'futures' THEN
      -- Use dedicated futures deposit function
      RETURN transfer_to_futures_wallet(user_id_param, amount_param);
    END IF;
  END IF;

  -- Regular wallet-to-wallet transfer (not involving futures)
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

  -- Perform the transfer
  UPDATE wallets
  SET balance = balance - amount_param,
      updated_at = now()
  WHERE id = from_wallet_record.id;

  UPDATE wallets
  SET balance = balance + amount_param,
      updated_at = now()
  WHERE id = to_wallet_record.id;

  -- Record transaction
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
    'message', format('Successfully transferred %s %s from %s to %s', amount_param, currency_param, from_wallet_type_param, to_wallet_type_param)
  );
END;
$$;
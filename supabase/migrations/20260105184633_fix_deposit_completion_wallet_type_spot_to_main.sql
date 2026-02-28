/*
  # Fix Deposit Completion Wallet Type

  ## Problem
  The deposit completion function was using `wallet_type = 'spot'` which is NOT
  a valid wallet type in the database constraint. Valid types are:
  'main', 'assets', 'copy', 'futures', 'card'

  This caused deposits to silently fail when trying to credit user wallets.

  ## Solution
  Update the function to use `wallet_type = 'main'` which is the correct
  wallet type for spot/deposit funds.

  ## Changes
  1. Recreate process_crypto_deposit_completion with correct wallet_type = 'main'
  2. Keep the currency normalization feature (removing network suffixes)
*/

CREATE OR REPLACE FUNCTION process_crypto_deposit_completion(
  p_nowpayments_payment_id text,
  p_status text,
  p_actually_paid numeric,
  p_outcome_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deposit crypto_deposits;
  v_wallet_updated boolean := false;
  v_credit_currency text;
  v_normalized_currency text;
  v_credit_amount numeric;
  v_notification_id uuid;
  v_already_processed boolean := false;
BEGIN
  SELECT * INTO v_deposit
  FROM crypto_deposits
  WHERE nowpayments_payment_id = p_nowpayments_payment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Deposit not found'
    );
  END IF;

  IF v_deposit.completed_at IS NOT NULL THEN
    v_already_processed := true;
    
    UPDATE crypto_deposits
    SET
      status = p_status,
      actually_paid = COALESCE(p_actually_paid, actually_paid),
      outcome_amount = COALESCE(p_outcome_amount, outcome_amount),
      updated_at = now()
    WHERE nowpayments_payment_id = p_nowpayments_payment_id;

    RETURN jsonb_build_object(
      'success', true,
      'already_processed', true,
      'deposit_id', v_deposit.payment_id,
      'status', p_status,
      'wallet_updated', false,
      'message', 'Deposit was already credited'
    );
  END IF;

  UPDATE crypto_deposits
  SET
    status = p_status,
    actually_paid = p_actually_paid,
    outcome_amount = p_outcome_amount,
    updated_at = now(),
    completed_at = CASE WHEN p_status IN ('finished', 'partially_paid', 'overpaid') THEN now() ELSE completed_at END
  WHERE nowpayments_payment_id = p_nowpayments_payment_id;

  IF p_status IN ('finished', 'partially_paid', 'overpaid') AND p_actually_paid > 0 THEN
    v_credit_currency := v_deposit.pay_currency;
    
    v_normalized_currency := normalize_crypto_currency(v_credit_currency);
    
    v_credit_amount := p_actually_paid;

    -- FIXED: Changed wallet_type from 'spot' to 'main' (valid wallet type)
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (v_deposit.user_id, v_normalized_currency, v_credit_amount, 'main')
    ON CONFLICT (user_id, currency, wallet_type)
    DO UPDATE SET
      balance = wallets.balance + v_credit_amount,
      updated_at = now();

    v_wallet_updated := true;

    INSERT INTO transactions (
      user_id,
      transaction_type,
      amount,
      currency,
      status,
      details
    ) VALUES (
      v_deposit.user_id,
      'deposit',
      v_credit_amount,
      v_normalized_currency,
      'completed',
      jsonb_build_object(
        'payment_id', v_deposit.payment_id,
        'nowpayments_payment_id', p_nowpayments_payment_id,
        'original_currency', v_deposit.pay_currency,
        'normalized_currency', v_normalized_currency,
        'pay_amount', p_actually_paid,
        'wallet_type', 'main'
      )
    );

    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_deposit.user_id,
      'deposit_credited',
      'Deposit Credited',
      'Your deposit of ' || v_credit_amount || ' ' || UPPER(v_normalized_currency) || ' has been credited to your Spot wallet.',
      false
    )
    RETURNING id INTO v_notification_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'already_processed', false,
    'deposit_id', v_deposit.payment_id,
    'status', p_status,
    'wallet_updated', v_wallet_updated,
    'original_currency', v_credit_currency,
    'normalized_currency', v_normalized_currency,
    'amount_credited', v_credit_amount,
    'notification_id', v_notification_id
  );
END;
$$;

COMMENT ON FUNCTION process_crypto_deposit_completion IS 
  'Processes NOWPayments callback and credits user Main wallet with normalized cryptocurrency (network suffixes removed)';

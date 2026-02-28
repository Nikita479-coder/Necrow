/*
  # Fix Deposit Commission - Use payment_id Instead of id

  ## Problem
  The `process_crypto_deposit_completion` function was passing `v_deposit.id` 
  to the commission distribution functions, but the `crypto_deposits` table
  doesn't have an `id` column - it uses `payment_id` as the primary key.
  
  This caused the exclusive affiliate commissions to silently fail.

  ## Solution
  Change `v_deposit.id` to `v_deposit.payment_id` when calling commission 
  distribution functions.
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
  v_exclusive_result jsonb;
  v_multi_tier_result jsonb;
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

    -- FIX: Use payment_id instead of non-existent id column
    BEGIN
      v_exclusive_result := distribute_exclusive_deposit_commission(
        v_deposit.user_id,
        v_credit_amount,
        v_deposit.payment_id  -- Changed from v_deposit.id
      );
    EXCEPTION WHEN OTHERS THEN
      v_exclusive_result := jsonb_build_object('error', SQLERRM);
    END;

    BEGIN
      v_multi_tier_result := distribute_multi_tier_deposit_commissions(
        v_deposit.user_id,
        v_credit_amount,
        v_deposit.payment_id  -- Changed from v_deposit.id
      );
    EXCEPTION WHEN OTHERS THEN
      v_multi_tier_result := jsonb_build_object('error', SQLERRM);
    END;
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
    'notification_id', v_notification_id,
    'exclusive_affiliate', v_exclusive_result,
    'multi_tier_commissions', v_multi_tier_result
  );
END;
$$;

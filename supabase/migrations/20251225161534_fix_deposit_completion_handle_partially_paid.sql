/*
  # Fix Deposit Completion to Handle Partially Paid Status

  ## Summary
  Updates the process_crypto_deposit_completion function to properly handle
  'partially_paid' status from NOWPayments and credit user wallets immediately.

  ## Changes
  - Credit user wallet for both 'finished' and 'partially_paid' statuses
  - Set completed_at timestamp for partially_paid deposits
  - Show deposits as completed when partially paid

  ## Security
  - Function remains SECURITY DEFINER for system use
  - Only processes deposits that exist in database
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
  v_user_id uuid;
  v_wallet_updated boolean := false;
  v_credit_currency text;
  v_credit_amount numeric;
  v_notification_id uuid;
BEGIN
  -- Get the deposit record
  SELECT * INTO v_deposit
  FROM crypto_deposits
  WHERE nowpayments_payment_id = p_nowpayments_payment_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Deposit not found'
    );
  END IF;

  -- Update deposit status
  UPDATE crypto_deposits
  SET
    status = p_status,
    actually_paid = p_actually_paid,
    outcome_amount = p_outcome_amount,
    updated_at = now(),
    completed_at = CASE WHEN p_status IN ('finished', 'partially_paid') THEN now() ELSE completed_at END
  WHERE nowpayments_payment_id = p_nowpayments_payment_id;

  -- If payment is finished or partially paid, credit the user's wallet with actual currency
  IF p_status IN ('finished', 'partially_paid') AND p_actually_paid > 0 THEN
    -- Use the actual cryptocurrency that was paid
    v_credit_currency := v_deposit.pay_currency;
    v_credit_amount := p_actually_paid;

    -- Get or create wallet for the actual currency (always in Spot wallet)
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (v_deposit.user_id, v_credit_currency, v_credit_amount, 'main')
    ON CONFLICT (user_id, currency, wallet_type)
    DO UPDATE SET
      balance = wallets.balance + v_credit_amount,
      updated_at = now();

    v_wallet_updated := true;

    -- Create transaction record
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
      v_credit_currency,
      'completed',
      'Crypto deposit via NOWPayments - Payment ID: ' || v_deposit.payment_id
    );

    -- Create notification for user
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_deposit.user_id,
      'deposit_credited',
      'Deposit Credited',
      'Your deposit of ' || v_credit_amount || ' ' || UPPER(v_credit_currency) || ' has been credited to your Spot wallet.',
      false
    )
    RETURNING id INTO v_notification_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'deposit_id', v_deposit.payment_id,
    'status', p_status,
    'wallet_updated', v_wallet_updated,
    'currency_credited', v_credit_currency,
    'amount_credited', v_credit_amount,
    'notification_id', v_notification_id
  );
END;
$$;

COMMENT ON FUNCTION process_crypto_deposit_completion IS
  'Processes NOWPayments callback and credits user Spot wallet with actual cryptocurrency when payment is finished or partially paid. Creates notification for user.';

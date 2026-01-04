/*
  # Add overpaid status to deposit completion

  1. Changes
    - Update process_crypto_deposit_completion to treat 'overpaid' as a completed deposit
    - This allows deposits that are overpaid to be credited to user wallets
    - Add 'deposit_credited' notification type to notifications constraint
*/

-- First add deposit_credited to valid notification types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'referral_payout'::text,
    'trade_executed'::text,
    'kyc_update'::text,
    'account_update'::text,
    'system'::text,
    'copy_trade'::text,
    'position_closed'::text,
    'position_sl_hit'::text,
    'position_tp_hit'::text,
    'position_liquidated'::text,
    'vip_downgrade'::text,
    'vip_upgrade'::text,
    'shark_card_application'::text,
    'withdrawal_completed'::text,
    'withdrawal_rejected'::text,
    'withdrawal_approved'::text,
    'bonus'::text,
    'affiliate_payout'::text,
    'pending_copy_trade'::text,
    'deposit_completed'::text,
    'deposit_failed'::text,
    'deposit_credited'::text,
    'broadcast'::text,
    'reward'::text,
    'promotion'::text
  ])
);

-- Update the deposit completion function to handle overpaid status
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

  -- Check if already processed
  IF v_deposit.completed_at IS NOT NULL THEN
    v_already_processed := true;
    
    -- Update status but don't credit again
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

  -- Update deposit record - treat finished, partially_paid, and overpaid as completed
  UPDATE crypto_deposits
  SET
    status = p_status,
    actually_paid = p_actually_paid,
    outcome_amount = p_outcome_amount,
    updated_at = now(),
    completed_at = CASE WHEN p_status IN ('finished', 'partially_paid', 'overpaid') THEN now() ELSE completed_at END
  WHERE nowpayments_payment_id = p_nowpayments_payment_id;

  -- Credit the wallet for finished, partially_paid, and overpaid deposits
  IF p_status IN ('finished', 'partially_paid', 'overpaid') AND p_actually_paid > 0 THEN
    v_credit_currency := v_deposit.pay_currency;
    v_credit_amount := p_actually_paid;

    -- Credit the wallet
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
      'Crypto Deposit'
    );

    -- Send notification
    INSERT INTO notifications (user_id, type, title, message, read)
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
    'already_processed', false,
    'deposit_id', v_deposit.payment_id,
    'status', p_status,
    'wallet_updated', v_wallet_updated,
    'currency_credited', v_credit_currency,
    'amount_credited', v_credit_amount,
    'notification_id', v_notification_id
  );
END;
$$;

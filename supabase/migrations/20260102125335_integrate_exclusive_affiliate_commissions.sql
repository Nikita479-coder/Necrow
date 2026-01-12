/*
  # Integrate Exclusive Affiliate Commissions

  ## Summary
  Integrates the exclusive affiliate commission system into:
  1. Deposit completion - pays deposit commissions
  2. Trading fees - pays fee share commissions

  ## Changes
  - Updates process_crypto_deposit_completion to call exclusive affiliate commission
  - Creates trigger for trading fee commission distribution
*/

-- Update deposit completion to include exclusive affiliate commission
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
  v_exclusive_result jsonb;
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
    completed_at = CASE WHEN p_status IN ('finished', 'partially_paid') THEN now() ELSE completed_at END
  WHERE nowpayments_payment_id = p_nowpayments_payment_id;

  IF p_status IN ('finished', 'partially_paid') AND p_actually_paid > 0 THEN
    v_credit_currency := v_deposit.pay_currency;
    v_credit_amount := p_actually_paid;

    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (v_deposit.user_id, v_credit_currency, v_credit_amount, 'main')
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
      v_credit_currency,
      'completed',
      'Crypto deposit via NOWPayments - Payment ID: ' || v_deposit.payment_id
    );

    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_deposit.user_id,
      'deposit_credited',
      'Deposit Credited',
      'Your deposit of ' || v_credit_amount || ' ' || UPPER(v_credit_currency) || ' has been credited to your Spot wallet.',
      false
    )
    RETURNING id INTO v_notification_id;
    
    -- Distribute exclusive affiliate deposit commissions
    -- Convert to USD equivalent for commission calculation
    v_exclusive_result := distribute_exclusive_deposit_commission(
      v_deposit.user_id,
      v_credit_amount, -- Amount in deposit currency (treated as USD equivalent)
      v_deposit.id
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'already_processed', false,
    'deposit_id', v_deposit.payment_id,
    'status', p_status,
    'wallet_updated', v_wallet_updated,
    'currency_credited', v_credit_currency,
    'amount_credited', v_credit_amount,
    'notification_id', v_notification_id,
    'exclusive_affiliate', v_exclusive_result
  );
END;
$$;

-- Create function to distribute exclusive fee commission from trading
CREATE OR REPLACE FUNCTION distribute_exclusive_trading_fee(
  p_trader_id uuid,
  p_fee_amount numeric,
  p_reference_id uuid,
  p_reference_type text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only distribute if there's an exclusive affiliate in the upline
  IF EXISTS (
    SELECT 1 FROM get_exclusive_upline_chain(p_trader_id) LIMIT 1
  ) THEN
    PERFORM distribute_exclusive_fee_commission(
      p_trader_id,
      p_fee_amount,
      p_reference_id,
      p_reference_type
    );
  END IF;
END;
$$;

-- Create trigger function for fee collections
CREATE OR REPLACE FUNCTION trigger_exclusive_fee_commission()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if this is a trading fee that should trigger exclusive affiliate commission
  IF NEW.fee_amount > 0 AND NEW.fee_type IN ('futures_open', 'futures_close', 'swap', 'funding') THEN
    PERFORM distribute_exclusive_trading_fee(
      NEW.user_id,
      NEW.fee_amount,
      NEW.id,
      NEW.fee_type
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger on fee_collections table
DROP TRIGGER IF EXISTS trg_exclusive_fee_commission ON fee_collections;
CREATE TRIGGER trg_exclusive_fee_commission
  AFTER INSERT ON fee_collections
  FOR EACH ROW
  EXECUTE FUNCTION trigger_exclusive_fee_commission();

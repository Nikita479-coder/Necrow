/*
  # NOWPayments Integration System

  ## Summary
  Creates comprehensive tables for tracking cryptocurrency deposits via NOWPayments API.

  ## Tables Created
  
  ### 1. crypto_deposits
  Tracks all deposit requests and their lifecycle
  - payment_id (uuid, primary key) - Unique payment identifier
  - user_id (uuid) - User making the deposit
  - nowpayments_payment_id (text) - NOWPayments payment ID
  - price_amount (numeric) - Amount in USD
  - price_currency (text) - Fiat currency (USD)
  - pay_amount (numeric) - Amount in crypto
  - pay_currency (text) - Cryptocurrency to pay with
  - pay_address (text) - Deposit address for payment
  - status (text) - Payment status (waiting, confirming, confirmed, sending, partially_paid, finished, failed, refunded, expired)
  - actually_paid (numeric) - Actual amount paid
  - outcome_amount (numeric) - Amount credited to wallet
  - created_at (timestamptz) - When payment was created
  - updated_at (timestamptz) - Last status update
  - completed_at (timestamptz) - When payment completed
  - expires_at (timestamptz) - Payment expiration time
  - payment_extra (jsonb) - Additional payment data

  ### 2. nowpayments_callbacks
  Stores IPN callbacks from NOWPayments for audit trail
  - id (uuid, primary key)
  - payment_id (uuid) - Reference to crypto_deposits
  - callback_data (jsonb) - Full callback payload
  - processed (boolean) - Whether callback was processed
  - created_at (timestamptz)

  ## Security
  - RLS enabled on all tables
  - Users can only view their own deposits
  - Service role needed for payment processing
  - Callbacks table accessible only to system
*/

-- Create crypto_deposits table
CREATE TABLE IF NOT EXISTS crypto_deposits (
  payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  nowpayments_payment_id text UNIQUE,
  price_amount numeric NOT NULL,
  price_currency text NOT NULL DEFAULT 'USD',
  pay_amount numeric,
  pay_currency text NOT NULL,
  pay_address text,
  status text NOT NULL DEFAULT 'waiting',
  actually_paid numeric DEFAULT 0,
  outcome_amount numeric DEFAULT 0,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  completed_at timestamptz,
  expires_at timestamptz,
  payment_extra jsonb DEFAULT '{}'::jsonb,
  
  CONSTRAINT valid_status CHECK (status IN (
    'waiting', 'confirming', 'confirmed', 'sending', 
    'partially_paid', 'finished', 'failed', 'refunded', 'expired'
  ))
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_crypto_deposits_user_id ON crypto_deposits(user_id);
CREATE INDEX IF NOT EXISTS idx_crypto_deposits_status ON crypto_deposits(status);
CREATE INDEX IF NOT EXISTS idx_crypto_deposits_nowpayments_id ON crypto_deposits(nowpayments_payment_id);

-- Create nowpayments_callbacks table for IPN tracking
CREATE TABLE IF NOT EXISTS nowpayments_callbacks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid REFERENCES crypto_deposits(payment_id) ON DELETE SET NULL,
  nowpayments_payment_id text,
  callback_data jsonb NOT NULL,
  processed boolean DEFAULT false,
  created_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_callbacks_payment_id ON nowpayments_callbacks(payment_id);
CREATE INDEX IF NOT EXISTS idx_callbacks_nowpayments_id ON nowpayments_callbacks(nowpayments_payment_id);
CREATE INDEX IF NOT EXISTS idx_callbacks_processed ON nowpayments_callbacks(processed);

-- Enable RLS
ALTER TABLE crypto_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE nowpayments_callbacks ENABLE ROW LEVEL SECURITY;

-- RLS Policies for crypto_deposits
CREATE POLICY "Users can view own deposits"
  ON crypto_deposits FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own deposits"
  ON crypto_deposits FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- RLS Policies for callbacks (system only)
CREATE POLICY "Service role can manage callbacks"
  ON nowpayments_callbacks FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Function to update deposit status and credit wallet
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
    completed_at = CASE WHEN p_status = 'finished' THEN now() ELSE completed_at END
  WHERE nowpayments_payment_id = p_nowpayments_payment_id;
  
  -- If payment is finished, credit the user's wallet
  IF p_status = 'finished' AND p_outcome_amount > 0 THEN
    -- Get or create wallet for the currency
    INSERT INTO wallets (user_id, currency, balance)
    VALUES (v_deposit.user_id, 'USDT', p_outcome_amount)
    ON CONFLICT (user_id, currency)
    DO UPDATE SET
      balance = wallets.balance + p_outcome_amount,
      updated_at = now();
    
    v_wallet_updated := true;
    
    -- Create transaction record
    INSERT INTO transactions (
      user_id,
      transaction_type,
      amount,
      currency,
      status,
      metadata
    ) VALUES (
      v_deposit.user_id,
      'deposit',
      p_outcome_amount,
      'USDT',
      'completed',
      jsonb_build_object(
        'payment_id', v_deposit.payment_id,
        'nowpayments_payment_id', p_nowpayments_payment_id,
        'pay_currency', v_deposit.pay_currency,
        'pay_amount', p_actually_paid
      )
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'deposit_id', v_deposit.payment_id,
    'status', p_status,
    'wallet_updated', v_wallet_updated,
    'amount_credited', p_outcome_amount
  );
END;
$$;

COMMENT ON FUNCTION process_crypto_deposit_completion IS 
  'Processes NOWPayments callback and credits user wallet when payment is finished';

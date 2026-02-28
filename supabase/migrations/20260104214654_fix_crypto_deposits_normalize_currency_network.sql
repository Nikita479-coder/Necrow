/*
  # Fix Crypto Deposits - Normalize Currency Networks

  ## Summary
  Updates the crypto deposit system to normalize currency names by removing network suffixes,
  ensuring deposits credit the base currency wallet regardless of network used.

  ## Changes
  1. Create helper function to normalize currency names (remove TRC20, ERC20, BSC, etc.)
  2. Update deposit completion to use normalized currency name
  3. Ensure USDTTRC20 → USDT, USDTERC20 → USDT, BTCLN → BTC, etc.

  ## Examples
  - USDTTRC20 → USDT
  - USDTERC20 → USDT
  - USDTBSC → USDT
  - BTCLN → BTC
  - ETH → ETH (unchanged)
*/

-- Create function to normalize currency by removing network suffixes
CREATE OR REPLACE FUNCTION normalize_crypto_currency(p_currency text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- Remove common network suffixes
  -- TRC20, ERC20, BSC, BEP20, POLYGON, MATIC, SOL, ARBITRUM, OPTIMISM, AVALANCHE, LN (Lightning)
  RETURN REGEXP_REPLACE(
    UPPER(p_currency),
    '(TRC20|ERC20|BSC|BEP20|POLYGON|MATIC|SOL|ARBITRUM|OPTIMISM|AVALANCHE|LN|AVAXC)$',
    '',
    'i'
  );
END;
$$;

COMMENT ON FUNCTION normalize_crypto_currency IS 
  'Normalizes cryptocurrency names by removing network suffixes (TRC20, ERC20, etc.)';

-- Update the deposit completion function to use normalized currency
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
  v_normalized_currency text;
  v_credit_amount numeric;
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
  
  -- If payment is finished, credit the user's wallet with actual currency
  IF p_status = 'finished' AND p_actually_paid > 0 THEN
    -- Use the actual cryptocurrency that was paid
    v_credit_currency := v_deposit.pay_currency;
    
    -- Normalize the currency (remove network suffixes)
    v_normalized_currency := normalize_crypto_currency(v_credit_currency);
    
    v_credit_amount := p_actually_paid;
    
    -- Get or create wallet for the normalized currency (always in Spot wallet)
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (v_deposit.user_id, v_normalized_currency, v_credit_amount, 'spot')
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
      v_normalized_currency,
      'completed',
      jsonb_build_object(
        'payment_id', v_deposit.payment_id,
        'nowpayments_payment_id', p_nowpayments_payment_id,
        'original_currency', v_deposit.pay_currency,
        'normalized_currency', v_normalized_currency,
        'pay_amount', p_actually_paid,
        'wallet_type', 'spot'
      )
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'deposit_id', v_deposit.payment_id,
    'status', p_status,
    'wallet_updated', v_wallet_updated,
    'original_currency', v_credit_currency,
    'normalized_currency', v_normalized_currency,
    'amount_credited', v_credit_amount
  );
END;
$$;

COMMENT ON FUNCTION process_crypto_deposit_completion IS 
  'Processes NOWPayments callback and credits user Spot wallet with normalized cryptocurrency (network suffixes removed)';

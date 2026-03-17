/*
  # Fix Commission Trigger - Cast Trade Amount

  ## Problem
  COALESCE returns unknown type which causes function signature mismatch

  ## Solution
  Explicitly cast to NUMERIC
*/

CREATE OR REPLACE FUNCTION trigger_distribute_commissions_on_fee()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_transaction_id UUID;
BEGIN
  -- Only process if fee amount is positive
  IF NEW.fee_amount <= 0 THEN
    RETURN NEW;
  END IF;

  -- Check if this user has a referrer
  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = NEW.user_id;

  -- If no referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get the ACTUAL transaction ID from the transactions table
  -- This is the futures_open transaction that was created alongside the position
  SELECT id INTO v_transaction_id
  FROM transactions
  WHERE user_id = NEW.user_id
    AND transaction_type = 'futures_open'
    AND created_at >= NEW.created_at - INTERVAL '5 seconds'
  ORDER BY created_at DESC
  LIMIT 1;

  -- If no matching transaction found, create one for tracking
  IF v_transaction_id IS NULL THEN
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      details
    ) VALUES (
      NEW.user_id,
      'fee_collection',
      NEW.currency,
      NEW.fee_amount,
      'completed',
      'Fee collection for ' || NEW.pair
    )
    RETURNING id INTO v_transaction_id;
  END IF;

  -- Call the unified commission distribution function with explicit type casting
  PERFORM distribute_commissions(
    p_trader_id := NEW.user_id,
    p_transaction_id := v_transaction_id,
    p_trade_amount := COALESCE(NEW.notional_size, NEW.fee_amount * 100)::NUMERIC,
    p_fee_amount := NEW.fee_amount,
    p_leverage := 1
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the transaction
  RAISE WARNING 'Commission distribution failed for user %: % (transaction_id: %)', 
    NEW.user_id, SQLERRM, v_transaction_id;
  RETURN NEW;
END;
$$;
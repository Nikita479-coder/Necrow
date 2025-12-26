/*
  # Fix First Deposit Bonus Trigger Column Reference

  ## Summary
  The tr_award_first_deposit_bonus trigger function was referencing NEW.amount_usd
  which doesn't exist in the transactions table. This was causing deposit completion
  to fail silently.

  ## Changes
  - Fix the trigger function to use NEW.amount instead of NEW.amount_usd
  - The amount column in transactions table stores the transaction amount directly

  ## Impact
  - Deposit completions will now work correctly
  - First deposit bonuses will be properly awarded
*/

CREATE OR REPLACE FUNCTION tr_award_first_deposit_bonus()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tracking record;
  v_result jsonb;
  v_deposit_amount numeric;
BEGIN
  IF NEW.status = 'completed' AND NEW.transaction_type = 'deposit' THEN
    SELECT * INTO v_tracking
    FROM signup_bonus_tracking
    WHERE user_id = NEW.user_id;

    IF v_tracking IS NULL OR NOT v_tracking.first_deposit_bonus_awarded THEN
      v_deposit_amount := NEW.amount;
      v_result := award_first_deposit_bonus(NEW.user_id, v_deposit_amount);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

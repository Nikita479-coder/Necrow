/*
  # Fix giveaway ticket trigger to include partially_paid deposits

  1. Changes
    - Updated `trigger_award_giveaway_tickets` to also fire for 'partially_paid'
      and 'overpaid' deposit statuses, matching the deposit completion logic

  2. Impact
    - Users with partially_paid or overpaid deposits will now correctly receive
      giveaway tickets if applicable
*/

CREATE OR REPLACE FUNCTION trigger_award_giveaway_tickets()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NEW.status IN ('finished', 'partially_paid', 'overpaid')
     AND (OLD.status IS NULL OR OLD.status NOT IN ('finished', 'partially_paid', 'overpaid')) THEN
    v_result := award_giveaway_tickets(
      NEW.user_id,
      NEW.payment_id,
      COALESCE(NEW.outcome_amount, NEW.actually_paid, NEW.price_amount)
    );
  END IF;

  RETURN NEW;
END;
$$;

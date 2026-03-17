/*
  # Fix Commission Trigger - Block Any Bonus Margin Position

  ## Problem
  The commission distribution trigger allowed proportional commissions on
  positions partially funded by bonus margin. This should be fully blocked
  to prevent any commission generation from bonus-funded trades.

  ## Changes
  1. Updated `trigger_distribute_commissions_on_fee` to block commissions
     on ANY position that has `margin_from_locked_bonus > 0`
     - Previously only blocked 100% bonus positions, allowed proportional for partial
     - Now blocks all positions with any bonus margin involvement

  ## Security
  - Prevents referral commission generation from bonus-funded trades
  - Consistent with the updated VIP rebate trigger behavior
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
  v_position_margin NUMERIC;
  v_locked_bonus_margin NUMERIC;
BEGIN
  IF NEW.fee_amount <= 0 THEN
    RETURN NEW;
  END IF;

  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = NEW.user_id;

  IF v_referrer_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.position_id IS NOT NULL THEN
    SELECT
      margin_allocated,
      COALESCE(margin_from_locked_bonus, 0)
    INTO v_position_margin, v_locked_bonus_margin
    FROM futures_positions
    WHERE position_id = NEW.position_id;

    IF FOUND AND v_locked_bonus_margin > 0 THEN
      RETURN NEW;
    END IF;
  END IF;

  v_transaction_id := COALESCE(NEW.position_id, gen_random_uuid());

  PERFORM distribute_commissions(
    p_trader_id := NEW.user_id,
    p_transaction_id := v_transaction_id,
    p_trade_amount := COALESCE(NEW.notional_size, NEW.fee_amount * 100),
    p_fee_amount := NEW.fee_amount,
    p_leverage := 1
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Commission distribution failed for user %: %', NEW.user_id, SQLERRM;
  RETURN NEW;
END;
$$;

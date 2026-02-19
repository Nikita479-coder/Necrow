/*
  # Fix VIP Fee Rebate - Require Real Deposit

  ## Problem
  Users who have never made a real deposit were receiving VIP fee rebates
  on trades funded entirely by bonus-derived funds. The rebate trigger only
  checked the position-level `margin_from_locked_bonus` field, which is 0
  when users trade with profits from previously unlocked bonuses.

  ## Changes
  1. Updated `trigger_apply_fee_rebate` to check `has_completed_deposit()`
     - Users without any completed deposits get NO rebates at all
     - This matches the same check used in the commission distribution trigger
  2. Also blocks rebates on ANY position that has bonus margin (not just 100%)
     - Previously, partial bonus positions got proportional rebates
     - Now, if any bonus margin is involved, no rebate is given

  ## Security
  - Prevents exploitation of bonus funds to earn VIP rebates
  - Aligns rebate eligibility with commission eligibility
*/

CREATE OR REPLACE FUNCTION trigger_apply_fee_rebate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rebate_amount numeric;
  v_position_margin numeric;
  v_locked_bonus_margin numeric;
  v_adjusted_fee numeric;
BEGIN
  IF NEW.fee_type IN ('maker', 'taker', 'funding', 'liquidation', 'spread', 'futures_open', 'futures_close') THEN
    IF NOT has_completed_deposit(NEW.user_id) THEN
      UPDATE fee_collections
      SET rebate_amount = 0,
          rebate_rate = 0
      WHERE id = NEW.id;
      RETURN NEW;
    END IF;

    v_adjusted_fee := NEW.fee_amount;

    IF NEW.position_id IS NOT NULL THEN
      SELECT
        margin_allocated,
        COALESCE(margin_from_locked_bonus, 0)
      INTO v_position_margin, v_locked_bonus_margin
      FROM futures_positions
      WHERE position_id = NEW.position_id;

      IF FOUND AND v_position_margin > 0 AND v_locked_bonus_margin > 0 THEN
        UPDATE fee_collections
        SET rebate_amount = 0,
            rebate_rate = 0
        WHERE id = NEW.id;
        RETURN NEW;
      END IF;
    END IF;

    IF v_adjusted_fee < 0.01 THEN
      UPDATE fee_collections
      SET rebate_amount = 0,
          rebate_rate = 0
      WHERE id = NEW.id;
      RETURN NEW;
    END IF;

    v_rebate_amount := apply_fee_rebate(
      NEW.user_id,
      v_adjusted_fee,
      NEW.fee_type,
      NEW.position_id::text
    );

    UPDATE fee_collections
    SET
      rebate_amount = v_rebate_amount,
      rebate_rate = (
        SELECT rebate_rate
        FROM user_vip_status
        WHERE user_id = NEW.user_id
      )
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

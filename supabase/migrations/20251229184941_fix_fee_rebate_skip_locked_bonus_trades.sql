/*
  # Fix Fee Rebate - Skip Trades Using Locked Bonus Margin

  ## Problem
  Fee rebates were being awarded even when users traded with locked bonus (free) margin.
  Users shouldn't receive fee rebates on trades made with bonus funds.

  ## Solution
  Modify the fee rebate trigger to:
  1. Check if the position used locked bonus margin
  2. If ALL margin came from locked bonus, skip the rebate entirely
  3. If PARTIAL margin came from locked bonus, only give rebate proportional to the real money used

  ## Example
  - User opens position with $20 margin ($17 from locked bonus, $3 from wallet)
  - Fee is $0.85
  - Before: User gets 5% rebate on full $0.85 = $0.0425
  - After: User gets 5% rebate only on wallet portion = $0.85 * (3/20) * 5% = $0.0064
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
  v_regular_margin_ratio numeric;
  v_adjusted_fee numeric;
BEGIN
  IF NEW.fee_type IN ('maker', 'taker', 'funding', 'liquidation', 'spread', 'futures_open', 'futures_close') THEN
    v_adjusted_fee := NEW.fee_amount;
    
    IF NEW.position_id IS NOT NULL THEN
      SELECT 
        margin_allocated,
        COALESCE(margin_from_locked_bonus, 0)
      INTO v_position_margin, v_locked_bonus_margin
      FROM futures_positions
      WHERE position_id = NEW.position_id;
      
      IF FOUND AND v_position_margin > 0 THEN
        IF v_locked_bonus_margin >= v_position_margin THEN
          UPDATE fee_collections
          SET rebate_amount = 0,
              rebate_rate = 0
          WHERE id = NEW.id;
          RETURN NEW;
        END IF;
        
        IF v_locked_bonus_margin > 0 THEN
          v_regular_margin_ratio := (v_position_margin - v_locked_bonus_margin) / v_position_margin;
          v_adjusted_fee := NEW.fee_amount * v_regular_margin_ratio;
        END IF;
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

/*
  # Fix Commission Distribution - Skip Trades Using Locked Bonus Margin

  ## Problem
  Referral/affiliate commissions were being generated even when users traded with 
  locked bonus (free) margin. Referrers shouldn't earn commissions on trades made 
  with bonus funds - only real money trades.

  ## Solution
  Modify the commission distribution trigger to:
  1. Check if the position used locked bonus margin
  2. If ALL margin came from locked bonus, skip commission distribution entirely
  3. If PARTIAL margin came from locked bonus, only distribute commission proportional 
     to the real money portion

  ## Example
  - User trades with $20 margin ($17 from locked bonus, $3 from real wallet)
  - Fee is $0.85, referrer should get 10% = $0.085
  - Before: Referrer gets $0.085 commission on full fee
  - After: Referrer gets commission only on wallet portion = $0.085 * (3/20) = $0.0128
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
  v_regular_margin_ratio NUMERIC;
  v_adjusted_fee NUMERIC;
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
        RETURN NEW;
      END IF;
      
      IF v_locked_bonus_margin > 0 THEN
        v_regular_margin_ratio := (v_position_margin - v_locked_bonus_margin) / v_position_margin;
        v_adjusted_fee := NEW.fee_amount * v_regular_margin_ratio;
      END IF;
    END IF;
  END IF;

  IF v_adjusted_fee < 0.001 THEN
    RETURN NEW;
  END IF;

  v_transaction_id := COALESCE(NEW.position_id, gen_random_uuid());

  PERFORM distribute_commissions(
    p_trader_id := NEW.user_id,
    p_transaction_id := v_transaction_id,
    p_trade_amount := COALESCE(NEW.notional_size, v_adjusted_fee * 100) * 
      CASE WHEN v_regular_margin_ratio IS NOT NULL THEN v_regular_margin_ratio ELSE 1 END,
    p_fee_amount := v_adjusted_fee,
    p_leverage := 1
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Commission distribution failed for user %: %', NEW.user_id, SQLERRM;
  RETURN NEW;
END;
$$;

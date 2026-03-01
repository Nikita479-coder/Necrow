/*
  # Fix CPA trigger column reference

  1. Changes
    - Fix trigger_cpa_first_trade to use position_id instead of id
    - futures_positions table uses position_id as its primary key

  2. Issue
    - The trigger was referencing 'id' which doesn't exist on futures_positions
    - This caused "column id does not exist" error when placing orders
*/

CREATE OR REPLACE FUNCTION trigger_cpa_first_trade()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_cpa_record RECORD;
  v_is_first_trade BOOLEAN;
BEGIN
  IF NEW.status = 'open' THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM futures_positions
      WHERE user_id = NEW.user_id AND position_id != NEW.position_id
    ) INTO v_is_first_trade;

    IF v_is_first_trade THEN
      SELECT referred_by INTO v_referrer_id
      FROM user_profiles
      WHERE id = NEW.user_id;

      IF v_referrer_id IS NOT NULL AND check_cpa_eligibility(v_referrer_id) THEN
        SELECT * INTO v_cpa_record
        FROM cpa_payouts
        WHERE affiliate_id = v_referrer_id AND referred_user_id = NEW.user_id;

        IF v_cpa_record.id IS NULL THEN
          INSERT INTO cpa_payouts (
            affiliate_id, referred_user_id, trade_paid, total_cpa_earned, status
          ) VALUES (
            v_referrer_id, NEW.user_id, true, 50, 'qualified'
          );
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Trade', 50);
        ELSIF NOT COALESCE(v_cpa_record.trade_paid, false) THEN
          UPDATE cpa_payouts
          SET trade_paid = true, total_cpa_earned = COALESCE(total_cpa_earned, 0) + 50
          WHERE id = v_cpa_record.id;
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Trade', 50);
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

/*
  # Fix CPA First Deposit Trigger - Details Cast Issue
  
  1. Changes
    - Recreate trigger_cpa_first_deposit function to handle jsonb details correctly
    - Remove any incorrect usd_value casting that's causing errors
    
  2. Security
    - SECURITY DEFINER with explicit search_path
*/

CREATE OR REPLACE FUNCTION trigger_cpa_first_deposit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_cpa_record RECORD;
  v_is_first_deposit BOOLEAN;
BEGIN
  IF NEW.transaction_type = 'deposit' AND NEW.status = 'completed' THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM transactions
      WHERE user_id = NEW.user_id
        AND transaction_type = 'deposit'
        AND status = 'completed'
        AND id != NEW.id
    ) INTO v_is_first_deposit;

    IF v_is_first_deposit THEN
      SELECT referred_by INTO v_referrer_id
      FROM user_profiles
      WHERE id = NEW.user_id;

      IF v_referrer_id IS NOT NULL AND check_cpa_eligibility(v_referrer_id) THEN
        SELECT * INTO v_cpa_record
        FROM cpa_payouts
        WHERE affiliate_id = v_referrer_id AND referred_user_id = NEW.user_id;

        IF v_cpa_record.id IS NULL THEN
          INSERT INTO cpa_payouts (
            affiliate_id, referred_user_id, deposit_paid, total_cpa_earned, status
          ) VALUES (
            v_referrer_id, NEW.user_id, true, 25, 'qualified'
          );
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Deposit', 25);
        ELSIF NOT COALESCE(v_cpa_record.deposit_paid, false) THEN
          UPDATE cpa_payouts
          SET deposit_paid = true, total_cpa_earned = COALESCE(total_cpa_earned, 0) + 25
          WHERE id = v_cpa_record.id;
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Deposit', 25);
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

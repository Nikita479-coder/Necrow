/*
  # Fix KYC Risk Score Column Name in Trigger Function

  ## Description
  The trigger function `trigger_risk_update_on_kyc_change` was referencing a
  non-existent column `kyc_risk_score`. The correct column name is `kyc_score`.

  ## Changes
  - Update the trigger function to use the correct column name `kyc_score`
  - Also update to use all required columns for proper risk score insertion
*/

CREATE OR REPLACE FUNCTION trigger_risk_update_on_kyc_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF (TG_OP = 'UPDATE' AND (OLD.kyc_level IS DISTINCT FROM NEW.kyc_level OR OLD.kyc_status IS DISTINCT FROM NEW.kyc_status)) THEN
    INSERT INTO risk_scores (
      user_id,
      overall_score,
      trading_score,
      kyc_score,
      behavior_score,
      risk_level,
      updated_at
    )
    VALUES (
      NEW.id,
      CASE 
        WHEN NEW.kyc_level >= 2 THEN 20
        WHEN NEW.kyc_level = 1 THEN 40
        ELSE 60
      END,
      30,
      CASE 
        WHEN NEW.kyc_level >= 2 THEN 10
        WHEN NEW.kyc_level = 1 THEN 30
        ELSE 70
      END,
      25,
      CASE 
        WHEN NEW.kyc_level >= 2 THEN 'low'
        WHEN NEW.kyc_level = 1 THEN 'medium'
        ELSE 'high'
      END,
      now()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET 
      kyc_score = EXCLUDED.kyc_score,
      overall_score = EXCLUDED.overall_score,
      risk_level = EXCLUDED.risk_level,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$;

/*
  # Add Auto-Trigger Columns to Bonus Types

  1. Schema Changes
    - `bonus_types` table gets 3 new columns:
      - `auto_trigger_event` (text, nullable) - event that triggers this bonus automatically
        Supported values: 'kyc_verified', 'first_deposit', 'second_deposit', 'third_deposit', 'trustpilot_review'
      - `auto_trigger_enabled` (boolean, default false) - whether auto-triggering is active
      - `auto_trigger_config` (jsonb, nullable) - extra configuration for deposit-type triggers
        e.g. { "bonus_percentage": 100, "max_amount": 500, "min_deposit": 10 }

  2. Purpose
    - Makes bonus_types the single source of truth for both manual and automatic bonus awarding
    - Admins can toggle automatic bonuses on/off and change amounts from the CRM
    - Database triggers become generic -- they look up what is configured in bonus_types

  3. Important Notes
    - No existing data is modified
    - All existing bonuses default to auto_trigger_enabled = false (manual only)
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bonus_types' AND column_name = 'auto_trigger_event'
  ) THEN
    ALTER TABLE bonus_types ADD COLUMN auto_trigger_event text DEFAULT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bonus_types' AND column_name = 'auto_trigger_enabled'
  ) THEN
    ALTER TABLE bonus_types ADD COLUMN auto_trigger_enabled boolean DEFAULT false NOT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bonus_types' AND column_name = 'auto_trigger_config'
  ) THEN
    ALTER TABLE bonus_types ADD COLUMN auto_trigger_config jsonb DEFAULT NULL;
  END IF;
END $$;

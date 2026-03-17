/*
  # Add unique constraint on auto_accept_settings

  1. Changes
    - Add a unique constraint on (follower_id, trader_id, is_mock) to support upsert operations
    - Drop the old expression-based unique index that used COALESCE (incompatible with ON CONFLICT)

  2. Notes
    - The existing unique index used COALESCE which cannot be referenced by ON CONFLICT
    - This adds a proper constraint that the Supabase client can target
    - trader_id is set to NOT NULL since every auto-accept setting targets a specific trader
*/

UPDATE auto_accept_settings SET trader_id = '00000000-0000-0000-0000-000000000000' WHERE trader_id IS NULL;

ALTER TABLE auto_accept_settings ALTER COLUMN trader_id SET NOT NULL;

ALTER TABLE auto_accept_settings ALTER COLUMN is_mock SET NOT NULL;

DROP INDEX IF EXISTS idx_auto_accept_settings_unique;

ALTER TABLE auto_accept_settings
  ADD CONSTRAINT auto_accept_settings_follower_trader_mock_unique
  UNIQUE (follower_id, trader_id, is_mock);

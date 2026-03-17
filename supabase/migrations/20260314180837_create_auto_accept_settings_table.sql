/*
  # Create auto_accept_settings Table

  1. New Tables
    - `auto_accept_settings`
      - `id` (uuid, primary key)
      - `follower_id` (uuid, references auth.users)
      - `trader_id` (uuid, nullable)
      - `is_mock` (boolean, default false)
      - `expires_at` (timestamptz)
      - `created_at` (timestamptz)
  2. Security
    - Enable RLS
    - Users can read/insert/update/delete their own settings
  3. Constraints
    - Unique on (follower_id, trader_id, is_mock)
*/

CREATE TABLE IF NOT EXISTS auto_accept_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trader_id uuid,
  is_mock boolean DEFAULT false,
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_auto_accept_settings_unique
  ON auto_accept_settings (follower_id, COALESCE(trader_id, '00000000-0000-0000-0000-000000000000'::uuid), is_mock);

CREATE INDEX IF NOT EXISTS idx_auto_accept_settings_follower
  ON auto_accept_settings (follower_id);

CREATE INDEX IF NOT EXISTS idx_auto_accept_settings_expires
  ON auto_accept_settings (expires_at);

ALTER TABLE auto_accept_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own auto-accept settings"
  ON auto_accept_settings
  FOR SELECT
  TO authenticated
  USING (auth.uid() = follower_id);

CREATE POLICY "Users can insert own auto-accept settings"
  ON auto_accept_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can update own auto-accept settings"
  ON auto_accept_settings
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = follower_id)
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can delete own auto-accept settings"
  ON auto_accept_settings
  FOR DELETE
  TO authenticated
  USING (auth.uid() = follower_id);

-- Update expire function to also clean up the table
CREATE OR REPLACE FUNCTION expire_auto_accept_settings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row RECORD;
  v_count integer := 0;
BEGIN
  FOR v_row IN
    SELECT id, follower_id
    FROM auto_accept_settings
    WHERE expires_at < NOW()
  LOOP
    DELETE FROM auto_accept_settings WHERE id = v_row.id;

    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_row.follower_id,
      'system',
      'Auto-Accept Period Ended',
      'Your 24-hour copy trading auto-accept period has ended. Enable it again to continue automatic trade acceptance.',
      false
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

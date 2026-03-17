/*
  # Game Bot "Login with Shark" Linking System

  ## Overview
  Creates infrastructure for linking Shark user accounts to the external
  Telegram game bot. Mirrors the existing notification bot linking pattern
  but stores game bot info in separate columns so both bots coexist.

  ## New Columns on user_profiles
  - `game_bot_chat_id` (text) - Game bot Telegram chat ID
  - `game_bot_username` (text) - Telegram username for display
  - `game_bot_linked_at` (timestamptz) - When account was linked

  ## New Tables

  ### game_bot_linking_codes
  One-time codes for secure account linking
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User requesting the link
  - `code` (text, unique) - 8-character alphanumeric code
  - `expires_at` (timestamptz) - Code expiration (10 minutes)
  - `used_at` (timestamptz) - When code was used

  ## New Functions
  - `generate_game_bot_linking_code` - Creates a one-time linking code
  - `verify_game_bot_linking_code` - Verifies code and links account
  - `unlink_game_bot_account` - Removes game bot link
  - `get_user_by_game_bot_chat_id` - Looks up user by game bot chat ID

  ## Security
  - RLS enabled on game_bot_linking_codes
  - Users can only manage their own codes
  - All functions use SECURITY DEFINER with explicit search_path
*/

-- Add game bot columns to user_profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'game_bot_chat_id'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN game_bot_chat_id text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'game_bot_username'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN game_bot_username text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'game_bot_linked_at'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN game_bot_linked_at timestamptz;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_profiles_game_bot_chat_id
  ON user_profiles(game_bot_chat_id)
  WHERE game_bot_chat_id IS NOT NULL;

-- Create game_bot_linking_codes table
CREATE TABLE IF NOT EXISTS game_bot_linking_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  code text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,

  CONSTRAINT game_code_format CHECK (code ~ '^[A-Z0-9]{8}$')
);

CREATE INDEX IF NOT EXISTS idx_game_bot_linking_codes_user
  ON game_bot_linking_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_game_bot_linking_codes_code
  ON game_bot_linking_codes(code)
  WHERE used_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_game_bot_linking_codes_expires
  ON game_bot_linking_codes(expires_at)
  WHERE used_at IS NULL;

ALTER TABLE game_bot_linking_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own game bot linking codes"
  ON game_bot_linking_codes FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own game bot linking codes"
  ON game_bot_linking_codes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own game bot linking codes"
  ON game_bot_linking_codes FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own game bot linking codes"
  ON game_bot_linking_codes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Generate a game bot linking code
CREATE OR REPLACE FUNCTION generate_game_bot_linking_code(p_user_id uuid)
RETURNS TABLE(code text, expires_at timestamptz, bot_username text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_expires_at timestamptz;
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_recent_count integer;
BEGIN
  SELECT COUNT(*) INTO v_recent_count
  FROM game_bot_linking_codes
  WHERE user_id = p_user_id
  AND created_at > now() - interval '1 hour';

  IF v_recent_count >= 5 THEN
    RAISE EXCEPTION 'Rate limit exceeded. Please try again later.';
  END IF;

  DELETE FROM game_bot_linking_codes
  WHERE user_id = p_user_id
  AND used_at IS NULL;

  LOOP
    v_code := '';
    FOR i IN 1..8 LOOP
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::integer, 1);
    END LOOP;

    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM game_bot_linking_codes WHERE game_bot_linking_codes.code = v_code
    );
  END LOOP;

  v_expires_at := now() + interval '10 minutes';

  INSERT INTO game_bot_linking_codes (user_id, code, expires_at)
  VALUES (p_user_id, v_code, v_expires_at);

  RETURN QUERY SELECT v_code, v_expires_at, 'satoshiacademybot'::text;
END;
$$;

-- Verify and use a game bot linking code
CREATE OR REPLACE FUNCTION verify_game_bot_linking_code(
  p_code text,
  p_chat_id text,
  p_username text DEFAULT NULL
)
RETURNS TABLE(success boolean, user_id uuid, username text, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_record record;
  v_username text;
BEGIN
  SELECT gblc.*, up.game_bot_chat_id as existing_chat_id
  INTO v_code_record
  FROM game_bot_linking_codes gblc
  JOIN user_profiles up ON up.id = gblc.user_id
  WHERE gblc.code = upper(p_code)
  AND gblc.used_at IS NULL
  AND gblc.expires_at > now();

  IF v_code_record IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, NULL::text, 'Invalid or expired code'::text;
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM user_profiles
    WHERE game_bot_chat_id = p_chat_id
    AND id != v_code_record.user_id
  ) THEN
    RETURN QUERY SELECT false, NULL::uuid, NULL::text, 'This Telegram account is already linked to another Shark user'::text;
    RETURN;
  END IF;

  UPDATE game_bot_linking_codes
  SET used_at = now()
  WHERE id = v_code_record.id;

  UPDATE user_profiles
  SET
    game_bot_chat_id = p_chat_id,
    game_bot_username = p_username,
    game_bot_linked_at = now()
  WHERE id = v_code_record.user_id;

  SELECT up.username INTO v_username
  FROM user_profiles up
  WHERE up.id = v_code_record.user_id;

  RETURN QUERY SELECT true, v_code_record.user_id, v_username, 'Account linked successfully!'::text;
END;
$$;

-- Unlink game bot account
CREATE OR REPLACE FUNCTION unlink_game_bot_account(p_chat_id text)
RETURNS TABLE(success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id
  FROM user_profiles
  WHERE game_bot_chat_id = p_chat_id;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'No account linked to this Telegram'::text;
    RETURN;
  END IF;

  UPDATE user_profiles
  SET
    game_bot_chat_id = NULL,
    game_bot_username = NULL,
    game_bot_linked_at = NULL
  WHERE id = v_user_id;

  RETURN QUERY SELECT true, 'Game bot account unlinked successfully'::text;
END;
$$;

-- Look up a user by their game bot chat ID
CREATE OR REPLACE FUNCTION get_user_by_game_bot_chat_id(p_chat_id text)
RETURNS TABLE(
  user_id uuid,
  username text,
  email text,
  kyc_level integer,
  game_bot_linked_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    up.id as user_id,
    up.username,
    au.email,
    up.kyc_level,
    up.game_bot_linked_at
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  WHERE up.game_bot_chat_id = p_chat_id;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_game_bot_linking_code(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_game_bot_linking_code(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION unlink_game_bot_account(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_by_game_bot_chat_id(text) TO authenticated;

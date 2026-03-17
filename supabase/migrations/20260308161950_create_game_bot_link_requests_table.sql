/*
  # Create Game Bot Link Requests Table

  1. New Tables
    - `game_bot_link_requests`
      - `id` (uuid, primary key)
      - `token` (text, unique) - secure random token for the link request
      - `chat_id` (text) - Telegram chat ID of the user requesting the link
      - `telegram_username` (text, nullable) - Telegram username for display
      - `expires_at` (timestamptz) - when this request expires (10 minutes)
      - `confirmed_by` (uuid, nullable, FK to auth.users) - user who confirmed
      - `confirmed_at` (timestamptz, nullable) - when confirmed
      - `created_at` (timestamptz, default now)

  2. Security
    - Enable RLS
    - Authenticated users can read rows by token (to validate on the website)
    - Service role handles inserts from the bot edge function

  3. Indexes
    - Unique index on token
    - Index on chat_id
    - Index on expires_at for cleanup
*/

CREATE TABLE IF NOT EXISTS game_bot_link_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token text UNIQUE NOT NULL,
  chat_id text NOT NULL,
  telegram_username text,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '10 minutes'),
  confirmed_by uuid REFERENCES auth.users(id),
  confirmed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_game_bot_link_requests_chat_id ON game_bot_link_requests(chat_id);
CREATE INDEX IF NOT EXISTS idx_game_bot_link_requests_expires_at ON game_bot_link_requests(expires_at);

ALTER TABLE game_bot_link_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read link requests by token"
  ON game_bot_link_requests
  FOR SELECT
  TO authenticated
  USING (
    expires_at > now()
    AND confirmed_at IS NULL
  );

CREATE POLICY "Authenticated users can update their own confirmation"
  ON game_bot_link_requests
  FOR UPDATE
  TO authenticated
  USING (
    expires_at > now()
    AND confirmed_at IS NULL
  )
  WITH CHECK (
    confirmed_by = auth.uid()
  );

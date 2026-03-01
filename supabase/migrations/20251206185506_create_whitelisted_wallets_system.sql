/*
  # Create Whitelisted Wallets System

  1. New Tables
    - `whitelisted_wallets`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `wallet_address` (text)
      - `label` (text) - friendly name for the wallet
      - `currency` (text) - cryptocurrency type (BTC, ETH, USDT, etc.)
      - `network` (text) - network/chain (e.g., ERC20, TRC20, BTC, etc.)
      - `created_at` (timestamptz)
      - `last_used_at` (timestamptz, nullable)

  2. Security
    - Enable RLS on `whitelisted_wallets` table
    - Add policies for users to manage their own whitelisted wallets
    - Add policy for admin to view all whitelisted wallets

  3. Indexes
    - Add index on user_id for faster lookups
    - Add unique constraint on (user_id, wallet_address, currency, network)
*/

CREATE TABLE IF NOT EXISTS whitelisted_wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wallet_address text NOT NULL,
  label text NOT NULL,
  currency text NOT NULL,
  network text NOT NULL,
  created_at timestamptz DEFAULT now(),
  last_used_at timestamptz,
  CONSTRAINT unique_user_wallet_currency UNIQUE (user_id, wallet_address, currency, network)
);

ALTER TABLE whitelisted_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own whitelisted wallets"
  ON whitelisted_wallets
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can add wallets to whitelist"
  ON whitelisted_wallets
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove wallets from whitelist"
  ON whitelisted_wallets
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all whitelisted wallets"
  ON whitelisted_wallets
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE INDEX IF NOT EXISTS idx_whitelisted_wallets_user_id ON whitelisted_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_whitelisted_wallets_currency ON whitelisted_wallets(currency);
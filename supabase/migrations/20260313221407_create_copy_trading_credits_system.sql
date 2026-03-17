/*
  # Create Copy Trading Credits System

  1. New Table: `copy_trading_credits`
    - `id` (uuid, PK)
    - `user_id` (uuid, FK)
    - `amount` (numeric) - credit amount granted
    - `remaining_amount` (numeric) - unused portion if partially consumed
    - `status` (text) - available, locked_in_relationship, forfeited, used, expired
    - `relationship_id` (uuid, nullable) - set when used in copy trading
    - `granted_by` (uuid) - admin who granted it
    - `notes` (text, nullable)
    - `lock_days` (integer, default 30) - how long credit locks after starting copy trading
    - `locked_until` (timestamptz, nullable) - set when copy trading starts
    - `forfeited_at` (timestamptz, nullable)
    - `forfeited_amount` (numeric, default 0)
    - `expires_at` (timestamptz, nullable) - optional expiry if unused
    - `created_at`, `updated_at` (timestamptz)

  2. Security
    - Enable RLS
    - Users can read their own credits
    - Admin/service role can manage all

  3. Indexes
    - user_id + status for quick lookups
*/

CREATE TABLE IF NOT EXISTS copy_trading_credits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  amount numeric NOT NULL CHECK (amount > 0),
  remaining_amount numeric NOT NULL CHECK (remaining_amount >= 0),
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'locked_in_relationship', 'forfeited', 'used', 'expired')),
  relationship_id uuid REFERENCES copy_relationships(id),
  granted_by uuid REFERENCES auth.users(id),
  notes text,
  lock_days integer NOT NULL DEFAULT 30,
  locked_until timestamptz,
  forfeited_at timestamptz,
  forfeited_amount numeric NOT NULL DEFAULT 0,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE copy_trading_credits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own credits"
  ON copy_trading_credits
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admin can read all credits"
  ON copy_trading_credits
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

CREATE POLICY "Service role can manage credits"
  ON copy_trading_credits
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_copy_trading_credits_user_status
  ON copy_trading_credits(user_id, status);

CREATE INDEX IF NOT EXISTS idx_copy_trading_credits_relationship
  ON copy_trading_credits(relationship_id)
  WHERE relationship_id IS NOT NULL;

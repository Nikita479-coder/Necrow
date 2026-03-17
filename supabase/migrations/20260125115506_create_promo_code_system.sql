/*
  # Create Promo Code System

  1. New Tables
    - `promo_codes`
      - `id` (uuid, primary key)
      - `code` (text, unique) - The promo code string (e.g., 'COPY20')
      - `description` (text) - Description of the promo
      - `bonus_amount` (numeric) - Amount of bonus to award
      - `bonus_type` (text) - Type of bonus ('copy_trading_only')
      - `expiry_days` (integer) - Number of days the bonus is valid
      - `max_redemptions` (integer, nullable) - Maximum total redemptions allowed
      - `current_redemptions` (integer) - Current number of redemptions
      - `is_active` (boolean) - Whether the promo code is active
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `promo_code_redemptions`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `promo_code_id` (uuid, references promo_codes)
      - `bonus_amount` (numeric) - Amount awarded
      - `bonus_expires_at` (timestamptz) - When the bonus expires
      - `status` (text) - active, expired, depleted
      - `profits_transferred` (numeric) - Profits transferred to main wallet on expiry
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Users can read their own redemptions
    - Admins can manage promo codes

  3. Initial Data
    - Insert COPY20 promo code with $20 bonus for copy trading
*/

-- Create promo_codes table
CREATE TABLE IF NOT EXISTS promo_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  description text,
  bonus_amount numeric(20, 8) NOT NULL DEFAULT 0,
  bonus_type text NOT NULL DEFAULT 'copy_trading_only',
  expiry_days integer NOT NULL DEFAULT 30,
  max_redemptions integer,
  current_redemptions integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create promo_code_redemptions table
CREATE TABLE IF NOT EXISTS promo_code_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  promo_code_id uuid NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
  bonus_amount numeric(20, 8) NOT NULL DEFAULT 0,
  bonus_expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'depleted')),
  profits_transferred numeric(20, 8) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, promo_code_id)
);

-- Enable RLS
ALTER TABLE promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE promo_code_redemptions ENABLE ROW LEVEL SECURITY;

-- Promo codes policies
CREATE POLICY "Anyone can view active promo codes"
  ON promo_codes
  FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage promo codes"
  ON promo_codes
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Promo code redemptions policies
CREATE POLICY "Users can view their own redemptions"
  ON promo_code_redemptions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "System can insert redemptions"
  ON promo_code_redemptions
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can manage redemptions"
  ON promo_code_redemptions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON promo_codes(code);
CREATE INDEX IF NOT EXISTS idx_promo_codes_active ON promo_codes(is_active);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_user ON promo_code_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_status ON promo_code_redemptions(status);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_expires ON promo_code_redemptions(bonus_expires_at);

-- Insert the COPY20 promo code
INSERT INTO promo_codes (code, description, bonus_amount, bonus_type, expiry_days, is_active)
VALUES (
  'COPY20',
  '$20 Copy Trading Bonus - Use this bonus exclusively for copy trading. Profits are withdrawable, but the $20 bonus is not. Bonus expires after 30 days.',
  20,
  'copy_trading_only',
  30,
  true
)
ON CONFLICT (code) DO NOTHING;

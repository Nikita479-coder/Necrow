/*
  # Create User Fee Rebates Tracking System

  1. New Tables
    - `user_fee_rebates`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to auth.users)
      - `total_rebates` (numeric) - Total fee rebates accumulated in USDT
      - `used_rebates` (numeric) - Rebates already used to offset fees
      - `available_rebates` (numeric) - Current available rebates balance
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `user_fee_rebates` table
    - Add policies for authenticated users to read and update their own rebates

  3. Notes
    - Fee rebates accumulate from completing tasks and can be used to reduce trading fees
    - This system tracks both total earned and available balance
*/

-- Create user_fee_rebates table
CREATE TABLE IF NOT EXISTS user_fee_rebates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  total_rebates numeric(20, 8) DEFAULT 0.00 NOT NULL,
  used_rebates numeric(20, 8) DEFAULT 0.00 NOT NULL,
  available_rebates numeric(20, 8) DEFAULT 0.00 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE user_fee_rebates ENABLE ROW LEVEL SECURITY;

-- Policies for user_fee_rebates
CREATE POLICY "Users can read own fee rebates"
  ON user_fee_rebates
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own fee rebates"
  ON user_fee_rebates
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own fee rebates"
  ON user_fee_rebates
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_fee_rebates_user_id ON user_fee_rebates(user_id);

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_fee_rebates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_fee_rebates_timestamp
  BEFORE UPDATE ON user_fee_rebates
  FOR EACH ROW
  EXECUTE FUNCTION update_user_fee_rebates_updated_at();

-- Insert demo data for the demo user
DO $$
DECLARE
  demo_user_id uuid;
BEGIN
  -- Get demo user ID
  SELECT id INTO demo_user_id
  FROM auth.users
  WHERE email = 'demo@sharktrades.com';

  -- Insert fee rebates data if demo user exists
  IF demo_user_id IS NOT NULL THEN
    INSERT INTO user_fee_rebates (user_id, total_rebates, used_rebates, available_rebates)
    VALUES (demo_user_id, 85.00, 20.00, 65.00)
    ON CONFLICT (user_id) DO UPDATE
    SET total_rebates = 85.00,
        used_rebates = 20.00,
        available_rebates = 65.00,
        updated_at = now();
  END IF;
END $$;

/*
  # Create Copy Trading Bonus Claims Table

  ## Overview
  Tracks one-time bonus claims per user account. Each user can only claim 
  the copy trading bonus once in their lifetime.

  ## New Table: copy_trading_bonus_claims
  - `id` (uuid) - Primary key
  - `user_id` (uuid) - User who claimed (UNIQUE - enforces one per account)
  - `relationship_id` (uuid) - The copy relationship that received the bonus
  - `amount` (numeric) - Bonus amount (100 USDT)
  - `claimed_at` (timestamptz) - When claimed
  - `forfeited` (boolean) - Whether bonus was forfeited due to early withdrawal
  - `forfeited_at` (timestamptz) - When forfeited
  - `forfeited_amount` (numeric) - Amount forfeited (including proportional profits)

  ## Security
  - RLS enabled
  - Users can only view their own claims
*/

-- Create the claims tracking table
CREATE TABLE IF NOT EXISTS copy_trading_bonus_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  relationship_id uuid NOT NULL REFERENCES copy_relationships(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 100,
  claimed_at timestamptz NOT NULL DEFAULT now(),
  forfeited boolean DEFAULT false,
  forfeited_at timestamptz,
  forfeited_amount numeric DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- UNIQUE constraint ensures one bonus per user lifetime
  CONSTRAINT copy_trading_bonus_claims_user_unique UNIQUE (user_id)
);

-- Enable RLS
ALTER TABLE copy_trading_bonus_claims ENABLE ROW LEVEL SECURITY;

-- Users can view their own claims
CREATE POLICY "Users can view own bonus claims"
  ON copy_trading_bonus_claims
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Only system functions can insert/update (SECURITY DEFINER functions)
-- No direct user insert/update policies

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_copy_trading_bonus_claims_user_id
ON copy_trading_bonus_claims(user_id);

CREATE INDEX IF NOT EXISTS idx_copy_trading_bonus_claims_relationship_id
ON copy_trading_bonus_claims(relationship_id);

-- Add admin read policy
CREATE POLICY "Admins can view all bonus claims"
  ON copy_trading_bonus_claims
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );
/*
  # Create Bonus Management System

  ## Summary
  Creates a comprehensive bonus management system for awarding and tracking
  bonuses given to users. Admins can define bonus types and award bonuses
  that automatically transfer to user wallets.

  ## New Tables

  ### 1. bonus_types
  Defines available bonus types that admins can award
  - `id` (uuid, primary key)
  - `name` (text, unique) - Bonus type name
  - `description` (text) - Description of bonus
  - `default_amount` (numeric) - Default bonus amount in USDT
  - `category` (text) - welcome, deposit, trading, vip, referral, promotion, special
  - `expiry_days` (integer) - Days until bonus expires (null = no expiry)
  - `is_active` (boolean) - Whether this bonus type is currently active
  - `created_by` (uuid) - Admin who created it
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. user_bonuses
  Tracks bonuses awarded to users
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User who received the bonus
  - `bonus_type_id` (uuid) - Type of bonus awarded
  - `bonus_type_name` (text) - Bonus type name at time of award
  - `amount` (numeric) - Bonus amount in USDT
  - `status` (text) - pending, active, claimed, expired, cancelled
  - `awarded_by` (uuid) - Admin who awarded it
  - `awarded_at` (timestamptz)
  - `claimed_at` (timestamptz)
  - `expires_at` (timestamptz)
  - `notes` (text) - Admin notes
  - `metadata` (jsonb) - Additional data

  ## Security
  - RLS enabled on both tables
  - Only admins can manage bonus types
  - Only admins can award bonuses
  - Users can view their own bonuses
  - Automatic transfer to wallet when awarded

  ## Workflow
  1. Admin awards bonus to user
  2. Bonus record created with status 'active'
  3. Amount automatically transferred to user's USDT wallet
  4. Transaction logged in transactions table
  5. User receives notification
  6. Bonus marked as 'claimed' immediately (automatic)
*/

-- Bonus Types Table
CREATE TABLE IF NOT EXISTS bonus_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text NOT NULL,
  default_amount numeric(10,2) NOT NULL DEFAULT 0,
  category text NOT NULL CHECK (category IN ('welcome', 'deposit', 'trading', 'vip', 'referral', 'promotion', 'special')),
  expiry_days integer,
  is_active boolean DEFAULT true NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  CHECK (default_amount >= 0),
  CHECK (expiry_days IS NULL OR expiry_days > 0)
);

-- User Bonuses Table
CREATE TABLE IF NOT EXISTS user_bonuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  bonus_type_id uuid REFERENCES bonus_types(id) ON DELETE SET NULL,
  bonus_type_name text NOT NULL,
  amount numeric(10,2) NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'claimed', 'expired', 'cancelled')),
  awarded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  awarded_at timestamptz DEFAULT now() NOT NULL,
  claimed_at timestamptz,
  expires_at timestamptz,
  notes text,
  metadata jsonb DEFAULT '{}'::jsonb,
  CHECK (amount > 0)
);

-- Enable RLS
ALTER TABLE bonus_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_bonuses ENABLE ROW LEVEL SECURITY;

-- Policies for bonus_types (admin only)
CREATE POLICY "Admins can view all bonus types"
  ON bonus_types FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can create bonus types"
  ON bonus_types FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can update bonus types"
  ON bonus_types FOR UPDATE
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true)
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can delete bonus types"
  ON bonus_types FOR DELETE
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

-- Policies for user_bonuses
CREATE POLICY "Admins can view all user bonuses"
  ON user_bonuses FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Users can view own bonuses"
  ON user_bonuses FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can insert user bonuses"
  ON user_bonuses FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can update user bonuses"
  ON user_bonuses FOR UPDATE
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true)
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_bonus_types_category ON bonus_types(category);
CREATE INDEX IF NOT EXISTS idx_bonus_types_is_active ON bonus_types(is_active);
CREATE INDEX IF NOT EXISTS idx_user_bonuses_user_id ON user_bonuses(user_id);
CREATE INDEX IF NOT EXISTS idx_user_bonuses_status ON user_bonuses(status);
CREATE INDEX IF NOT EXISTS idx_user_bonuses_awarded_at ON user_bonuses(awarded_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_bonuses_expires_at ON user_bonuses(expires_at) WHERE expires_at IS NOT NULL;

-- Function to get user bonus history
CREATE OR REPLACE FUNCTION get_user_bonus_history(
  p_user_id uuid,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  bonus_type_name text,
  amount numeric,
  status text,
  awarded_at timestamptz,
  claimed_at timestamptz,
  expires_at timestamptz,
  awarded_by_username text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ub.id,
    ub.bonus_type_name,
    ub.amount,
    ub.status,
    ub.awarded_at,
    ub.claimed_at,
    ub.expires_at,
    COALESCE(up.username, 'System') as awarded_by_username,
    ub.notes
  FROM user_bonuses ub
  LEFT JOIN user_profiles up ON up.id = ub.awarded_by
  WHERE ub.user_id = p_user_id
  ORDER BY ub.awarded_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

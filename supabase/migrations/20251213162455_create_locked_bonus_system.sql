/*
  # Create Locked Bonus System

  ## Summary
  Implements a locked bonus system where bonuses can be used for futures trading
  but cannot be withdrawn. Only profits from trading with locked bonuses are
  withdrawable. Locked bonuses expire after a configurable number of days.

  ## New Tables

  ### 1. locked_bonuses
  Tracks locked bonus balances for each user
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User who received the bonus
  - `original_amount` (numeric) - Initial bonus amount awarded
  - `current_amount` (numeric) - Current balance (decreases with losses)
  - `realized_profits` (numeric) - Total profits earned from trading with this bonus
  - `bonus_type_id` (uuid) - Reference to bonus type
  - `bonus_type_name` (text) - Bonus type name at time of award
  - `awarded_by` (uuid) - Admin who awarded it
  - `notes` (text) - Admin notes
  - `status` (text) - active, expired, depleted
  - `expires_at` (timestamptz) - When the bonus expires
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## Schema Changes

  ### bonus_types table
  - Add `is_locked_bonus` column (default false)
  - Update default_expiry_days to 7 for locked bonuses

  ### user_bonuses table
  - Add `is_locked` column to track if a bonus was locked
  - Add `locked_bonus_id` to reference the locked_bonuses record

  ## Security
  - RLS enabled on locked_bonuses table
  - Users can view their own locked bonuses
  - Only admins can create/modify locked bonuses
*/

-- Add is_locked_bonus to bonus_types table
ALTER TABLE bonus_types 
  ADD COLUMN IF NOT EXISTS is_locked_bonus boolean DEFAULT false NOT NULL;

-- Update existing bonus types to set default expiry_days where not set
UPDATE bonus_types 
SET expiry_days = 7 
WHERE is_locked_bonus = true AND expiry_days IS NULL;

-- Add is_locked and locked_bonus_id to user_bonuses table
ALTER TABLE user_bonuses 
  ADD COLUMN IF NOT EXISTS is_locked boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS locked_bonus_id uuid;

-- Create locked_bonuses table
CREATE TABLE IF NOT EXISTS locked_bonuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  original_amount numeric(20,8) NOT NULL,
  current_amount numeric(20,8) NOT NULL,
  realized_profits numeric(20,8) NOT NULL DEFAULT 0,
  bonus_type_id uuid REFERENCES bonus_types(id) ON DELETE SET NULL,
  bonus_type_name text NOT NULL,
  awarded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  notes text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'depleted')),
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  CHECK (original_amount > 0),
  CHECK (current_amount >= 0)
);

-- Add foreign key to user_bonuses
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'user_bonuses_locked_bonus_id_fkey'
  ) THEN
    ALTER TABLE user_bonuses 
      ADD CONSTRAINT user_bonuses_locked_bonus_id_fkey 
      FOREIGN KEY (locked_bonus_id) REFERENCES locked_bonuses(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Enable RLS on locked_bonuses
ALTER TABLE locked_bonuses ENABLE ROW LEVEL SECURITY;

-- RLS Policies for locked_bonuses
CREATE POLICY "Users can view own locked bonuses"
  ON locked_bonuses FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all locked bonuses"
  ON locked_bonuses FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can insert locked bonuses"
  ON locked_bonuses FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can update locked bonuses"
  ON locked_bonuses FOR UPDATE
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true)
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_locked_bonuses_user_id ON locked_bonuses(user_id);
CREATE INDEX IF NOT EXISTS idx_locked_bonuses_status ON locked_bonuses(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_locked_bonuses_expires_at ON locked_bonuses(expires_at) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_user_bonuses_is_locked ON user_bonuses(is_locked) WHERE is_locked = true;

-- Function to get total active locked bonus balance for a user
CREATE OR REPLACE FUNCTION get_user_locked_bonus_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT COALESCE(SUM(current_amount), 0)
  FROM locked_bonuses
  WHERE user_id = p_user_id 
    AND status = 'active'
    AND expires_at > now();
$$;

-- Function to get detailed locked bonus info for a user
CREATE OR REPLACE FUNCTION get_user_locked_bonuses(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  original_amount numeric,
  current_amount numeric,
  realized_profits numeric,
  bonus_type_name text,
  status text,
  expires_at timestamptz,
  days_remaining integer,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT 
    lb.id,
    lb.original_amount,
    lb.current_amount,
    lb.realized_profits,
    lb.bonus_type_name,
    lb.status,
    lb.expires_at,
    GREATEST(0, EXTRACT(DAY FROM (lb.expires_at - now()))::integer) as days_remaining,
    lb.created_at
  FROM locked_bonuses lb
  WHERE lb.user_id = p_user_id
  ORDER BY lb.created_at DESC;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_locked_bonus_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_locked_bonuses(uuid) TO authenticated;

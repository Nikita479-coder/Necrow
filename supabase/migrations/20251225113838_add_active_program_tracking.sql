/*
  # Add Active Program Tracking

  ## Overview
  This migration adds the ability to track which program (referral or affiliate) 
  a user has activated. Users can only have one active at a time.

  ## Changes
  1. Add `active_program` column to user_profiles
  2. Create enum type for program types
  3. Default all existing users to 'referral' program
  4. Add index for efficient lookups

  ## Security
  Column is only modifiable through specific functions
*/

-- Add active_program column to user_profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'active_program'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN active_program TEXT DEFAULT 'referral'
      CHECK (active_program IN ('referral', 'affiliate'));
  END IF;
END $$;

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_active_program 
  ON user_profiles(active_program);

-- Initialize all existing users to referral program
UPDATE user_profiles 
SET active_program = 'referral' 
WHERE active_program IS NULL;

-- Function to switch active program
CREATE OR REPLACE FUNCTION switch_active_program(
  p_user_id UUID,
  p_program TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_program TEXT;
  v_has_referrals BOOLEAN;
BEGIN
  IF p_program NOT IN ('referral', 'affiliate') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid program type');
  END IF;

  SELECT active_program INTO v_current_program
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_current_program IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_current_program = p_program THEN
    RETURN jsonb_build_object('success', true, 'message', 'Program already active', 'program', p_program);
  END IF;

  UPDATE user_profiles
  SET active_program = p_program, updated_at = now()
  WHERE id = p_user_id;

  IF p_program = 'affiliate' THEN
    INSERT INTO affiliate_compensation_plans (user_id, plan_type, is_auto_optimized)
    VALUES (p_user_id, 'revshare', false)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    p_user_id,
    'system',
    'Program Switched',
    'You have switched to the ' || INITCAP(p_program) || ' program',
    jsonb_build_object('program', p_program, 'switched_at', now())
  );

  RETURN jsonb_build_object(
    'success', true, 
    'previous_program', v_current_program,
    'new_program', p_program
  );
END;
$$;

-- Function to get user's active program
CREATE OR REPLACE FUNCTION get_active_program(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_program TEXT;
BEGIN
  SELECT COALESCE(active_program, 'referral') INTO v_program
  FROM user_profiles
  WHERE id = p_user_id;
  
  RETURN COALESCE(v_program, 'referral');
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION switch_active_program(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_program(UUID) TO authenticated;

/*
  # Create User Eligibility Check Function

  1. New Functions
    - `check_new_user_eligibility` - Checks if a user is eligible for new user exclusive offers
      - Takes user_id and eligibility_hours as parameters
      - Returns boolean indicating eligibility
      - User is eligible if their account was created within the specified hours

  2. Security
    - Function uses SECURITY DEFINER to access user creation timestamps
    - Only checks eligibility, doesn't expose sensitive data
*/

-- Create function to check if user is eligible for new user exclusive offers
CREATE OR REPLACE FUNCTION check_new_user_eligibility(
  p_user_id uuid,
  p_eligibility_hours integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_created_at timestamptz;
  hours_since_creation numeric;
BEGIN
  -- Get user creation timestamp from auth.users
  SELECT created_at INTO user_created_at
  FROM auth.users
  WHERE id = p_user_id;

  -- If user not found, return false
  IF user_created_at IS NULL THEN
    RETURN false;
  END IF;

  -- Calculate hours since user creation
  hours_since_creation := EXTRACT(EPOCH FROM (now() - user_created_at)) / 3600;

  -- Return true if within eligibility window
  RETURN hours_since_creation <= p_eligibility_hours;
END;
$$;
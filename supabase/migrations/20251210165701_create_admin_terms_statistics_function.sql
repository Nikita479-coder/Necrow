/*
  # Admin Terms Acceptance Statistics

  1. New Functions
    - `admin_get_terms_statistics` - Get stats on terms acceptance
    - `admin_get_user_acceptance_history` - View a user's acceptance history

  2. Security
    - Only admins can execute these functions
*/

-- Function to get overall terms acceptance statistics
CREATE OR REPLACE FUNCTION admin_get_terms_statistics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_total_users bigint;
  v_accepted_users bigint;
  v_active_terms_id uuid;
BEGIN
  -- Check if user is admin
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Get active terms ID
  SELECT id INTO v_active_terms_id
  FROM terms_and_conditions
  WHERE is_active = true
  ORDER BY effective_date DESC
  LIMIT 1;

  IF v_active_terms_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No active terms found'
    );
  END IF;

  -- Count total users
  SELECT COUNT(*) INTO v_total_users
  FROM auth.users;

  -- Count users who accepted current terms
  SELECT COUNT(DISTINCT user_id) INTO v_accepted_users
  FROM user_terms_acceptance
  WHERE terms_id = v_active_terms_id;

  v_result := jsonb_build_object(
    'success', true,
    'total_users', v_total_users,
    'accepted_users', v_accepted_users,
    'pending_users', v_total_users - v_accepted_users,
    'acceptance_rate', 
      CASE 
        WHEN v_total_users > 0 THEN ROUND((v_accepted_users::numeric / v_total_users::numeric) * 100, 2)
        ELSE 0
      END
  );

  RETURN v_result;
END;
$$;

-- Function to get a specific user's acceptance history
CREATE OR REPLACE FUNCTION admin_get_user_acceptance_history(p_user_id uuid)
RETURNS TABLE(
  terms_version text,
  terms_title text,
  accepted_at timestamptz,
  ip_address text,
  user_agent text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user is admin
  IF NOT is_user_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT 
    uta.version,
    tc.title,
    uta.accepted_at,
    uta.ip_address,
    uta.user_agent
  FROM user_terms_acceptance uta
  JOIN terms_and_conditions tc ON tc.id = uta.terms_id
  WHERE uta.user_id = p_user_id
  ORDER BY uta.accepted_at DESC;
END;
$$;
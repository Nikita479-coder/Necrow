/*
  # Fix get_filtered_users to include email

  1. Changes
    - Update get_filtered_users function to join with auth.users
    - Add email field to the result
    - Update search to include email and full_name

  2. Notes
    - Email is stored in auth.users table, not user_profiles
    - Function uses security definer to access auth.users
    - Now searchable by email, username, full name, or user ID
*/

CREATE OR REPLACE FUNCTION get_filtered_users(
  p_filters jsonb DEFAULT '{}',
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_query text;
  v_count_query text;
  v_result jsonb;
  v_total integer;
  v_users jsonb;
BEGIN
  -- Check if user is admin
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN jsonb_build_object(
      'users', '[]'::jsonb,
      'total', 0,
      'limit', p_limit,
      'offset', p_offset
    );
  END IF;

  -- Base query with auth.users join for email
  v_query := 'SELECT up.*, au.email::text,
    (SELECT COALESCE(SUM(balance), 0) FROM wallets WHERE user_id = up.id) as total_balance,
    (SELECT COUNT(*) FROM futures_positions WHERE user_id = up.id AND status = ''open'') as open_positions,
    (SELECT array_agg(ut.name) FROM user_tag_assignments uta JOIN user_tags ut ON ut.id = uta.tag_id WHERE uta.user_id = up.id) as tags
    FROM user_profiles up
    LEFT JOIN auth.users au ON au.id = up.id
    WHERE 1=1';

  v_count_query := 'SELECT COUNT(*) FROM user_profiles up LEFT JOIN auth.users au ON au.id = up.id WHERE 1=1';

  -- Apply filters
  IF p_filters ? 'search' AND p_filters->>'search' != '' THEN
    v_query := v_query || format(' AND (up.username ILIKE ''%%%s%%'' OR up.full_name ILIKE ''%%%s%%'' OR au.email ILIKE ''%%%s%%'' OR up.id::text ILIKE ''%%%s%%'')',
      p_filters->>'search', p_filters->>'search', p_filters->>'search', p_filters->>'search');
    v_count_query := v_count_query || format(' AND (up.username ILIKE ''%%%s%%'' OR up.full_name ILIKE ''%%%s%%'' OR au.email ILIKE ''%%%s%%'' OR up.id::text ILIKE ''%%%s%%'')',
      p_filters->>'search', p_filters->>'search', p_filters->>'search', p_filters->>'search');
  END IF;

  IF p_filters ? 'kycStatus' AND p_filters->>'kycStatus' != 'all' THEN
    v_query := v_query || format(' AND up.kyc_status = ''%s''', p_filters->>'kycStatus');
    v_count_query := v_count_query || format(' AND up.kyc_status = ''%s''', p_filters->>'kycStatus');
  END IF;

  IF p_filters ? 'vipTier' AND p_filters->>'vipTier' != 'all' THEN
    v_query := v_query || format(' AND up.vip_tier = ''%s''', p_filters->>'vipTier');
    v_count_query := v_count_query || format(' AND up.vip_tier = ''%s''', p_filters->>'vipTier');
  END IF;

  IF p_filters ? 'hasTag' THEN
    v_query := v_query || format(' AND EXISTS (SELECT 1 FROM user_tag_assignments WHERE user_id = up.id AND tag_id = ''%s'')',
      p_filters->>'hasTag');
    v_count_query := v_count_query || format(' AND EXISTS (SELECT 1 FROM user_tag_assignments WHERE user_id = up.id AND tag_id = ''%s'')',
      p_filters->>'hasTag');
  END IF;

  IF p_filters ? 'minBalance' THEN
    v_query := v_query || format(' AND (SELECT COALESCE(SUM(balance), 0) FROM wallets WHERE user_id = up.id) >= %s',
      (p_filters->>'minBalance')::numeric);
    v_count_query := v_count_query || format(' AND (SELECT COALESCE(SUM(balance), 0) FROM wallets WHERE user_id = up.id) >= %s',
      (p_filters->>'minBalance')::numeric);
  END IF;

  IF p_filters ? 'maxBalance' THEN
    v_query := v_query || format(' AND (SELECT COALESCE(SUM(balance), 0) FROM wallets WHERE user_id = up.id) <= %s',
      (p_filters->>'maxBalance')::numeric);
    v_count_query := v_count_query || format(' AND (SELECT COALESCE(SUM(balance), 0) FROM wallets WHERE user_id = up.id) <= %s',
      (p_filters->>'maxBalance')::numeric);
  END IF;

  IF p_filters ? 'registeredAfter' THEN
    v_query := v_query || format(' AND up.created_at >= ''%s''', p_filters->>'registeredAfter');
    v_count_query := v_count_query || format(' AND up.created_at >= ''%s''', p_filters->>'registeredAfter');
  END IF;

  IF p_filters ? 'registeredBefore' THEN
    v_query := v_query || format(' AND up.created_at <= ''%s''', p_filters->>'registeredBefore');
    v_count_query := v_count_query || format(' AND up.created_at <= ''%s''', p_filters->>'registeredBefore');
  END IF;

  IF p_filters ? 'withdrawalBlocked' THEN
    v_query := v_query || format(' AND up.withdrawal_blocked = %s', (p_filters->>'withdrawalBlocked')::boolean);
    v_count_query := v_count_query || format(' AND up.withdrawal_blocked = %s', (p_filters->>'withdrawalBlocked')::boolean);
  END IF;

  -- Add ordering and pagination
  v_query := v_query || ' ORDER BY up.created_at DESC LIMIT ' || p_limit || ' OFFSET ' || p_offset;

  -- Execute queries
  EXECUTE v_count_query INTO v_total;
  EXECUTE 'SELECT jsonb_agg(row_to_json(t)) FROM (' || v_query || ') t' INTO v_users;

  RETURN jsonb_build_object(
    'users', COALESCE(v_users, '[]'::jsonb),
    'total', v_total,
    'limit', p_limit,
    'offset', p_offset
  );
END;
$$;

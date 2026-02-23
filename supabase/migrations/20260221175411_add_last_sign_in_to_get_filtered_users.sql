/*
  # Add last_sign_in_at to get_filtered_users

  1. Changes
    - Join auth.users to include last_sign_in_at in the returned user data
    - This allows the CRM to display when each user last signed in

  2. Notes
    - Uses LEFT JOIN so users without sign-in data still appear
    - last_sign_in_at comes from Supabase's built-in auth.users table
*/

DROP FUNCTION IF EXISTS get_filtered_users(jsonb, int, int);

CREATE FUNCTION get_filtered_users(
  p_filters jsonb DEFAULT '{}',
  p_limit int DEFAULT 100,
  p_offset int DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_users json;
  v_total bigint;
  v_search text;
  v_kyc_status text;
  v_vip_tier text;
  v_has_deposits text;
  v_online_status text;
  v_sort_by text;
  v_sort_order text;
BEGIN
  IF NOT check_admin_permission('view_users') THEN
    RETURN json_build_object('users', '[]'::json, 'total', 0);
  END IF;

  v_search := p_filters->>'search';
  v_kyc_status := p_filters->>'kycStatus';
  v_vip_tier := p_filters->>'vipTier';
  v_has_deposits := p_filters->>'hasDeposits';
  v_online_status := p_filters->>'onlineStatus';
  v_sort_by := COALESCE(p_filters->>'sortBy', 'created_at');
  v_sort_order := COALESCE(p_filters->>'sortOrder', 'desc');

  SELECT COUNT(*) INTO v_total
  FROM user_profiles up
  LEFT JOIN vip_tier_tracking vt ON vt.user_id = up.id
  LEFT JOIN user_sessions us ON us.user_id = up.id
  WHERE (v_search IS NULL OR v_search = '' OR up.username ILIKE '%' || v_search || '%' OR up.id::text ILIKE '%' || v_search || '%')
    AND (v_kyc_status IS NULL OR v_kyc_status = '' OR up.kyc_status = v_kyc_status)
    AND (v_vip_tier IS NULL OR v_vip_tier = '' OR vt.current_tier = v_vip_tier)
    AND (
      v_has_deposits IS NULL OR v_has_deposits = '' OR
      (v_has_deposits = 'true' AND EXISTS (
        SELECT 1 FROM crypto_deposits cd 
        WHERE cd.user_id = up.id 
        AND cd.status IN ('completed', 'confirmed', 'finished', 'partially_paid')
      )) OR
      (v_has_deposits = 'false' AND NOT EXISTS (
        SELECT 1 FROM crypto_deposits cd 
        WHERE cd.user_id = up.id 
        AND cd.status IN ('completed', 'confirmed', 'finished', 'partially_paid')
      ))
    )
    AND (
      v_online_status IS NULL OR v_online_status = '' OR v_online_status = 'all' OR
      (v_online_status = 'online' AND us.is_online = true AND us.heartbeat > NOW() - INTERVAL '2 minutes') OR
      (v_online_status = 'offline' AND (us.user_id IS NULL OR us.is_online = false OR us.heartbeat <= NOW() - INTERVAL '2 minutes'))
    );

  SELECT json_agg(row_to_json(t)) INTO v_users
  FROM (
    SELECT 
      up.id,
      up.username,
      up.full_name,
      up.kyc_status,
      COALESCE(vt.current_tier, 'None') as vip_tier,
      up.created_at,
      false as withdrawal_blocked,
      COALESCE((
        SELECT SUM(w.balance::numeric)
        FROM wallets w
        WHERE w.user_id = up.id AND w.currency = 'USDT'
      ), 0) as total_balance,
      COALESCE((
        SELECT COUNT(*)
        FROM futures_positions fp
        WHERE fp.user_id = up.id AND fp.status = 'open'
      ), 0) as open_positions,
      COALESCE((
        SELECT SUM(cd.actual_amount::numeric)
        FROM crypto_deposits cd
        WHERE cd.user_id = up.id 
        AND cd.status IN ('completed', 'confirmed', 'finished', 'partially_paid')
      ), 0) as total_deposits,
      up.referred_by,
      ARRAY[]::text[] as tags,
      (us.is_online = true AND us.heartbeat > NOW() - INTERVAL '2 minutes') as is_online,
      us.last_activity,
      us.platform,
      au.last_sign_in_at
    FROM user_profiles up
    LEFT JOIN vip_tier_tracking vt ON vt.user_id = up.id
    LEFT JOIN user_sessions us ON us.user_id = up.id
    LEFT JOIN auth.users au ON au.id = up.id
    WHERE (v_search IS NULL OR v_search = '' OR up.username ILIKE '%' || v_search || '%' OR up.id::text ILIKE '%' || v_search || '%')
      AND (v_kyc_status IS NULL OR v_kyc_status = '' OR up.kyc_status = v_kyc_status)
      AND (v_vip_tier IS NULL OR v_vip_tier = '' OR vt.current_tier = v_vip_tier)
      AND (
        v_has_deposits IS NULL OR v_has_deposits = '' OR
        (v_has_deposits = 'true' AND EXISTS (
          SELECT 1 FROM crypto_deposits cd 
          WHERE cd.user_id = up.id 
          AND cd.status IN ('completed', 'confirmed', 'finished', 'partially_paid')
        )) OR
        (v_has_deposits = 'false' AND NOT EXISTS (
          SELECT 1 FROM crypto_deposits cd 
          WHERE cd.user_id = up.id 
          AND cd.status IN ('completed', 'confirmed', 'finished', 'partially_paid')
        ))
      )
      AND (
        v_online_status IS NULL OR v_online_status = '' OR v_online_status = 'all' OR
        (v_online_status = 'online' AND us.is_online = true AND us.heartbeat > NOW() - INTERVAL '2 minutes') OR
        (v_online_status = 'offline' AND (us.user_id IS NULL OR us.is_online = false OR us.heartbeat <= NOW() - INTERVAL '2 minutes'))
      )
    ORDER BY
      CASE WHEN v_sort_by = 'last_activity' AND v_sort_order = 'desc' THEN us.last_activity END DESC NULLS LAST,
      CASE WHEN v_sort_by = 'last_activity' AND v_sort_order = 'asc' THEN us.last_activity END ASC NULLS LAST,
      CASE WHEN v_sort_by = 'total_balance' AND v_sort_order = 'desc' THEN (
        SELECT COALESCE(SUM(w.balance::numeric), 0) FROM wallets w WHERE w.user_id = up.id AND w.currency = 'USDT'
      ) END DESC NULLS LAST,
      CASE WHEN v_sort_by = 'total_balance' AND v_sort_order = 'asc' THEN (
        SELECT COALESCE(SUM(w.balance::numeric), 0) FROM wallets w WHERE w.user_id = up.id AND w.currency = 'USDT'
      ) END ASC NULLS LAST,
      CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'asc' THEN up.created_at END ASC,
      CASE WHEN v_sort_by IS NULL OR v_sort_by = '' OR v_sort_by = 'created_at' THEN up.created_at END DESC
    LIMIT p_limit
    OFFSET p_offset
  ) t;

  RETURN json_build_object('users', COALESCE(v_users, '[]'::json), 'total', v_total);
END;
$$;

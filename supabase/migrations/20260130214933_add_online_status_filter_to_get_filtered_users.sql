/*
  # Add Online Status Filter to get_filtered_users

  1. Changes
    - Add `onlineStatus` filter parameter to filter by online/offline users
    - Join with user_sessions table to determine online status
    - Online = is_online AND heartbeat within last 2 minutes
    - Include is_online and last_activity in returned data

  2. Usage
    - Pass onlineStatus: 'online' to show only online users
    - Pass onlineStatus: 'offline' to show only offline users
    - Pass onlineStatus: 'all' or omit to show all users
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
BEGIN
  IF NOT check_admin_permission('view_users') THEN
    RETURN json_build_object('users', '[]'::json, 'total', 0);
  END IF;

  v_search := p_filters->>'search';
  v_kyc_status := p_filters->>'kycStatus';
  v_vip_tier := p_filters->>'vipTier';
  v_has_deposits := p_filters->>'hasDeposits';
  v_online_status := p_filters->>'onlineStatus';

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
      us.last_activity
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
      )
    ORDER BY up.created_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) t;

  RETURN json_build_object('users', COALESCE(v_users, '[]'::json), 'total', v_total);
END;
$$;

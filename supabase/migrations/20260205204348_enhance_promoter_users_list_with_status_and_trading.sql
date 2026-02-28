/*
  # Enhance Promoter Users List with Online Status, Phone, and Trading Info

  1. Changes
    - Drops and recreates `promoter_get_users_list` to include additional fields:
      - `is_online` (boolean) - Whether the user is currently online (heartbeat within 2 minutes)
      - `last_activity` (timestamptz) - Last activity timestamp from user_sessions
      - `phone` (text) - User phone number from user_profiles
      - `open_positions` (int) - Count of open futures positions (live trading indicator)
      - `copy_trading` (jsonb) - Array of active copy trading relationships with trader names

  2. Security
    - Function remains SECURITY DEFINER with search_path = public
    - All data is scoped to the promoter's referral tree via get_promoter_tree_user_ids
    - Promoter role validation enforced before any data access
*/

CREATE OR REPLACE FUNCTION promoter_get_users_list(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_search text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_users jsonb;
  v_total int;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM get_promoter_tree_user_ids(v_promoter_id) t
  JOIN user_profiles up ON up.id = t.user_id
  LEFT JOIN auth.users au ON au.id = t.user_id
  WHERE (
    p_search IS NULL
    OR up.username ILIKE '%' || p_search || '%'
    OR up.full_name ILIKE '%' || p_search || '%'
    OR au.email ILIKE '%' || p_search || '%'
  );

  SELECT jsonb_agg(row_data ORDER BY created_at DESC) INTO v_users
  FROM (
    SELECT jsonb_build_object(
      'user_id', t.user_id,
      'tree_depth', t.tree_depth,
      'username', up.username,
      'full_name', up.full_name,
      'email', au.email,
      'kyc_status', up.kyc_status,
      'kyc_level', up.kyc_level,
      'country', up.country,
      'phone', up.phone,
      'created_at', up.created_at,
      'total_deposits', COALESCE((
        SELECT SUM(cd.price_amount) FROM crypto_deposits cd
        WHERE cd.user_id = t.user_id
        AND cd.status IN ('finished', 'completed', 'partially_paid', 'overpaid')
      ), 0),
      'total_withdrawals', COALESCE((
        SELECT SUM(tx.amount) FROM transactions tx
        WHERE tx.user_id = t.user_id
        AND tx.transaction_type = 'withdrawal'
        AND tx.status = 'completed'
      ), 0),
      'main_balance', COALESCE((
        SELECT w.balance FROM wallets w
        WHERE w.user_id = t.user_id AND w.wallet_type = 'main' AND w.currency = 'USDT'
      ), 0),
      'is_online', COALESCE(
        us.is_online = true AND us.heartbeat > NOW() - INTERVAL '2 minutes',
        false
      ),
      'last_activity', us.last_activity,
      'open_positions', COALESCE((
        SELECT COUNT(*)::int FROM futures_positions fp
        WHERE fp.user_id = t.user_id AND fp.status = 'open'
      ), 0),
      'copy_trading', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'trader_name', tr.name,
          'trader_id', cr.trader_id,
          'is_mock', cr.is_mock,
          'current_balance', cr.current_balance,
          'cumulative_pnl', cr.cumulative_pnl
        ))
        FROM copy_relationships cr
        JOIN traders tr ON tr.id = cr.trader_id
        WHERE cr.follower_id = t.user_id
          AND cr.is_active = true
          AND cr.status = 'active'
      ), '[]'::jsonb)
    ) AS row_data,
    up.created_at
    FROM get_promoter_tree_user_ids(v_promoter_id) t
    JOIN user_profiles up ON up.id = t.user_id
    LEFT JOIN auth.users au ON au.id = t.user_id
    LEFT JOIN user_sessions us ON us.user_id = t.user_id
    WHERE (
      p_search IS NULL
      OR up.username ILIKE '%' || p_search || '%'
      OR up.full_name ILIKE '%' || p_search || '%'
      OR au.email ILIKE '%' || p_search || '%'
    )
    ORDER BY up.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object(
    'success', true,
    'users', COALESCE(v_users, '[]'::jsonb),
    'total', v_total
  );
END;
$$;

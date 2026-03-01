/*
  # CRM Helper Functions
  
  This migration creates functions for CRM operations.
  
  ## Functions
  
  1. `get_crm_dashboard_stats` - Get real-time CRM dashboard statistics
  2. `evaluate_user_segment` - Check if user matches segment criteria
  3. `get_segment_users` - Get all users in a segment
  4. `capture_daily_crm_snapshot` - Capture daily analytics snapshot
  5. `get_user_with_crm_data` - Get user with all CRM data (tags, notes, etc.)
  6. `execute_bulk_action` - Execute bulk actions on users
*/

-- Get CRM Dashboard Stats
CREATE OR REPLACE FUNCTION get_crm_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_now timestamptz := now();
  v_24h_ago timestamptz := v_now - interval '24 hours';
  v_7d_ago timestamptz := v_now - interval '7 days';
  v_30d_ago timestamptz := v_now - interval '30 days';
BEGIN
  SELECT jsonb_build_object(
    'totalUsers', (SELECT COUNT(*) FROM user_profiles),
    'activeUsers24h', (
      SELECT COUNT(DISTINCT user_id) FROM user_sessions 
      WHERE last_activity > v_24h_ago
    ),
    'activeUsers7d', (
      SELECT COUNT(DISTINCT user_id) FROM user_sessions 
      WHERE last_activity > v_7d_ago
    ),
    'newUsers24h', (
      SELECT COUNT(*) FROM user_profiles 
      WHERE created_at > v_24h_ago
    ),
    'newUsers7d', (
      SELECT COUNT(*) FROM user_profiles 
      WHERE created_at > v_7d_ago
    ),
    'kycPending', (
      SELECT COUNT(*) FROM user_profiles 
      WHERE kyc_status = 'pending'
    ),
    'kycVerified', (
      SELECT COUNT(*) FROM user_profiles 
      WHERE kyc_status = 'verified'
    ),
    'totalDeposits24h', (
      SELECT COALESCE(SUM(amount), 0) FROM transactions 
      WHERE transaction_type = 'deposit' AND created_at > v_24h_ago
    ),
    'totalWithdrawals24h', (
      SELECT COALESCE(SUM(ABS(amount)), 0) FROM transactions 
      WHERE transaction_type = 'withdrawal' AND created_at > v_24h_ago
    ),
    'totalVolume24h', (
      SELECT COALESCE(SUM(position_size), 0) FROM futures_positions 
      WHERE opened_at > v_24h_ago
    ),
    'totalFees24h', (
      SELECT COALESCE(SUM(fee_amount), 0) FROM fee_collections 
      WHERE created_at > v_24h_ago
    ),
    'openSupportTickets', (
      SELECT COUNT(*) FROM support_tickets 
      WHERE status IN ('open', 'in_progress', 'waiting_admin')
    ),
    'avgResponseTime', (
      SELECT EXTRACT(EPOCH FROM AVG(first_response_at - created_at))/60 
      FROM support_tickets 
      WHERE first_response_at IS NOT NULL AND created_at > v_7d_ago
    ),
    'topCountries', (
      SELECT jsonb_agg(row_to_json(c)) FROM (
        SELECT country, COUNT(*) as count 
        FROM user_profiles 
        WHERE country IS NOT NULL 
        GROUP BY country 
        ORDER BY count DESC 
        LIMIT 5
      ) c
    ),
    'vipBreakdown', (
      SELECT jsonb_object_agg(COALESCE(vip_tier, 'Standard'), count) FROM (
        SELECT vip_tier, COUNT(*) as count 
        FROM user_profiles 
        GROUP BY vip_tier
      ) v
    ),
    'recentDeposits', (
      SELECT jsonb_agg(row_to_json(d)) FROM (
        SELECT user_id, amount, currency, created_at 
        FROM transactions 
        WHERE transaction_type = 'deposit' 
        ORDER BY created_at DESC 
        LIMIT 5
      ) d
    ),
    'recentWithdrawals', (
      SELECT jsonb_agg(row_to_json(w)) FROM (
        SELECT user_id, ABS(amount) as amount, currency, created_at 
        FROM transactions 
        WHERE transaction_type = 'withdrawal' 
        ORDER BY created_at DESC 
        LIMIT 5
      ) w
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- Get User with CRM Data
CREATE OR REPLACE FUNCTION get_user_crm_profile(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'profile', (
      SELECT row_to_json(p) FROM (
        SELECT * FROM user_profiles WHERE id = p_user_id
      ) p
    ),
    'tags', (
      SELECT jsonb_agg(row_to_json(t)) FROM (
        SELECT ut.id, ut.name, ut.color, uta.assigned_at
        FROM user_tag_assignments uta
        JOIN user_tags ut ON ut.id = uta.tag_id
        WHERE uta.user_id = p_user_id
      ) t
    ),
    'notes', (
      SELECT jsonb_agg(row_to_json(n)) FROM (
        SELECT un.*, up.username as admin_username
        FROM user_notes un
        LEFT JOIN user_profiles up ON up.id = un.admin_id
        WHERE un.user_id = p_user_id
        ORDER BY un.is_pinned DESC, un.created_at DESC
        LIMIT 20
      ) n
    ),
    'segments', (
      SELECT jsonb_agg(row_to_json(s)) FROM (
        SELECT us.id, us.name, us.description
        FROM user_segment_members usm
        JOIN user_segments us ON us.id = usm.segment_id
        WHERE usm.user_id = p_user_id
      ) s
    ),
    'stats', jsonb_build_object(
      'totalBalance', (
        SELECT COALESCE(SUM(balance), 0) FROM wallets WHERE user_id = p_user_id
      ),
      'totalDeposited', (
        SELECT COALESCE(SUM(total_deposited), 0) FROM wallets WHERE user_id = p_user_id
      ),
      'totalWithdrawn', (
        SELECT COALESCE(SUM(total_withdrawn), 0) FROM wallets WHERE user_id = p_user_id
      ),
      'openPositions', (
        SELECT COUNT(*) FROM futures_positions WHERE user_id = p_user_id AND status = 'open'
      ),
      'totalTrades', (
        SELECT COUNT(*) FROM trades WHERE user_id = p_user_id
      ),
      'lifetimeVolume', (
        SELECT COALESCE(SUM(quantity * price), 0) FROM trades WHERE user_id = p_user_id
      ),
      'referralCount', (
        SELECT total_referrals FROM referral_stats WHERE user_id = p_user_id
      ),
      'supportTicketsOpen', (
        SELECT COUNT(*) FROM support_tickets 
        WHERE user_id = p_user_id AND status NOT IN ('closed', 'resolved')
      )
    ),
    'recentActivity', (
      SELECT jsonb_agg(row_to_json(a)) FROM (
        SELECT action_type, page_url, created_at
        FROM user_activity_logs
        WHERE user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 10
      ) a
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- Capture Daily CRM Snapshot
CREATE OR REPLACE FUNCTION capture_daily_crm_snapshot()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := CURRENT_DATE;
  v_yesterday date := CURRENT_DATE - 1;
BEGIN
  INSERT INTO crm_analytics_snapshots (
    snapshot_date,
    total_users,
    active_users_24h,
    active_users_7d,
    new_users,
    total_deposits,
    total_withdrawals,
    total_trading_volume,
    total_fees_collected,
    kyc_pending_count,
    kyc_verified_count,
    support_tickets_open,
    avg_user_balance,
    metrics
  )
  SELECT
    v_today,
    (SELECT COUNT(*) FROM user_profiles),
    (SELECT COUNT(DISTINCT user_id) FROM user_sessions WHERE last_activity > now() - interval '24 hours'),
    (SELECT COUNT(DISTINCT user_id) FROM user_sessions WHERE last_activity > now() - interval '7 days'),
    (SELECT COUNT(*) FROM user_profiles WHERE created_at::date = v_yesterday),
    (SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE transaction_type = 'deposit' AND created_at::date = v_yesterday),
    (SELECT COALESCE(SUM(ABS(amount)), 0) FROM transactions WHERE transaction_type = 'withdrawal' AND created_at::date = v_yesterday),
    (SELECT COALESCE(SUM(position_size), 0) FROM futures_positions WHERE opened_at::date = v_yesterday),
    (SELECT COALESCE(SUM(fee_amount), 0) FROM fee_collections WHERE created_at::date = v_yesterday),
    (SELECT COUNT(*) FROM user_profiles WHERE kyc_status = 'pending'),
    (SELECT COUNT(*) FROM user_profiles WHERE kyc_status = 'verified'),
    (SELECT COUNT(*) FROM support_tickets WHERE status IN ('open', 'in_progress', 'waiting_admin')),
    (SELECT COALESCE(AVG(balance), 0) FROM wallets WHERE currency = 'USDT'),
    jsonb_build_object(
      'vipDistribution', (
        SELECT jsonb_object_agg(COALESCE(vip_tier, 'Standard'), count) FROM (
          SELECT vip_tier, COUNT(*) as count FROM user_profiles GROUP BY vip_tier
        ) v
      ),
      'countryDistribution', (
        SELECT jsonb_object_agg(country, count) FROM (
          SELECT country, COUNT(*) as count FROM user_profiles WHERE country IS NOT NULL GROUP BY country ORDER BY count DESC LIMIT 10
        ) c
      )
    )
  ON CONFLICT (snapshot_date) DO UPDATE SET
    total_users = EXCLUDED.total_users,
    active_users_24h = EXCLUDED.active_users_24h,
    active_users_7d = EXCLUDED.active_users_7d,
    new_users = EXCLUDED.new_users,
    total_deposits = EXCLUDED.total_deposits,
    total_withdrawals = EXCLUDED.total_withdrawals,
    total_trading_volume = EXCLUDED.total_trading_volume,
    total_fees_collected = EXCLUDED.total_fees_collected,
    kyc_pending_count = EXCLUDED.kyc_pending_count,
    kyc_verified_count = EXCLUDED.kyc_verified_count,
    support_tickets_open = EXCLUDED.support_tickets_open,
    avg_user_balance = EXCLUDED.avg_user_balance,
    metrics = EXCLUDED.metrics;
END;
$$;

-- Execute Bulk Action
CREATE OR REPLACE FUNCTION execute_bulk_action(
  p_admin_id uuid,
  p_action_type text,
  p_user_ids uuid[],
  p_details jsonb DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id uuid;
  v_affected_count integer := 0;
  v_user_id uuid;
BEGIN
  -- Check admin permission
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  
  -- Create bulk action log
  INSERT INTO bulk_action_logs (admin_id, action_type, affected_user_count, affected_user_ids, details, status)
  VALUES (p_admin_id, p_action_type, array_length(p_user_ids, 1), p_user_ids, p_details, 'in_progress')
  RETURNING id INTO v_log_id;
  
  -- Execute action based on type
  CASE p_action_type
    WHEN 'add_tag' THEN
      FOREACH v_user_id IN ARRAY p_user_ids LOOP
        INSERT INTO user_tag_assignments (user_id, tag_id, assigned_by)
        VALUES (v_user_id, (p_details->>'tag_id')::uuid, p_admin_id)
        ON CONFLICT DO NOTHING;
        v_affected_count := v_affected_count + 1;
      END LOOP;
      
    WHEN 'remove_tag' THEN
      DELETE FROM user_tag_assignments 
      WHERE user_id = ANY(p_user_ids) AND tag_id = (p_details->>'tag_id')::uuid;
      GET DIAGNOSTICS v_affected_count = ROW_COUNT;
      
    WHEN 'add_to_segment' THEN
      FOREACH v_user_id IN ARRAY p_user_ids LOOP
        INSERT INTO user_segment_members (segment_id, user_id, added_by)
        VALUES ((p_details->>'segment_id')::uuid, v_user_id, p_admin_id)
        ON CONFLICT DO NOTHING;
        v_affected_count := v_affected_count + 1;
      END LOOP;
      
    WHEN 'remove_from_segment' THEN
      DELETE FROM user_segment_members 
      WHERE user_id = ANY(p_user_ids) AND segment_id = (p_details->>'segment_id')::uuid;
      GET DIAGNOSTICS v_affected_count = ROW_COUNT;
      
    WHEN 'send_notification' THEN
      FOREACH v_user_id IN ARRAY p_user_ids LOOP
        INSERT INTO notifications (user_id, notification_type, title, message, is_read)
        VALUES (
          v_user_id, 
          'system', 
          p_details->>'title', 
          p_details->>'message',
          false
        );
        v_affected_count := v_affected_count + 1;
      END LOOP;
      
    WHEN 'block_withdrawal' THEN
      UPDATE user_profiles 
      SET withdrawal_blocked = true,
          withdrawal_block_reason = p_details->>'reason'
      WHERE id = ANY(p_user_ids);
      GET DIAGNOSTICS v_affected_count = ROW_COUNT;
      
    WHEN 'unblock_withdrawal' THEN
      UPDATE user_profiles 
      SET withdrawal_blocked = false,
          withdrawal_block_reason = NULL
      WHERE id = ANY(p_user_ids);
      GET DIAGNOSTICS v_affected_count = ROW_COUNT;
      
    ELSE
      UPDATE bulk_action_logs 
      SET status = 'failed', error_message = 'Unknown action type'
      WHERE id = v_log_id;
      RETURN jsonb_build_object('success', false, 'error', 'Unknown action type');
  END CASE;
  
  -- Update log with results
  UPDATE bulk_action_logs 
  SET status = 'completed', affected_user_count = v_affected_count
  WHERE id = v_log_id;
  
  RETURN jsonb_build_object(
    'success', true, 
    'affectedCount', v_affected_count,
    'logId', v_log_id
  );
END;
$$;

-- Get Filtered Users for CRM
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
  -- Base query
  v_query := 'SELECT up.*, 
    (SELECT COALESCE(SUM(balance), 0) FROM wallets WHERE user_id = up.id) as total_balance,
    (SELECT COUNT(*) FROM futures_positions WHERE user_id = up.id AND status = ''open'') as open_positions,
    (SELECT array_agg(ut.name) FROM user_tag_assignments uta JOIN user_tags ut ON ut.id = uta.tag_id WHERE uta.user_id = up.id) as tags
    FROM user_profiles up WHERE 1=1';
  
  v_count_query := 'SELECT COUNT(*) FROM user_profiles up WHERE 1=1';
  
  -- Apply filters
  IF p_filters ? 'search' AND p_filters->>'search' != '' THEN
    v_query := v_query || format(' AND (up.username ILIKE ''%%%s%%'' OR up.id::text ILIKE ''%%%s%%'')', 
      p_filters->>'search', p_filters->>'search');
    v_count_query := v_count_query || format(' AND (up.username ILIKE ''%%%s%%'' OR up.id::text ILIKE ''%%%s%%'')', 
      p_filters->>'search', p_filters->>'search');
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
/*
  # Create Promoter RPC Functions

  All scoped data access functions for the Promoter CRM dashboard.
  Every function validates the caller is an active promoter before returning data.

  1. Functions
    - `promoter_get_dashboard_stats` - Earnings calculation and summary stats
    - `promoter_get_users_list` - Paginated user list scoped to tree
    - `promoter_get_deposits` - Read-only deposits for tree users
    - `promoter_get_withdrawals` - Read-only withdrawals for tree users (no status changes)
    - `promoter_get_support_tickets` - Support tickets from tree users
    - `promoter_get_ticket_messages` - Messages for a specific ticket
    - `promoter_send_support_reply` - Send reply as platform (not promoter identity)
    - `promoter_get_referral_tree_stats` - Level-by-level tree breakdown
    - `promoter_get_exclusive_affiliates` - Read-only exclusive affiliates in tree
*/

-- 1. Dashboard stats with earnings formula: (deposits - withdrawals) / 2
CREATE OR REPLACE FUNCTION promoter_get_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_total_deposits numeric := 0;
  v_total_withdrawals numeric := 0;
  v_tree_user_count int := 0;
  v_depositor_count int := 0;
  v_active_traders int := 0;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT COUNT(*) INTO v_tree_user_count
  FROM get_promoter_tree_user_ids(v_promoter_id);

  SELECT COALESCE(SUM(cd.price_amount), 0) INTO v_total_deposits
  FROM crypto_deposits cd
  WHERE cd.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t)
    AND cd.status IN ('finished', 'completed', 'partially_paid', 'overpaid');

  SELECT COALESCE(SUM(t.amount), 0) INTO v_total_withdrawals
  FROM transactions t
  WHERE t.user_id IN (SELECT tr.user_id FROM get_promoter_tree_user_ids(v_promoter_id) tr)
    AND t.transaction_type = 'withdrawal'
    AND t.status = 'completed';

  SELECT COUNT(DISTINCT cd.user_id) INTO v_depositor_count
  FROM crypto_deposits cd
  WHERE cd.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t)
    AND cd.status IN ('finished', 'completed', 'partially_paid', 'overpaid');

  SELECT COUNT(DISTINCT fp.user_id) INTO v_active_traders
  FROM futures_positions fp
  WHERE fp.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t)
    AND fp.status = 'open';

  RETURN jsonb_build_object(
    'success', true,
    'total_deposits', v_total_deposits,
    'total_withdrawals', v_total_withdrawals,
    'earnings', (v_total_deposits - v_total_withdrawals) / 2,
    'tree_user_count', v_tree_user_count,
    'depositor_count', v_depositor_count,
    'active_traders', v_active_traders
  );
END;
$$;

-- 2. Paginated users list scoped to tree
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
      ), 0)
    ) AS row_data,
    up.created_at
    FROM get_promoter_tree_user_ids(v_promoter_id) t
    JOIN user_profiles up ON up.id = t.user_id
    LEFT JOIN auth.users au ON au.id = t.user_id
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

-- 3. Deposits for tree users (read-only)
CREATE OR REPLACE FUNCTION promoter_get_deposits(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 100,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_deposits jsonb;
  v_total int;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM crypto_deposits cd
  WHERE cd.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t)
    AND (p_status IS NULL OR cd.status = p_status);

  SELECT jsonb_agg(
    jsonb_build_object(
      'payment_id', cd.payment_id,
      'user_id', cd.user_id,
      'user_email', au.email,
      'user_name', COALESCE(up.full_name, up.username, 'Unknown'),
      'price_amount', cd.price_amount,
      'price_currency', cd.price_currency,
      'pay_amount', cd.pay_amount,
      'pay_currency', cd.pay_currency,
      'status', cd.status,
      'actually_paid', cd.actually_paid,
      'outcome_amount', cd.outcome_amount,
      'created_at', cd.created_at,
      'completed_at', cd.completed_at,
      'wallet_type', cd.wallet_type
    ) ORDER BY cd.created_at DESC
  ) INTO v_deposits
  FROM crypto_deposits cd
  JOIN auth.users au ON au.id = cd.user_id
  LEFT JOIN user_profiles up ON up.id = cd.user_id
  WHERE cd.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t)
    AND (p_status IS NULL OR cd.status = p_status)
  LIMIT p_limit OFFSET p_offset;

  RETURN jsonb_build_object(
    'success', true,
    'deposits', COALESCE(v_deposits, '[]'::jsonb),
    'total', v_total
  );
END;
$$;

-- 4. Withdrawals for tree users (read-only, no status change capability)
CREATE OR REPLACE FUNCTION promoter_get_withdrawals(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 100,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_withdrawals jsonb;
  v_total int;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM transactions tx
  WHERE tx.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t)
    AND tx.transaction_type = 'withdrawal'
    AND (p_status IS NULL OR tx.status = p_status);

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', tx.id,
      'user_id', tx.user_id,
      'email', au.email,
      'username', up.username,
      'full_name', up.full_name,
      'currency', tx.currency,
      'amount', tx.amount,
      'fee', tx.fee,
      'receive_amount', tx.amount - tx.fee,
      'status', tx.status,
      'address', tx.address,
      'network', tx.network,
      'tx_hash', tx.tx_hash,
      'created_at', tx.created_at,
      'updated_at', tx.updated_at,
      'confirmed_at', tx.confirmed_at
    ) ORDER BY tx.created_at DESC
  ) INTO v_withdrawals
  FROM transactions tx
  JOIN auth.users au ON au.id = tx.user_id
  LEFT JOIN user_profiles up ON up.id = tx.user_id
  WHERE tx.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t)
    AND tx.transaction_type = 'withdrawal'
    AND (p_status IS NULL OR tx.status = p_status)
  LIMIT p_limit OFFSET p_offset;

  RETURN jsonb_build_object(
    'success', true,
    'withdrawals', COALESCE(v_withdrawals, '[]'::jsonb),
    'total', v_total
  );
END;
$$;

-- 5. Support tickets from tree users
CREATE OR REPLACE FUNCTION promoter_get_support_tickets()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_tickets jsonb;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', st.id,
      'user_id', st.user_id,
      'subject', st.subject,
      'status', st.status,
      'priority', st.priority,
      'created_at', st.created_at,
      'updated_at', st.updated_at,
      'first_response_at', st.first_response_at,
      'user_email', au.email,
      'user_username', up.username,
      'unread_count', (
        SELECT COUNT(*) FROM support_messages sm
        WHERE sm.ticket_id = st.id AND sm.sender_type = 'user' AND sm.read_at IS NULL
      ),
      'first_message', (
        SELECT sm.message FROM support_messages sm
        WHERE sm.ticket_id = st.id AND sm.sender_type = 'user'
        ORDER BY sm.created_at ASC LIMIT 1
      )
    ) ORDER BY st.updated_at DESC
  ) INTO v_tickets
  FROM support_tickets st
  JOIN auth.users au ON au.id = st.user_id
  LEFT JOIN user_profiles up ON up.id = st.user_id
  WHERE st.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t);

  RETURN jsonb_build_object(
    'success', true,
    'tickets', COALESCE(v_tickets, '[]'::jsonb)
  );
END;
$$;

-- 6. Get messages for a ticket (only if ticket belongs to tree user)
CREATE OR REPLACE FUNCTION promoter_get_ticket_messages(p_ticket_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_ticket_user_id uuid;
  v_messages jsonb;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT st.user_id INTO v_ticket_user_id
  FROM support_tickets st
  WHERE st.id = p_ticket_id;

  IF v_ticket_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket not found');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM get_promoter_tree_user_ids(v_promoter_id) t
    WHERE t.user_id = v_ticket_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket not in your tree');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', sm.id,
      'sender_id', sm.sender_id,
      'sender_type', sm.sender_type,
      'message', sm.message,
      'created_at', sm.created_at,
      'read_at', sm.read_at
    ) ORDER BY sm.created_at ASC
  ) INTO v_messages
  FROM support_messages sm
  WHERE sm.ticket_id = p_ticket_id
    AND sm.is_internal_note = false;

  UPDATE support_messages
  SET read_at = now()
  WHERE ticket_id = p_ticket_id
    AND sender_type = 'user'
    AND read_at IS NULL;

  RETURN jsonb_build_object(
    'success', true,
    'messages', COALESCE(v_messages, '[]'::jsonb)
  );
END;
$$;

-- 7. Send support reply as platform (hides promoter identity)
CREATE OR REPLACE FUNCTION promoter_send_support_reply(
  p_ticket_id uuid,
  p_message text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_ticket_user_id uuid;
  v_message_id uuid;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT st.user_id INTO v_ticket_user_id
  FROM support_tickets st
  WHERE st.id = p_ticket_id;

  IF v_ticket_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket not found');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM get_promoter_tree_user_ids(v_promoter_id) t
    WHERE t.user_id = v_ticket_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket not in your tree');
  END IF;

  INSERT INTO support_messages (ticket_id, sender_id, sender_type, message, is_internal_note)
  VALUES (p_ticket_id, v_promoter_id, 'admin', p_message, false)
  RETURNING id INTO v_message_id;

  UPDATE support_tickets
  SET status = 'in_progress',
      updated_at = now(),
      first_response_at = COALESCE(first_response_at, now())
  WHERE id = p_ticket_id;

  RETURN jsonb_build_object(
    'success', true,
    'message_id', v_message_id
  );
END;
$$;

-- 8. Referral tree stats broken down by level
CREATE OR REPLACE FUNCTION promoter_get_referral_tree_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_levels jsonb;
  v_total_users int;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'level', level_data.tree_depth,
      'user_count', level_data.user_count,
      'total_deposits', level_data.total_deposits,
      'total_withdrawals', level_data.total_withdrawals
    ) ORDER BY level_data.tree_depth
  ), SUM(level_data.user_count)::int
  INTO v_levels, v_total_users
  FROM (
    SELECT
      t.tree_depth,
      COUNT(*)::int AS user_count,
      COALESCE(SUM((
        SELECT COALESCE(SUM(cd.price_amount), 0)
        FROM crypto_deposits cd
        WHERE cd.user_id = t.user_id
        AND cd.status IN ('finished', 'completed', 'partially_paid', 'overpaid')
      )), 0) AS total_deposits,
      COALESCE(SUM((
        SELECT COALESCE(SUM(tx.amount), 0)
        FROM transactions tx
        WHERE tx.user_id = t.user_id
        AND tx.transaction_type = 'withdrawal'
        AND tx.status = 'completed'
      )), 0) AS total_withdrawals
    FROM get_promoter_tree_user_ids(v_promoter_id) t
    GROUP BY t.tree_depth
  ) level_data;

  RETURN jsonb_build_object(
    'success', true,
    'levels', COALESCE(v_levels, '[]'::jsonb),
    'total_users', COALESCE(v_total_users, 0)
  );
END;
$$;

-- 9. Get users at a specific tree level (for expanding level rows)
CREATE OR REPLACE FUNCTION promoter_get_users_at_level(
  p_level int,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_users jsonb;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'user_id', t.user_id,
      'username', up.username,
      'full_name', up.full_name,
      'email', au.email,
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
      ), 0)
    ) ORDER BY up.created_at DESC
  ) INTO v_users
  FROM get_promoter_tree_user_ids(v_promoter_id) t
  JOIN user_profiles up ON up.id = t.user_id
  LEFT JOIN auth.users au ON au.id = t.user_id
  WHERE t.tree_depth = p_level
  LIMIT p_limit OFFSET p_offset;

  RETURN jsonb_build_object(
    'success', true,
    'users', COALESCE(v_users, '[]'::jsonb)
  );
END;
$$;

-- 10. Exclusive affiliates in tree (read-only)
CREATE OR REPLACE FUNCTION promoter_get_exclusive_affiliates()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promoter_id uuid := auth.uid();
  v_affiliates jsonb;
BEGIN
  IF NOT is_user_promoter(v_promoter_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Promoter access required');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', ea.id,
      'user_id', ea.user_id,
      'username', up.username,
      'full_name', up.full_name,
      'email', au.email,
      'is_active', ea.is_active,
      'deposit_commission_rates', ea.deposit_commission_rates,
      'fee_share_rates', ea.fee_share_rates,
      'copy_profit_rates', ea.copy_profit_rates,
      'created_at', ea.created_at,
      'network_size', (
        SELECT COUNT(*) FROM get_promoter_tree_user_ids(ea.user_id)
      )
    ) ORDER BY ea.created_at DESC
  ) INTO v_affiliates
  FROM exclusive_affiliates ea
  JOIN user_profiles up ON up.id = ea.user_id
  LEFT JOIN auth.users au ON au.id = ea.user_id
  WHERE ea.user_id IN (SELECT t.user_id FROM get_promoter_tree_user_ids(v_promoter_id) t);

  RETURN jsonb_build_object(
    'success', true,
    'affiliates', COALESCE(v_affiliates, '[]'::jsonb)
  );
END;
$$;

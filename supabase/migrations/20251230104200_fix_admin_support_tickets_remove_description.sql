/*
  # Fix Admin Support Tickets Function - Remove Missing Columns

  1. Changes
    - Remove `description` field (doesn't exist in support_tickets table)
    - Change `assigned_to` to `assigned_admin_id` (correct column name)
    - Add first_message field to get ticket description from first message

  2. Notes
    - support_tickets table doesn't have a description column
    - The description is stored as the first support_message
*/

DROP FUNCTION IF EXISTS admin_get_support_tickets_with_users();

CREATE OR REPLACE FUNCTION admin_get_support_tickets_with_users()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  subject text,
  status text,
  priority text,
  category_id uuid,
  assigned_to uuid,
  first_response_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  category_name text,
  category_color_code text,
  user_email text,
  user_username text,
  unread_count bigint,
  admin_unread_by_user bigint,
  first_message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_user_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied. Admin privileges required.';
  END IF;

  RETURN QUERY
  SELECT 
    st.id,
    st.user_id,
    st.subject,
    st.status,
    st.priority,
    st.category_id,
    st.assigned_admin_id as assigned_to,
    st.first_response_at,
    st.resolved_at,
    st.created_at,
    st.updated_at,
    sc.name as category_name,
    sc.color_code as category_color_code,
    au.email as user_email,
    up.username as user_username,
    (
      SELECT COUNT(*)::bigint
      FROM support_messages sm
      WHERE sm.ticket_id = st.id
        AND sm.sender_type = 'user'
        AND sm.read_at IS NULL
    ) as unread_count,
    (
      SELECT COUNT(*)::bigint
      FROM support_messages sm
      WHERE sm.ticket_id = st.id
        AND sm.sender_type = 'admin'
        AND sm.is_internal_note = false
        AND sm.read_at IS NULL
    ) as admin_unread_by_user,
    (
      SELECT sm.message
      FROM support_messages sm
      WHERE sm.ticket_id = st.id
        AND sm.sender_type = 'user'
      ORDER BY sm.created_at ASC
      LIMIT 1
    ) as first_message
  FROM support_tickets st
  LEFT JOIN support_categories sc ON st.category_id = sc.id
  LEFT JOIN auth.users au ON st.user_id = au.id
  LEFT JOIN user_profiles up ON st.user_id = up.id
  ORDER BY st.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_support_tickets_with_users() TO authenticated;

/*
  # Add User Read Tracking for Admin Messages

  1. Changes
    - Add function to mark admin messages as read when user views them
    - Add function to get admin messages with user read status
    - Update admin_get_support_tickets_with_users to include admin unread count

  2. Features
    - Track when users have seen admin responses
    - Show admin which messages users haven't seen yet
    - Auto-mark messages as read when user loads ticket
*/

-- Function to mark admin messages as read when user views the ticket
CREATE OR REPLACE FUNCTION mark_admin_messages_read(p_ticket_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket_user_id uuid;
BEGIN
  SELECT user_id INTO v_ticket_user_id 
  FROM support_tickets 
  WHERE id = p_ticket_id;

  IF v_ticket_user_id IS NULL THEN
    RETURN;
  END IF;

  IF auth.uid() != v_ticket_user_id THEN
    RETURN;
  END IF;

  UPDATE support_messages
  SET read_at = now()
  WHERE ticket_id = p_ticket_id
    AND sender_type = 'admin'
    AND read_at IS NULL;
END;
$$;

-- Function for admins to mark user messages as read
CREATE OR REPLACE FUNCTION mark_user_messages_read(p_ticket_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN;
  END IF;

  UPDATE support_messages
  SET read_at = now()
  WHERE ticket_id = p_ticket_id
    AND sender_type = 'user'
    AND read_at IS NULL;
END;
$$;

-- Function to get messages with read status for admin panel
CREATE OR REPLACE FUNCTION admin_get_ticket_messages(p_ticket_id uuid)
RETURNS TABLE (
  id uuid,
  ticket_id uuid,
  sender_id uuid,
  sender_type text,
  message text,
  is_internal_note boolean,
  created_at timestamptz,
  read_at timestamptz,
  sender_username text,
  is_read_by_recipient boolean
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
    sm.id,
    sm.ticket_id,
    sm.sender_id,
    sm.sender_type,
    sm.message,
    sm.is_internal_note,
    sm.created_at,
    sm.read_at,
    COALESCE(up.username, 'Unknown') as sender_username,
    (sm.read_at IS NOT NULL) as is_read_by_recipient
  FROM support_messages sm
  LEFT JOIN user_profiles up ON sm.sender_id = up.id
  WHERE sm.ticket_id = p_ticket_id
  ORDER BY sm.created_at ASC;
END;
$$;

-- Update admin ticket list to include count of admin messages not yet read by user
DROP FUNCTION IF EXISTS admin_get_support_tickets_with_users();

CREATE OR REPLACE FUNCTION admin_get_support_tickets_with_users()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  subject text,
  description text,
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
  admin_unread_by_user bigint
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
    st.description,
    st.status,
    st.priority,
    st.category_id,
    st.assigned_to,
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
    ) as admin_unread_by_user
  FROM support_tickets st
  LEFT JOIN support_categories sc ON st.category_id = sc.id
  LEFT JOIN auth.users au ON st.user_id = au.id
  LEFT JOIN user_profiles up ON st.user_id = up.id
  ORDER BY st.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_admin_messages_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_user_messages_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_ticket_messages(uuid) TO authenticated;
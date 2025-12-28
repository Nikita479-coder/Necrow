/*
  # Fix Ambiguous Column Reference in Admin Support Tickets

  1. Changes
    - Fix ambiguous column reference by qualifying the table alias
    
  2. Security
    - No security changes
*/

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
  unread_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if the current user is an admin via user_profiles table
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles up
    WHERE up.id = auth.uid() AND up.is_admin = true
  ) THEN
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
    up2.username as user_username,
    (
      SELECT COUNT(*)::bigint
      FROM support_messages sm
      WHERE sm.ticket_id = st.id
      AND sm.sender_type = 'user'
      AND sm.read_at IS NULL
    ) as unread_count
  FROM support_tickets st
  LEFT JOIN support_categories sc ON st.category_id = sc.id
  LEFT JOIN auth.users au ON st.user_id = au.id
  LEFT JOIN user_profiles up2 ON st.user_id = up2.id
  ORDER BY st.created_at DESC;
END;
$$;

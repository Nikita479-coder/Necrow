/*
  # Add Attachments to Admin Support Messages

  1. Changes
    - Drop and recreate admin_get_ticket_messages to include attachment data
    - Returns attachment IDs, file names, and types for each message

  2. Security
    - Maintains existing admin-only access
*/

-- Drop existing function
DROP FUNCTION IF EXISTS admin_get_ticket_messages(uuid);

-- Recreate with attachments
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
  is_read_by_recipient boolean,
  attachments jsonb
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
    (sm.read_at IS NOT NULL) as is_read_by_recipient,
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', sa.id,
            'file_name', sa.file_name,
            'file_size', sa.file_size,
            'mime_type', sa.mime_type,
            'created_at', sa.created_at
          )
        )
        FROM support_attachments sa
        WHERE sa.message_id = sm.id
      ),
      '[]'::jsonb
    ) as attachments
  FROM support_messages sm
  LEFT JOIN user_profiles up ON sm.sender_id = up.id
  WHERE sm.ticket_id = p_ticket_id
  ORDER BY sm.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_ticket_messages(uuid) TO authenticated;

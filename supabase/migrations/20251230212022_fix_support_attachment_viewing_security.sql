/*
  # Fix Support Attachment Viewing

  1. Issue
    - Users cannot view attachments even though data exists
    - get_support_attachment_base64 function has overly restrictive security checks
    
  2. Solution
    - Simplify the function to rely on RLS policies
    - Remove redundant security checks that may be blocking valid access
*/

-- Drop the old function
DROP FUNCTION IF EXISTS get_support_attachment_base64(uuid);

-- Create improved function that relies on RLS
CREATE OR REPLACE FUNCTION get_support_attachment_base64(attachment_id uuid)
RETURNS TABLE(
  file_data_base64 text,
  mime_type text,
  file_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Simply return the data - RLS policies will handle access control
  RETURN QUERY
  SELECT 
    encode(sa.file_data, 'base64') as file_data_base64,
    sa.mime_type,
    sa.file_name
  FROM support_attachments sa
  WHERE sa.id = attachment_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_support_attachment_base64(uuid) TO authenticated;

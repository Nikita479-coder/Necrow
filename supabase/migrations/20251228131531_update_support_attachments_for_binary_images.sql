/*
  # Update Support Attachments for Binary Image Storage

  1. Changes
    - Add `ticket_id` column (foreign key to support_tickets)
    - Add `file_data` column (bytea for binary storage)
    - Remove `file_url` column (we'll store images directly)

  2. Functions
    - `insert_support_attachment` - Insert attachment with binary data
    - `get_support_attachment_base64` - Get attachment as base64

  3. Security
    - Update RLS policies for ticket-based access
*/

-- Add ticket_id column
ALTER TABLE support_attachments 
ADD COLUMN IF NOT EXISTS ticket_id uuid REFERENCES support_tickets(id) ON DELETE CASCADE;

-- Add file_data column for binary storage
ALTER TABLE support_attachments 
ADD COLUMN IF NOT EXISTS file_data bytea;

-- Populate ticket_id from message_id for existing records
UPDATE support_attachments sa
SET ticket_id = sm.ticket_id
FROM support_messages sm
WHERE sa.message_id = sm.id AND sa.ticket_id IS NULL;

-- Make ticket_id required
ALTER TABLE support_attachments 
ALTER COLUMN ticket_id SET NOT NULL;

-- Drop file_url column if it exists (we're using binary storage now)
ALTER TABLE support_attachments 
DROP COLUMN IF EXISTS file_url;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_support_attachments_ticket_id ON support_attachments(ticket_id);

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own ticket attachments" ON support_attachments;
DROP POLICY IF EXISTS "Users can upload to own tickets" ON support_attachments;
DROP POLICY IF EXISTS "Admins can view all attachments" ON support_attachments;
DROP POLICY IF EXISTS "Admins can upload to any ticket" ON support_attachments;

-- Users can view attachments for their own tickets
CREATE POLICY "Users can view own ticket attachments"
  ON support_attachments
  FOR SELECT
  TO authenticated
  USING (
    ticket_id IN (
      SELECT id FROM support_tickets WHERE user_id = auth.uid()
    )
  );

-- Users can upload attachments to their own tickets
CREATE POLICY "Users can upload to own tickets"
  ON support_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid() AND
    ticket_id IN (
      SELECT id FROM support_tickets WHERE user_id = auth.uid()
    )
  );

-- Admins can view all attachments
CREATE POLICY "Admins can view all attachments"
  ON support_attachments
  FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Admins can upload attachments to any ticket
CREATE POLICY "Admins can upload to any ticket"
  ON support_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Function to insert support attachment
CREATE OR REPLACE FUNCTION insert_support_attachment(
  p_ticket_id uuid,
  p_message_id uuid,
  p_file_name text,
  p_file_size bigint,
  p_mime_type text,
  p_file_data_base64 text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_attachment_id uuid;
  v_file_data bytea;
BEGIN
  -- Decode base64 to bytea
  v_file_data := decode(p_file_data_base64, 'base64');
  
  -- Insert attachment
  INSERT INTO support_attachments (
    ticket_id,
    message_id,
    uploaded_by,
    file_name,
    file_size,
    mime_type,
    file_data
  ) VALUES (
    p_ticket_id,
    p_message_id,
    auth.uid(),
    p_file_name,
    p_file_size,
    p_mime_type,
    v_file_data
  )
  RETURNING id INTO v_attachment_id;
  
  RETURN v_attachment_id;
END;
$$;

-- Function to get attachment as base64
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
  RETURN QUERY
  SELECT 
    encode(sa.file_data, 'base64') as file_data_base64,
    sa.mime_type,
    sa.file_name
  FROM support_attachments sa
  WHERE sa.id = attachment_id
    AND (
      sa.ticket_id IN (
        SELECT id FROM support_tickets WHERE user_id = auth.uid()
      )
      OR
      (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
    );
END;
$$;

/*
  # Auto-Delete Old Read Notifications

  ## Summary
  Creates a function and scheduled job to automatically delete notifications
  that have been read and are older than 24 hours.

  ## Changes
  1. Create function to delete old read notifications
  2. This function can be called periodically by a cron job or edge function

  ## How It Works
  - Notifications marked as read are automatically deleted after 24 hours
  - Unread notifications are kept indefinitely
  - This keeps the notifications table clean and performant
*/

-- Function to clean up old read notifications
CREATE OR REPLACE FUNCTION cleanup_old_read_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  -- Delete notifications that are:
  -- 1. Marked as read
  -- 2. Created more than 24 hours ago
  DELETE FROM notifications
  WHERE read = true
    AND created_at < now() - INTERVAL '24 hours';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN deleted_count;
END;
$$;

-- Add a comment explaining the function
COMMENT ON FUNCTION cleanup_old_read_notifications IS 
  'Deletes notifications that have been read and are older than 24 hours. Returns the number of deleted notifications.';

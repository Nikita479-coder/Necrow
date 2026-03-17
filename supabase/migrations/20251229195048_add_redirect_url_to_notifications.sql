/*
  # Add Redirect URL to Notifications

  1. Changes
    - Add `redirect_url` column to notifications table
    - This allows each notification to have an optional redirect path
    - When clicked, notifications can navigate users to relevant pages

  2. Column Details
    - `redirect_url` (text, nullable) - Internal app route to redirect to when clicked
*/

ALTER TABLE notifications
ADD COLUMN IF NOT EXISTS redirect_url text;

COMMENT ON COLUMN notifications.redirect_url IS 'Optional internal app route to redirect to when notification is clicked';
/*
  # Add Admin Insert Policy for Notifications

  ## Problem
  Admin users cannot send notifications to users because there is no
  INSERT policy on the notifications table. Direct inserts from the
  admin panel are blocked by RLS.

  ## Solution
  Add an INSERT policy that allows admin users (identified via JWT
  app_metadata) to insert notifications for any user.
*/

CREATE POLICY "Admins can insert notifications for any user"
  ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    COALESCE(
      (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean,
      false
    )
  );

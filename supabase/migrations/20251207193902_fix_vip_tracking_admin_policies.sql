/*
  # Fix VIP Tracking Admin Policies

  ## Description
  Updates RLS policies for VIP tracking tables to use the correct admin check.
  The admin flag is in app_metadata, not user_metadata.

  ## Changes
  - Drop old policies that check user_metadata
  - Create new policies using is_user_admin() helper function
  - Ensures admin users can properly access VIP tracking data
*/

-- Drop old policies
DROP POLICY IF EXISTS "Admins can view VIP history" ON vip_level_history;
DROP POLICY IF EXISTS "Admins can view VIP downgrades" ON vip_tier_downgrades;
DROP POLICY IF EXISTS "Admins can manage VIP downgrades" ON vip_tier_downgrades;
DROP POLICY IF EXISTS "Admins can view campaigns" ON vip_retention_campaigns;
DROP POLICY IF EXISTS "Admins can manage campaigns" ON vip_retention_campaigns;

-- Create new policies with correct admin check
CREATE POLICY "Admins can view VIP history"
  ON vip_level_history FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

CREATE POLICY "Admins can view VIP downgrades"
  ON vip_tier_downgrades FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

CREATE POLICY "Admins can manage VIP downgrades"
  ON vip_tier_downgrades FOR UPDATE
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

CREATE POLICY "Admins can view campaigns"
  ON vip_retention_campaigns FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

CREATE POLICY "Admins can manage campaigns"
  ON vip_retention_campaigns FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

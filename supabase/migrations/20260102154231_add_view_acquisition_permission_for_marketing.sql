/*
  # Add View Acquisition Permission for Marketing

  1. Changes
    - Add view_acquisition permission
    - Assign to Marketing role
    
  2. Security
    - Marketing can view user acquisition analytics
*/

-- Add the view_acquisition permission if it doesn't exist
INSERT INTO admin_permissions (code, name, description, category)
VALUES ('view_acquisition', 'View Acquisition', 'View user acquisition and visitor analytics', 'Analytics')
ON CONFLICT (code) DO NOTHING;

-- Get the Marketing role ID and assign the permission
DO $$
DECLARE
  v_marketing_role_id uuid;
  v_permission_id uuid;
BEGIN
  -- Get Marketing role ID
  SELECT id INTO v_marketing_role_id FROM admin_roles WHERE name = 'Marketing';
  
  -- Get the permission ID
  SELECT id INTO v_permission_id FROM admin_permissions WHERE code = 'view_acquisition';
  
  -- Assign to Marketing role
  IF v_marketing_role_id IS NOT NULL AND v_permission_id IS NOT NULL THEN
    INSERT INTO admin_role_permissions (role_id, permission_id)
    VALUES (v_marketing_role_id, v_permission_id)
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- Also add to Super Admin role
DO $$
DECLARE
  v_super_admin_role_id uuid;
  v_permission_id uuid;
BEGIN
  -- Get Super Admin role ID
  SELECT id INTO v_super_admin_role_id FROM admin_roles WHERE name = 'Super Admin';
  
  -- Get the permission ID
  SELECT id INTO v_permission_id FROM admin_permissions WHERE code = 'view_acquisition';
  
  -- Assign to Super Admin role
  IF v_super_admin_role_id IS NOT NULL AND v_permission_id IS NOT NULL THEN
    INSERT INTO admin_role_permissions (role_id, permission_id)
    VALUES (v_super_admin_role_id, v_permission_id)
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- Add RLS policy for visitor_sessions table for staff with view_acquisition permission
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'visitor_sessions' 
    AND policyname = 'Staff with view_acquisition can read visitor sessions'
  ) THEN
    CREATE POLICY "Staff with view_acquisition can read visitor sessions"
      ON visitor_sessions
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM admin_staff ast
          WHERE ast.id = auth.uid()
            AND ast.is_active = true
            AND (
              EXISTS (
                SELECT 1 FROM admin_role_permissions arp
                JOIN admin_permissions ap ON ap.id = arp.permission_id
                WHERE arp.role_id = ast.role_id
                  AND ap.code = 'view_acquisition'
              )
              OR
              EXISTS (
                SELECT 1 FROM staff_permission_overrides spo
                JOIN admin_permissions ap ON ap.id = spo.permission_id
                WHERE spo.staff_id = ast.id
                  AND ap.code = 'view_acquisition'
                  AND spo.is_granted = true
              )
            )
        )
      );
  END IF;
END $$;

-- Add RLS policy for campaign_tracking_links table for staff with view_acquisition permission
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'campaign_tracking_links' 
    AND policyname = 'Staff with view_acquisition can read tracking links'
  ) THEN
    CREATE POLICY "Staff with view_acquisition can read tracking links"
      ON campaign_tracking_links
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM admin_staff ast
          WHERE ast.id = auth.uid()
            AND ast.is_active = true
            AND (
              EXISTS (
                SELECT 1 FROM admin_role_permissions arp
                JOIN admin_permissions ap ON ap.id = arp.permission_id
                WHERE arp.role_id = ast.role_id
                  AND ap.code = 'view_acquisition'
              )
              OR
              EXISTS (
                SELECT 1 FROM staff_permission_overrides spo
                JOIN admin_permissions ap ON ap.id = spo.permission_id
                WHERE spo.staff_id = ast.id
                  AND ap.code = 'view_acquisition'
                  AND spo.is_granted = true
              )
            )
        )
      );
  END IF;
END $$;

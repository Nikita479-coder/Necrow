/*
  # Add Staff Deposits View Policy

  1. Changes
    - Add RLS policy for staff members with view_wallets permission to view all deposits
    
  2. Security
    - Only staff with explicit view_wallets permission can see deposits
*/

-- Add policy for staff with view_wallets permission to view all deposits
CREATE POLICY "Staff with view_wallets can view all deposits"
  ON crypto_deposits
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_staff ast
      WHERE ast.id = auth.uid()
        AND ast.is_active = true
        AND (
          -- Check role permissions
          EXISTS (
            SELECT 1 FROM admin_role_permissions arp
            JOIN admin_permissions ap ON ap.id = arp.permission_id
            WHERE arp.role_id = ast.role_id
              AND ap.code = 'view_wallets'
          )
          OR
          -- Check override permissions
          EXISTS (
            SELECT 1 FROM staff_permission_overrides spo
            JOIN admin_permissions ap ON ap.id = spo.permission_id
            WHERE spo.staff_id = ast.id
              AND ap.code = 'view_wallets'
              AND spo.is_granted = true
          )
        )
    )
  );

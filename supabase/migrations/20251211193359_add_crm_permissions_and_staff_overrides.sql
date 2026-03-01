/*
  # Add CRM Permissions and Staff Permission Overrides
  
  ## Description
  This migration adds comprehensive CRM permissions and allows staff members to have
  custom permission overrides beyond their base role.
  
  ## Changes
  1. Add all CRM permissions to admin_permissions table
  2. Create staff_permission_overrides table for custom per-user permissions
  3. Create functions to manage staff permissions
  
  ## Permissions Added
  - User Management: view_users, view_wallets, modify_balances, manage_accounts
  - Transactions: view_transactions
  - Trading: view_trading
  - Risk: view_risk
  - KYC: manage_kyc
  - Email: view_emails, send_emails, manage_email_templates
  - Bonuses: view_bonuses, award_bonuses, manage_bonus_types
  - VIP: view_vip, manage_vip
  - Logs: view_logs
  - Support: manage_support
*/

-- Insert all CRM permissions if they don't exist
INSERT INTO admin_permissions (code, name, category, description) VALUES
  ('view_users', 'View Users', 'User Management', 'View user list and basic info'),
  ('view_wallets', 'View Wallets', 'User Management', 'View user wallet balances'),
  ('modify_balances', 'Modify Balances', 'User Management', 'Adjust user balances'),
  ('manage_accounts', 'Manage Accounts', 'User Management', 'Suspend/activate user accounts'),
  ('view_transactions', 'View Transactions', 'Transactions', 'View deposits, withdrawals, transaction history'),
  ('view_trading', 'View Trading', 'Trading', 'View trading history and positions'),
  ('view_risk', 'View Risk', 'Risk Management', 'View risk scores, alerts, and flags'),
  ('manage_kyc', 'Manage KYC', 'KYC', 'View and update KYC status'),
  ('view_emails', 'View Emails', 'Email', 'View email history'),
  ('send_emails', 'Send Emails', 'Email', 'Send emails to users'),
  ('manage_email_templates', 'Manage Email Templates', 'Email', 'Create/edit email templates'),
  ('view_bonuses', 'View Bonuses', 'Bonuses', 'View bonus history'),
  ('award_bonuses', 'Award Bonuses', 'Bonuses', 'Award bonuses to users'),
  ('manage_bonus_types', 'Manage Bonus Types', 'Bonuses', 'Create/edit bonus types'),
  ('view_vip', 'View VIP', 'VIP', 'View VIP tracking data'),
  ('manage_vip', 'Manage VIP', 'VIP', 'Update VIP levels'),
  ('view_logs', 'View Logs', 'Logs', 'View admin activity, financial, security, system logs'),
  ('manage_support', 'Manage Support', 'Support', 'Handle support tickets')
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  description = EXCLUDED.description;

-- Create table for staff-specific permission overrides
CREATE TABLE IF NOT EXISTS staff_permission_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL REFERENCES admin_staff(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES admin_permissions(id) ON DELETE CASCADE,
  is_granted boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  UNIQUE(staff_id, permission_id)
);

-- Enable RLS
ALTER TABLE staff_permission_overrides ENABLE ROW LEVEL SECURITY;

-- Super admins can manage permission overrides
CREATE POLICY "Super admins can manage permission overrides"
  ON staff_permission_overrides
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_staff_permission_overrides_staff_id 
  ON staff_permission_overrides(staff_id);

-- Function to get staff member's effective permissions (role + overrides)
CREATE OR REPLACE FUNCTION get_staff_effective_permissions(p_staff_id uuid)
RETURNS TABLE (
  permission_code text,
  permission_name text,
  category text,
  granted_by text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only super admins can view this
  IF NOT is_super_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied. Super admin privileges required.';
  END IF;
  
  RETURN QUERY
  WITH role_permissions AS (
    SELECT 
      p.code,
      p.name,
      p.category,
      'Role: ' || r.name as granted_by,
      1 as priority
    FROM admin_staff s
    JOIN admin_roles r ON s.role_id = r.id
    JOIN admin_role_permissions rp ON r.id = rp.role_id
    JOIN admin_permissions p ON rp.permission_id = p.id
    WHERE s.id = p_staff_id
  ),
  override_permissions AS (
    SELECT 
      p.code,
      p.name,
      p.category,
      CASE 
        WHEN spo.is_granted THEN 'Custom: Granted'
        ELSE 'Custom: Revoked'
      END as granted_by,
      2 as priority,
      spo.is_granted
    FROM staff_permission_overrides spo
    JOIN admin_permissions p ON spo.permission_id = p.id
    WHERE spo.staff_id = p_staff_id
  ),
  combined AS (
    SELECT * FROM role_permissions
    UNION ALL
    SELECT code, name, category, granted_by, priority, true as is_granted FROM role_permissions
    WHERE NOT EXISTS (SELECT 1 FROM override_permissions WHERE override_permissions.code = role_permissions.code)
    
    UNION ALL
    
    SELECT code, name, category, granted_by, priority, is_granted FROM override_permissions
  )
  SELECT DISTINCT ON (c.code)
    c.code,
    c.name,
    c.category,
    c.granted_by
  FROM combined c
  WHERE c.is_granted = true
  ORDER BY c.code, c.priority DESC;
END;
$$;

-- Function to set staff permission override
CREATE OR REPLACE FUNCTION set_staff_permission(
  p_staff_id uuid,
  p_permission_code text,
  p_is_granted boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_permission_id uuid;
  v_permission_name text;
BEGIN
  v_admin_id := auth.uid();
  
  -- Only super admins can modify permissions
  IF NOT is_super_admin(v_admin_id) THEN
    RETURN json_build_object('success', false, 'error', 'Access denied. Super admin privileges required.');
  END IF;
  
  -- Get permission ID
  SELECT id, name INTO v_permission_id, v_permission_name
  FROM admin_permissions
  WHERE code = p_permission_code;
  
  IF v_permission_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Permission not found.');
  END IF;
  
  -- Insert or update override
  INSERT INTO staff_permission_overrides (staff_id, permission_id, is_granted, created_by)
  VALUES (p_staff_id, v_permission_id, p_is_granted, v_admin_id)
  ON CONFLICT (staff_id, permission_id) 
  DO UPDATE SET is_granted = p_is_granted;
  
  -- Log the action
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
  VALUES (
    v_admin_id,
    'modify_staff_permission',
    CASE WHEN p_is_granted THEN 'Granted' ELSE 'Revoked' END || ' permission: ' || v_permission_name,
    p_staff_id,
    json_build_object('permission_code', p_permission_code, 'is_granted', p_is_granted)
  );
  
  RETURN json_build_object('success', true, 'message', 'Permission updated successfully.');
END;
$$;

-- Function to remove staff permission override (revert to role default)
CREATE OR REPLACE FUNCTION remove_staff_permission_override(
  p_staff_id uuid,
  p_permission_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_permission_id uuid;
BEGIN
  v_admin_id := auth.uid();
  
  IF NOT is_super_admin(v_admin_id) THEN
    RETURN json_build_object('success', false, 'error', 'Access denied. Super admin privileges required.');
  END IF;
  
  SELECT id INTO v_permission_id
  FROM admin_permissions
  WHERE code = p_permission_code;
  
  IF v_permission_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Permission not found.');
  END IF;
  
  DELETE FROM staff_permission_overrides
  WHERE staff_id = p_staff_id AND permission_id = v_permission_id;
  
  RETURN json_build_object('success', true, 'message', 'Permission override removed. Using role default.');
END;
$$;

-- Function to get all permissions with staff member's current status
CREATE OR REPLACE FUNCTION get_staff_permissions_detail(p_staff_id uuid)
RETURNS TABLE (
  permission_code text,
  permission_name text,
  category text,
  description text,
  has_permission boolean,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_super_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied. Super admin privileges required.';
  END IF;
  
  RETURN QUERY
  SELECT 
    p.code,
    p.name,
    p.category,
    p.description,
    CASE
      -- Check if there's an override
      WHEN spo.is_granted IS NOT NULL THEN spo.is_granted
      -- Otherwise check role permission
      WHEN rp.permission_id IS NOT NULL THEN true
      ELSE false
    END as has_permission,
    CASE
      WHEN spo.is_granted IS NOT NULL THEN 
        CASE WHEN spo.is_granted THEN 'Custom: Granted' ELSE 'Custom: Revoked' END
      WHEN rp.permission_id IS NOT NULL THEN 'From Role: ' || r.name
      ELSE 'Not Granted'
    END as source
  FROM admin_permissions p
  LEFT JOIN admin_staff s ON s.id = p_staff_id
  LEFT JOIN admin_roles r ON s.role_id = r.id
  LEFT JOIN admin_role_permissions rp ON (r.id = rp.role_id AND p.id = rp.permission_id)
  LEFT JOIN staff_permission_overrides spo ON (s.id = spo.staff_id AND p.id = spo.permission_id)
  ORDER BY p.category, p.name;
END;
$$;

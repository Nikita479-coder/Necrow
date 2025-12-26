/*
  # Assign Permissions to Roles
  
  ## Description
  This migration assigns the appropriate CRM permissions to each admin role based on their responsibilities.
  
  ## Role Permissions
  
  ### Financier Role
  - View users, wallets, transactions, trading, risk management
  - Modify balances
  - Manage accounts (suspend/activate)
  - No access to emails, bonuses, or logs
  
  ### Marketing Role
  - View users (basic info)
  - View and send emails
  - Manage email templates
  - View and award bonuses
  - Manage bonus types
  - Limited user data access
  
  ### VIP Manager Role
  - View users, wallets, transactions, trading
  - View VIP tracking data
  - Manage VIP levels
  - View bonuses
*/

-- Get role IDs
DO $$
DECLARE
  v_financier_role_id uuid;
  v_marketing_role_id uuid;
  v_vip_manager_role_id uuid;
  v_permission_id uuid;
BEGIN
  -- Get role IDs
  SELECT id INTO v_financier_role_id FROM admin_roles WHERE name = 'Financier';
  SELECT id INTO v_marketing_role_id FROM admin_roles WHERE name = 'Marketing';
  SELECT id INTO v_vip_manager_role_id FROM admin_roles WHERE name = 'VIP Manager';
  
  -- Clear existing role permissions to start fresh
  DELETE FROM admin_role_permissions WHERE role_id IN (v_financier_role_id, v_marketing_role_id, v_vip_manager_role_id);
  
  -- Financier permissions
  INSERT INTO admin_role_permissions (role_id, permission_id)
  SELECT v_financier_role_id, id FROM admin_permissions WHERE code IN (
    'view_users',
    'view_wallets',
    'modify_balances',
    'manage_accounts',
    'view_transactions',
    'view_trading',
    'view_risk'
  );
  
  -- Marketing permissions
  INSERT INTO admin_role_permissions (role_id, permission_id)
  SELECT v_marketing_role_id, id FROM admin_permissions WHERE code IN (
    'view_users',
    'view_emails',
    'send_emails',
    'manage_email_templates',
    'view_bonuses',
    'award_bonuses',
    'manage_bonus_types'
  );
  
  -- VIP Manager permissions
  INSERT INTO admin_role_permissions (role_id, permission_id)
  SELECT v_vip_manager_role_id, id FROM admin_permissions WHERE code IN (
    'view_users',
    'view_wallets',
    'view_transactions',
    'view_trading',
    'view_bonuses',
    'view_vip',
    'manage_vip'
  );
  
END $$;

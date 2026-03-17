/*
  # Create Admin Role-Based Access Control (RBAC) System

  ## Description
  This migration creates a comprehensive role-based access control system for the CRM.
  It allows the main admin to create staff users with specific roles and permissions.

  ## New Tables

  ### 1. admin_roles
  Defines available staff roles (Admin, Financier, Marketing, VIP Manager)
  - `id` (uuid, primary key)
  - `name` (text, unique) - Role name
  - `description` (text) - Role description
  - `is_system_role` (boolean) - If true, cannot be deleted
  - `created_at` (timestamptz)

  ### 2. admin_permissions
  Defines granular permissions for each feature
  - `id` (uuid, primary key)
  - `code` (text, unique) - Permission code (e.g., 'view_users')
  - `name` (text) - Human readable name
  - `description` (text) - Description of what this permission allows
  - `category` (text) - Category for grouping (users, finance, marketing, etc.)
  - `created_at` (timestamptz)

  ### 3. admin_role_permissions
  Junction table linking roles to their permissions
  - `role_id` (uuid, references admin_roles)
  - `permission_id` (uuid, references admin_permissions)

  ### 4. admin_staff
  Staff accounts with assigned roles
  - `id` (uuid, primary key, references auth.users)
  - `role_id` (uuid, references admin_roles)
  - `is_active` (boolean) - Can be deactivated without deletion
  - `created_by` (uuid) - Admin who created this staff account
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Only super admins (is_admin=true) can manage staff and roles
  - Staff can read their own permissions

  ## Default Data
  - Creates 4 default roles: Super Admin, Financier, Marketing, VIP Manager
  - Creates all necessary permissions
  - Links permissions to roles based on requirements
*/

-- Admin Roles Table
CREATE TABLE IF NOT EXISTS admin_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  is_system_role boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Admin Permissions Table
CREATE TABLE IF NOT EXISTS admin_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  category text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Role-Permissions Junction Table
CREATE TABLE IF NOT EXISTS admin_role_permissions (
  role_id uuid REFERENCES admin_roles(id) ON DELETE CASCADE NOT NULL,
  permission_id uuid REFERENCES admin_permissions(id) ON DELETE CASCADE NOT NULL,
  PRIMARY KEY (role_id, permission_id)
);

-- Admin Staff Table
CREATE TABLE IF NOT EXISTS admin_staff (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id uuid REFERENCES admin_roles(id) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE admin_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_staff ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is super admin
CREATE OR REPLACE FUNCTION is_super_admin(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  is_admin_flag boolean;
BEGIN
  SELECT is_admin INTO is_admin_flag
  FROM user_profiles
  WHERE id = user_id;
  
  RETURN COALESCE(is_admin_flag, false);
END;
$$;

-- RLS Policies for admin_roles
CREATE POLICY "Super admins can manage roles"
  ON admin_roles
  FOR ALL
  TO authenticated
  USING (is_super_admin(auth.uid()))
  WITH CHECK (is_super_admin(auth.uid()));

CREATE POLICY "Staff can view roles"
  ON admin_roles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_staff
      WHERE admin_staff.id = auth.uid()
      AND admin_staff.is_active = true
    )
  );

-- RLS Policies for admin_permissions
CREATE POLICY "Super admins can manage permissions"
  ON admin_permissions
  FOR ALL
  TO authenticated
  USING (is_super_admin(auth.uid()))
  WITH CHECK (is_super_admin(auth.uid()));

CREATE POLICY "Staff can view permissions"
  ON admin_permissions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_staff
      WHERE admin_staff.id = auth.uid()
      AND admin_staff.is_active = true
    )
  );

-- RLS Policies for admin_role_permissions
CREATE POLICY "Super admins can manage role permissions"
  ON admin_role_permissions
  FOR ALL
  TO authenticated
  USING (is_super_admin(auth.uid()))
  WITH CHECK (is_super_admin(auth.uid()));

CREATE POLICY "Staff can view role permissions"
  ON admin_role_permissions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_staff
      WHERE admin_staff.id = auth.uid()
      AND admin_staff.is_active = true
    )
  );

-- RLS Policies for admin_staff
CREATE POLICY "Super admins can manage staff"
  ON admin_staff
  FOR ALL
  TO authenticated
  USING (is_super_admin(auth.uid()))
  WITH CHECK (is_super_admin(auth.uid()));

CREATE POLICY "Staff can view own record"
  ON admin_staff
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Indexes
CREATE INDEX IF NOT EXISTS idx_admin_staff_role_id ON admin_staff(role_id);
CREATE INDEX IF NOT EXISTS idx_admin_staff_is_active ON admin_staff(is_active);
CREATE INDEX IF NOT EXISTS idx_admin_role_permissions_role_id ON admin_role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_admin_permissions_category ON admin_permissions(category);

-- Insert Default Roles
INSERT INTO admin_roles (name, description, is_system_role) VALUES
  ('Super Admin', 'Full access to all features. Can manage staff and system settings.', true),
  ('Financier', 'Access to financial data: deposits, withdrawals, trading history, risk management. No access to emails, bonuses, or logs.', true),
  ('Marketing', 'Access to email templates, send emails, and bonus management. Limited user data access.', true),
  ('VIP Manager', 'Access to VIP tracking, user overview, and VIP-related features.', true)
ON CONFLICT (name) DO NOTHING;

-- Insert All Permissions
INSERT INTO admin_permissions (code, name, description, category) VALUES
  -- User Management
  ('view_users', 'View Users', 'View user list and search users', 'users'),
  ('view_user_details', 'View User Details', 'View detailed user profile information', 'users'),
  ('manage_accounts', 'Manage Accounts', 'Suspend, activate, or modify user accounts', 'users'),
  
  -- Financial
  ('view_wallets', 'View Wallets', 'View user wallet balances', 'finance'),
  ('modify_balances', 'Modify Balances', 'Adjust user wallet balances', 'finance'),
  ('view_transactions', 'View Transactions', 'View deposit, withdrawal, and transaction history', 'finance'),
  ('manage_withdrawals', 'Manage Withdrawals', 'Block or unblock user withdrawals', 'finance'),
  
  -- Trading
  ('view_trading', 'View Trading', 'View trading history and positions', 'trading'),
  ('view_copy_trading', 'View Copy Trading', 'View copy trading relationships and performance', 'trading'),
  ('manage_traders', 'Manage Traders', 'Manage featured traders and trader settings', 'trading'),
  
  -- Risk
  ('view_risk', 'View Risk', 'View risk scores, alerts, and flags', 'risk'),
  ('manage_risk', 'Manage Risk', 'Update risk settings and resolve alerts', 'risk'),
  
  -- KYC
  ('view_kyc', 'View KYC', 'View KYC documents and status', 'kyc'),
  ('manage_kyc', 'Manage KYC', 'Approve, reject, or update KYC status', 'kyc'),
  
  -- Email
  ('view_emails', 'View Emails', 'View email history for users', 'marketing'),
  ('send_emails', 'Send Emails', 'Send emails to users', 'marketing'),
  ('manage_email_templates', 'Manage Email Templates', 'Create and edit email templates', 'marketing'),
  
  -- Bonuses
  ('view_bonuses', 'View Bonuses', 'View bonus history and awards', 'marketing'),
  ('award_bonuses', 'Award Bonuses', 'Award bonuses to users', 'marketing'),
  ('manage_bonus_types', 'Manage Bonus Types', 'Create and edit bonus types', 'marketing'),
  
  -- VIP
  ('view_vip', 'View VIP', 'View VIP tracking and levels', 'vip'),
  ('manage_vip', 'Manage VIP', 'Update VIP levels and settings', 'vip'),
  
  -- Cards
  ('view_shark_cards', 'View Shark Cards', 'View shark card applications and status', 'cards'),
  ('manage_shark_cards', 'Manage Shark Cards', 'Issue and manage shark cards', 'cards'),
  
  -- Support
  ('view_support', 'View Support', 'View support tickets', 'support'),
  ('manage_support', 'Manage Support', 'Respond to and manage support tickets', 'support'),
  
  -- Logs
  ('view_logs', 'View Logs', 'View admin activity, financial, and system logs', 'logs'),
  ('view_function_logs', 'View Function Logs', 'View edge function execution logs', 'logs'),
  
  -- Activity
  ('view_activity', 'View Activity', 'View user live activity and sessions', 'activity'),
  
  -- Staff Management
  ('manage_staff', 'Manage Staff', 'Create, edit, and manage staff accounts', 'admin')
ON CONFLICT (code) DO NOTHING;

-- Link Permissions to Roles
-- Super Admin gets all permissions
INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r, admin_permissions p
WHERE r.name = 'Super Admin'
ON CONFLICT DO NOTHING;

-- Financier Role Permissions
INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r, admin_permissions p
WHERE r.name = 'Financier'
AND p.code IN (
  'view_users',
  'view_user_details',
  'view_wallets',
  'view_transactions',
  'view_trading',
  'view_copy_trading',
  'view_risk',
  'view_kyc',
  'view_activity'
)
ON CONFLICT DO NOTHING;

-- Marketing Role Permissions
INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r, admin_permissions p
WHERE r.name = 'Marketing'
AND p.code IN (
  'view_users',
  'view_user_details',
  'view_emails',
  'send_emails',
  'manage_email_templates',
  'view_bonuses',
  'award_bonuses',
  'manage_bonus_types'
)
ON CONFLICT DO NOTHING;

-- VIP Manager Role Permissions
INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r, admin_permissions p
WHERE r.name = 'VIP Manager'
AND p.code IN (
  'view_users',
  'view_user_details',
  'view_vip',
  'manage_vip',
  'view_wallets',
  'view_bonuses',
  'award_bonuses',
  'view_shark_cards',
  'manage_shark_cards'
)
ON CONFLICT DO NOTHING;

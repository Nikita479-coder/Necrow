/*
  # Create Promoter CRM System

  1. New Tables
    - `promoter_profiles`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users, unique)
      - `is_active` (boolean, default true)
      - `notes` (text, nullable)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. New Role & Permissions
    - Creates "Promoter" admin role
    - Creates "promoter_access" permission
    - Assigns view_users, view_wallets, view_support, manage_support, promoter_access to Promoter role

  3. Staff Enrollment
    - Enrolls Derek (derekbun9@gmail.com) as staff with Promoter role
    - Creates promoter_profiles entry for Derek

  4. Security
    - Enable RLS on promoter_profiles
    - Policies for promoters to view own profile
    - Admin policies for full access

  5. Helper Function
    - `get_promoter_tree_user_ids` - Recursive CTE to walk entire referral tree with no depth cap
    - `is_user_promoter` - Check if user is an active promoter
*/

-- Create promoter_profiles table
CREATE TABLE IF NOT EXISTS promoter_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT promoter_profiles_user_id_unique UNIQUE (user_id)
);

ALTER TABLE promoter_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Promoters can view own profile"
  ON promoter_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage promoter profiles"
  ON promoter_profiles
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid() AND up.is_admin = true
    )
  );

-- Create index on user_profiles.referred_by for tree traversal performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_referred_by ON user_profiles(referred_by);

-- Create "Promoter" role
INSERT INTO admin_roles (name, description, is_system_role)
VALUES ('Promoter', 'Scoped CRM access for promoter partners who manage referral trees', false)
ON CONFLICT DO NOTHING;

-- Create "promoter_access" permission
INSERT INTO admin_permissions (code, name, description, category)
VALUES ('promoter_access', 'Promoter Access', 'Access to the Promoter CRM dashboard', 'promoter')
ON CONFLICT DO NOTHING;

-- Assign permissions to the Promoter role
DO $$
DECLARE
  v_promoter_role_id uuid;
  v_perm_id uuid;
  v_perm_codes text[] := ARRAY['view_users', 'view_wallets', 'view_support', 'manage_support', 'promoter_access'];
  v_code text;
BEGIN
  SELECT id INTO v_promoter_role_id FROM admin_roles WHERE name = 'Promoter';

  IF v_promoter_role_id IS NOT NULL THEN
    FOREACH v_code IN ARRAY v_perm_codes LOOP
      SELECT id INTO v_perm_id FROM admin_permissions WHERE code = v_code;
      IF v_perm_id IS NOT NULL THEN
        INSERT INTO admin_role_permissions (role_id, permission_id)
        VALUES (v_promoter_role_id, v_perm_id)
        ON CONFLICT DO NOTHING;
      END IF;
    END LOOP;
  END IF;
END $$;

-- Enroll Derek as staff with Promoter role
DO $$
DECLARE
  v_derek_id uuid := '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007';
  v_promoter_role_id uuid;
BEGIN
  SELECT id INTO v_promoter_role_id FROM admin_roles WHERE name = 'Promoter';

  IF v_promoter_role_id IS NOT NULL THEN
    INSERT INTO admin_staff (id, role_id, is_active)
    VALUES (v_derek_id, v_promoter_role_id, true)
    ON CONFLICT (id) DO UPDATE SET role_id = v_promoter_role_id, is_active = true;

    INSERT INTO promoter_profiles (user_id, is_active, notes)
    VALUES (v_derek_id, true, 'Initial promoter enrollment')
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
END $$;

-- Helper: Check if a user is an active promoter
CREATE OR REPLACE FUNCTION is_user_promoter(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM promoter_profiles
    WHERE user_id = p_user_id AND is_active = true
  );
END;
$$;

-- Core: Recursive function to get all user IDs in a promoter's referral tree (no depth cap)
CREATE OR REPLACE FUNCTION get_promoter_tree_user_ids(p_promoter_user_id uuid)
RETURNS TABLE(user_id uuid, tree_depth int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE tree AS (
    SELECT up.id AS user_id, 1 AS depth
    FROM user_profiles up
    WHERE up.referred_by = p_promoter_user_id

    UNION ALL

    SELECT up.id AS user_id, t.depth + 1 AS depth
    FROM user_profiles up
    INNER JOIN tree t ON up.referred_by = t.user_id
    WHERE t.depth < 500
  )
  SELECT tree.user_id, tree.depth AS tree_depth
  FROM tree;
END;
$$;

/*
  # Add View Popup Banners Permission for Marketing

  1. New Permissions
    - `view_popup_banners` - Allows viewing all popup banners (read-only)

  2. Changes
    - Assigns permission to marketing role
    - Adds RLS policy for staff to view popup banners

  3. Security
    - Marketing staff can only VIEW banners, not create/edit/delete
*/

-- Add the view_popup_banners permission
INSERT INTO admin_permissions (code, name, description, category)
VALUES ('view_popup_banners', 'View Popup Banners', 'View all popup banners (read-only)', 'marketing')
ON CONFLICT (code) DO NOTHING;

-- Assign to marketing role
INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r, admin_permissions p
WHERE r.name = 'marketing' AND p.code = 'view_popup_banners'
AND NOT EXISTS (
  SELECT 1 FROM admin_role_permissions existing
  WHERE existing.role_id = r.id AND existing.permission_id = p.id
);

-- Add RLS policy for staff with view_popup_banners permission to view all banners
CREATE POLICY "Staff with permission can view all popup banners"
ON popup_banners
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM admin_staff s
    JOIN admin_role_permissions rp ON rp.role_id = s.role_id
    JOIN admin_permissions p ON p.id = rp.permission_id
    WHERE s.id = auth.uid()
      AND s.is_active = true
      AND p.code = 'view_popup_banners'
  )
);

/*
  # Add View Support Permission to Marketing Role

  This migration grants the Marketing staff role access to view support tickets.

  ## Changes
  - Adds view_support permission to Marketing role
  - Adds manage_support permission to Marketing role (to respond to tickets)
*/

INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT 
  r.id as role_id,
  p.id as permission_id
FROM admin_roles r
CROSS JOIN admin_permissions p
WHERE r.name = 'Marketing'
AND p.code IN ('view_support', 'manage_support')
ON CONFLICT DO NOTHING;

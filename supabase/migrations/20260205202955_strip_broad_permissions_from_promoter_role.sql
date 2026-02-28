/*
  # Strip broad permissions from Promoter role

  1. Changes
    - Removes `view_users`, `view_wallets`, `view_support`, and `manage_support`
      permissions from the Promoter role
    - Keeps only `promoter_access` as the sole permission for this role
  
  2. Rationale
    - Promoter-scoped RPC functions use `is_user_promoter()` which checks
      `promoter_profiles`, not admin permissions — so removing these does
      not break the Promoter Dashboard
    - Broad admin permissions were allowing promoters to see the full
      admin user list, deposits, withdrawals, and support tickets
  
  3. Security
    - Promoters can no longer call admin-only RPCs that check for
      `view_users` / `view_wallets` / `view_support` / `manage_support`
*/

DELETE FROM public.admin_role_permissions
WHERE role_id = (
  SELECT id FROM public.admin_roles WHERE name = 'Promoter'
)
AND permission_id IN (
  SELECT id FROM public.admin_permissions
  WHERE code IN ('view_users', 'view_wallets', 'view_support', 'manage_support')
);

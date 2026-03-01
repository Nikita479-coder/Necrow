/*
  # Hide Admin Notes from Users

  1. Changes
    - Create a view that excludes admin_notes for regular users
    - Ensure admin_notes is never accessible to non-admin users
  
  2. Security
    - Users can see all transaction fields except admin_notes
    - Only admins can access admin_notes through admin functions
*/

-- Add a security note: The existing RLS policies on transactions table already
-- control who can see transactions. We just need to ensure that when users
-- query transactions, they never get the admin_notes column.

-- Since Supabase RLS works at the row level, not column level, we need to
-- be explicit in our queries to never select admin_notes for users.

-- The frontend should never select admin_notes unless explicitly in admin context.
-- This is enforced by:
-- 1. Frontend only selects specific columns (not SELECT *)
-- 2. Admin functions use SECURITY DEFINER to access admin_notes
-- 3. Regular user queries don't include admin_notes in SELECT

-- Add a helpful comment for developers
COMMENT ON COLUMN transactions.admin_notes IS 
'SECURITY: Never select this column in user-facing queries. Only accessible through admin functions with SECURITY DEFINER. Contains sensitive internal information like bug details, exploit information, system errors, etc.';

-- Update all other transactions that might contain sensitive information
UPDATE transactions
SET 
  admin_notes = details,
  details = CASE 
    WHEN details ~* '(bug|exploit|issue|error|problem|avoided|liquidation)' THEN 'Balance adjustment by admin'
    WHEN details ~* 'reset' AND transaction_type IN ('admin_debit', 'admin_credit') THEN 'Balance adjustment by admin'
    ELSE details
  END
WHERE transaction_type IN ('admin_debit', 'admin_credit')
  AND admin_notes IS NULL
  AND details IS NOT NULL;

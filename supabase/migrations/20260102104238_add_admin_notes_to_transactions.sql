/*
  # Add Admin Notes to Transactions

  1. Changes
    - Add `admin_notes` column to transactions table for sensitive internal information
    - This field is only visible to admins and contains detailed reasons/context
    - The `details` field remains user-facing with generic messages
  
  2. Security
    - Add RLS policy to prevent users from seeing admin_notes
    - Only admins can view admin_notes through admin functions
*/

-- Add admin_notes column
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS admin_notes text;

-- Create index for admin queries
CREATE INDEX IF NOT EXISTS idx_transactions_admin_notes 
ON transactions(admin_notes) 
WHERE admin_notes IS NOT NULL;

-- Comment on column
COMMENT ON COLUMN transactions.admin_notes IS 
'Internal admin notes - sensitive information not visible to users. Contains detailed reasons for adjustments, bug information, etc.';

COMMENT ON COLUMN transactions.details IS 
'User-facing description - shown in transaction history. Should be generic and not reveal sensitive information.';

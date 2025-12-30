/*
  # Drop Old admin_block_withdrawals Version

  1. Problem
    - Two versions exist with different signatures
    - Old version uses `is_read` (wrong)

  2. Fix
    - Drop the old version with wrong signature
*/

-- Drop the old version with different argument order
DROP FUNCTION IF EXISTS admin_block_withdrawals(uuid, text, uuid);

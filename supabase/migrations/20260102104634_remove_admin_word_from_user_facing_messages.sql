/*
  # Remove Admin Word from User-Facing Messages

  1. Changes
    - Update all user-facing transaction descriptions to remove "admin" references
    - Use generic terms like "Balance adjustment", "Account credit", etc.
  
  2. Security
    - Keep admin notes unchanged (still contain full context)
    - Only change user-visible descriptions
*/

-- Update existing transactions to remove "admin" from details
UPDATE transactions
SET details = CASE
  WHEN details ~* 'balance adjustment by admin' THEN 'Balance adjustment'
  WHEN details ~* 'admin credit' THEN 'Account credit'
  WHEN details ~* 'admin debit' THEN 'Balance adjustment'
  WHEN details ~* 'balance credit by admin' THEN 'Account credit'
  WHEN details ~* 'by admin' THEN REPLACE(details, 'by admin', '')
  WHEN details ~* 'from admin' THEN REPLACE(details, 'from admin', '')
  ELSE details
END
WHERE details IS NOT NULL
  AND details ~* 'admin';

-- Trim any extra spaces
UPDATE transactions
SET details = TRIM(details)
WHERE details IS NOT NULL
  AND details LIKE '% ';

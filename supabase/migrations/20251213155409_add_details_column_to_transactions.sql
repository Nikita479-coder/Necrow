/*
  # Add Details Column to Transactions

  1. Changes
    - Add 'details' text column to transactions table
    - This will store custom descriptions for transactions
    - Used by admin balance adjustments and other transactions that need custom descriptions
*/

ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS details text;

-- Add comment
COMMENT ON COLUMN transactions.details IS 'Custom description or details about the transaction';

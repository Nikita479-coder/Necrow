/*
  # Add New User Exclusive Features to Earn Products

  1. Changes
    - Add `is_new_user_exclusive` boolean column to track special offers for new users
    - Add `eligibility_hours` integer column to specify time window (e.g., 48 hours)
    - Update existing products to set proper min/max amounts for new user exclusives
    - Ensure new user exclusive products have 100 USD min and 300 USD max

  2. Security
    - No changes to RLS policies needed
    - Data integrity maintained with proper defaults
*/

-- Add new columns to earn_products table
ALTER TABLE earn_products 
ADD COLUMN IF NOT EXISTS is_new_user_exclusive boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS eligibility_hours integer DEFAULT NULL;

-- Update the existing "New Users" products to be new user exclusives
UPDATE earn_products
SET 
  is_new_user_exclusive = true,
  eligibility_hours = 48,
  min_amount = 100,
  max_amount = 300
WHERE badge LIKE '%New User%' OR badge LIKE '%Earn New User%';

-- Create an index for faster filtering
CREATE INDEX IF NOT EXISTS idx_earn_products_new_user_exclusive 
ON earn_products(is_new_user_exclusive) 
WHERE is_new_user_exclusive = true;
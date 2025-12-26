/*
  # Fix Copy Relationships Foreign Key Constraint

  1. Changes
    - Drop the incorrect foreign key constraint pointing to copy_traders
    - Add correct foreign key constraint pointing to traders table
    - This allows copy_relationships to reference the correct traders table

  2. Security
    - No changes to RLS policies
    - Maintains data integrity with correct references
*/

-- Drop the incorrect foreign key constraint
ALTER TABLE copy_relationships 
DROP CONSTRAINT IF EXISTS copy_relationships_trader_id_fkey;

-- Add the correct foreign key constraint pointing to traders table
ALTER TABLE copy_relationships
ADD CONSTRAINT copy_relationships_trader_id_fkey 
FOREIGN KEY (trader_id) 
REFERENCES traders(id) 
ON DELETE CASCADE;
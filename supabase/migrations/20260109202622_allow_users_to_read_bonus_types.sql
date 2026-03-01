/*
  # Allow Users to Read Bonus Types

  1. Problem
    - Users cannot claim rewards from the Rewards Hub
    - bonus_types table only has SELECT policy for admins
    - Regular users get "bonus type not found" error when claiming locked bonus rewards

  2. Solution
    - Add RLS policy allowing authenticated users to read active bonus types
    - This allows the frontend to look up bonus type IDs when claiming rewards

  3. Security
    - Users can only SELECT (read), not modify bonus types
    - Keeps admin-only policies for INSERT, UPDATE, DELETE
*/

-- Allow authenticated users to view active bonus types
CREATE POLICY "Users can view active bonus types"
  ON bonus_types
  FOR SELECT
  TO authenticated
  USING (is_active = true);

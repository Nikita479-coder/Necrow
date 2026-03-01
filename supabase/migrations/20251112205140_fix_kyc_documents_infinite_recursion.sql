/*
  # Fix infinite recursion in kyc_documents RLS policies

  1. Changes
    - Drop the problematic admin policies that cause infinite recursion
    - Recreate admin policies using the is_admin() function that bypasses RLS
    
  2. Security
    - Maintains proper access control
    - Admins can view and update all KYC documents
    - Regular users can only access their own documents
*/

-- Drop the problematic policies
DROP POLICY IF EXISTS "Admins can view all documents" ON kyc_documents;
DROP POLICY IF EXISTS "Admins can update all documents" ON kyc_documents;

-- Create new admin policies using the is_admin function (no recursion)
CREATE POLICY "Admins can view all documents"
  ON kyc_documents
  FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE POLICY "Admins can update all documents"
  ON kyc_documents
  FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));
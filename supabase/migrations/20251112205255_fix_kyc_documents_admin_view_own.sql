/*
  # Fix KYC documents policies to allow admins to view their own documents

  1. Changes
    - Update admin SELECT policy to include viewing own documents
    - Combine the logic: admins can view ALL documents OR users can view their own
    
  2. Security
    - Admins can view all documents including their own
    - Regular users can only view their own documents
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own documents" ON kyc_documents;
DROP POLICY IF EXISTS "Admins can view all documents" ON kyc_documents;

-- Create combined policy for viewing documents
CREATE POLICY "Users can view own documents or admins can view all"
  ON kyc_documents
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR is_admin(auth.uid())
  );
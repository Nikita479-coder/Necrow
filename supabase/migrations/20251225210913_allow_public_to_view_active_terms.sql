/*
  # Allow Public Access to Active Terms and Conditions

  1. Security Changes
    - Add policy allowing anonymous users to view active terms
    - Terms and conditions should be publicly accessible for legal compliance

  2. Notes
    - Only active terms are visible to public
    - Admins retain full access to all terms
*/

CREATE POLICY "Public can view active terms"
  ON terms_and_conditions
  FOR SELECT
  TO anon
  USING (is_active = true);

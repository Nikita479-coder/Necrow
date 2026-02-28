/*
  # Fix KYC Documents Table Schema

  1. Changes
    - Drop existing kyc_documents table with incorrect schema
    - Create new kyc_documents table with correct schema for binary file storage
    - Add proper columns: file_name, file_size, mime_type, file_data
    - Enable RLS with proper policies

  2. Security
    - Enable RLS on kyc_documents table
    - Users can only access their own documents
*/

-- Drop the old table
DROP TABLE IF EXISTS kyc_documents CASCADE;

-- Create the correct table
CREATE TABLE kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  document_type text NOT NULL,
  file_name text NOT NULL,
  file_size integer NOT NULL,
  mime_type text NOT NULL,
  file_data bytea NOT NULL,
  uploaded_at timestamptz DEFAULT now(),
  verified boolean DEFAULT false,
  verification_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_document_type CHECK (document_type IN ('id_front', 'id_back', 'selfie', 'proof_address', 'business_doc', 'face_verification'))
);

CREATE INDEX idx_kyc_documents_user_id ON kyc_documents(user_id);
CREATE INDEX idx_kyc_documents_type ON kyc_documents(user_id, document_type);

ALTER TABLE kyc_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own documents"
  ON kyc_documents FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own documents"
  ON kyc_documents FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own documents"
  ON kyc_documents FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own documents"
  ON kyc_documents FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

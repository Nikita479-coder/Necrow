/*
  # Create KYC Documents Storage Table

  1. New Tables
    - `kyc_documents`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to user_profiles)
      - `document_type` (text) - Types: 'id_front', 'id_back', 'selfie', 'proof_address', 'business_doc'
      - `file_name` (text) - Original file name
      - `file_size` (integer) - File size in bytes
      - `mime_type` (text) - File MIME type
      - `file_data` (bytea) - Binary file data stored directly in database
      - `uploaded_at` (timestamptz) - Upload timestamp
      - `verified` (boolean) - Whether document has been verified
      - `verification_notes` (text) - Notes from verification process
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
  
  2. Security
    - Enable RLS on `kyc_documents` table
    - Users can only view their own documents
    - Only authenticated users can insert their own documents
    - Only authenticated users can update their own documents
*/

CREATE TABLE IF NOT EXISTS kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_kyc_documents_user_id ON kyc_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_documents_type ON kyc_documents(user_id, document_type);

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
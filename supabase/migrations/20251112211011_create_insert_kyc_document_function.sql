/*
  # Create Insert KYC Document Function

  1. New Functions
    - `insert_kyc_document` - Properly inserts a KYC document by decoding base64 to bytea
      - Takes base64 string and converts it to binary data
      - Inserts into kyc_documents table with proper binary storage
      
  2. Purpose
    - Fixes the issue where binary data was being JSON-stringified
    - Ensures images are stored as actual bytea for proper retrieval
*/

CREATE OR REPLACE FUNCTION insert_kyc_document(
  p_user_id uuid,
  p_document_type text,
  p_file_name text,
  p_file_size bigint,
  p_mime_type text,
  p_file_data_base64 text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO kyc_documents (
    user_id,
    document_type,
    file_name,
    file_size,
    mime_type,
    file_data
  ) VALUES (
    p_user_id,
    p_document_type,
    p_file_name,
    p_file_size,
    p_mime_type,
    decode(p_file_data_base64, 'base64')
  );
END;
$$;
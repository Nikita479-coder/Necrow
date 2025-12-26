/*
  # Fix insert_kyc_document Function Signature

  1. Changes
    - Drop the incorrect function signature
    - Recreate with the correct parameter order that matches the frontend call
    - Parameters: p_user_id, p_document_type, p_file_name, p_file_size, p_mime_type, p_file_data_base64

  2. Purpose
    - Fix KYC document uploads that are failing due to parameter mismatch
*/

-- Drop all versions of the function
DROP FUNCTION IF EXISTS insert_kyc_document(uuid, text, bytea, text, text);
DROP FUNCTION IF EXISTS insert_kyc_document(uuid, text, text, bigint, text, text);

-- Create the correct function with the signature that matches the frontend
CREATE FUNCTION insert_kyc_document(
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
SET search_path = public
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
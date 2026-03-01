/*
  # Create function to get document as base64
  
  1. New Functions
    - `get_document_base64` - Returns document file_data encoded as base64 string
  
  2. Purpose
    - Properly encode binary data for frontend consumption
    - Avoid issues with bytea hex encoding
*/

CREATE OR REPLACE FUNCTION get_document_base64(doc_id uuid)
RETURNS TABLE (file_data_base64 text, mime_type text) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    encode(file_data, 'base64') as file_data_base64,
    kyc_documents.mime_type
  FROM kyc_documents
  WHERE id = doc_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
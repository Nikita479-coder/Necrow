/*
  # Remove Otto Verification System

  1. Changes
    - Drop otto_verification_sessions table
    - Drop otto_verification_results table
    - These tables were used for external Otto AI face verification
    - Replaced with simple selfie image upload to kyc_documents

  2. Security
    - No RLS changes needed (tables are being removed)
*/

-- Drop Otto verification tables
DROP TABLE IF EXISTS otto_verification_results CASCADE;
DROP TABLE IF EXISTS otto_verification_sessions CASCADE;

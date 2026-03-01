/*
  # Comprehensive Legal Documents System

  1. Changes
    - Add document_type column to terms_and_conditions table
    - Create index on document_type for efficient queries
    - Update existing terms to have document_type 'terms_of_service'
  
  2. Document Types
    - terms_of_service: Main Terms and Conditions
    - privacy_policy: Privacy Policy
    - cookie_policy: Cookie Policy
    - risk_disclosure: Risk Disclosure Statement
    - aml_kyc_policy: AML/KYC Policy
    - trading_rules: Trading Rules and Regulations
    - futures_terms: Futures and Margin Trading Terms
    - copy_trading_terms: Copy Trading Terms
    - staking_terms: Staking and Earn Terms
    - fee_schedule: Fee Schedule
    - referral_terms: Referral Program Terms
    - affiliate_terms: Affiliate Program Terms
    - vip_terms: VIP Program Terms
    - api_terms: API Terms of Use
    - acceptable_use: Acceptable Use Policy
    - dispute_resolution: Dispute Resolution and Arbitration
    - intellectual_property: Intellectual Property Notice
*/

-- Add document_type column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'terms_and_conditions' AND column_name = 'document_type'
  ) THEN
    ALTER TABLE terms_and_conditions ADD COLUMN document_type text DEFAULT 'terms_of_service';
  END IF;
END $$;

-- Update existing terms to have document_type
UPDATE terms_and_conditions 
SET document_type = 'terms_of_service' 
WHERE document_type IS NULL;

-- Create index for document_type
CREATE INDEX IF NOT EXISTS idx_terms_document_type ON terms_and_conditions(document_type);

-- Remove unique constraint on version if it exists (to allow same version across document types)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'terms_and_conditions_version_key'
  ) THEN
    ALTER TABLE terms_and_conditions DROP CONSTRAINT terms_and_conditions_version_key;
  END IF;
END $$;

-- Add unique constraint on version + document_type
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'terms_and_conditions_version_document_type_key'
  ) THEN
    ALTER TABLE terms_and_conditions 
    ADD CONSTRAINT terms_and_conditions_version_document_type_key 
    UNIQUE (version, document_type);
  END IF;
END $$;
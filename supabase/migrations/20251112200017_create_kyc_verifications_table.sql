/*
  # Create KYC Verifications Table

  1. New Tables
    - `kyc_verifications`
      - `user_id` (uuid, primary key, references auth.users)
      - `verification_type` (text) - 'individual' or 'business'
      - `kyc_level` (integer) - 0=none, 1=basic, 2=intermediate, 3=advanced, 4=entity
      - `kyc_status` (text) - 'pending', 'approved', 'rejected'
      - Individual fields: first_name, last_name, date_of_birth, nationality, address, city, postal_code, country, id_type
      - Business fields: company_name, company_country, incorporation_date, business_nature, tax_id
      - Timestamps: created_at, updated_at

  2. Security
    - Enable RLS on `kyc_verifications` table
    - Add policy for users to read their own KYC data
    - Add policy for users to insert/update their own KYC data
*/

CREATE TABLE IF NOT EXISTS kyc_verifications (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  verification_type text NOT NULL DEFAULT 'individual',
  kyc_level integer NOT NULL DEFAULT 0,
  kyc_status text NOT NULL DEFAULT 'pending',
  
  -- Individual verification fields
  first_name text,
  last_name text,
  date_of_birth date,
  nationality text,
  address text,
  city text,
  postal_code text,
  country text,
  id_type text,
  
  -- Business verification fields
  company_name text,
  company_country text,
  incorporation_date date,
  business_nature text,
  tax_id text,
  
  -- Timestamps
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE kyc_verifications ENABLE ROW LEVEL SECURITY;

-- Policy for users to read their own KYC data
CREATE POLICY "Users can read own KYC data"
  ON kyc_verifications
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Policy for users to insert their own KYC data
CREATE POLICY "Users can insert own KYC data"
  ON kyc_verifications
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy for users to update their own KYC data
CREATE POLICY "Users can update own KYC data"
  ON kyc_verifications
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_kyc_verifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_kyc_verifications_updated_at
  BEFORE UPDATE ON kyc_verifications
  FOR EACH ROW
  EXECUTE FUNCTION update_kyc_verifications_updated_at();

/*
  # Add Geographic Restrictions to Bonus Types

  1. Changes
    - Add allowed_countries column to bonus_types table
    - Add excluded_countries column to bonus_types table
    - Update Trustpilot Review Bonus to only allow Asian countries

  2. Logic
    - If allowed_countries is set, only users from those countries can receive bonus
    - If excluded_countries is set, users from those countries cannot receive bonus
    - Country codes use ISO 3166-1 alpha-2 format (e.g., 'IN', 'PK', 'BD', 'ID')
*/

-- Add geo-restriction columns to bonus_types
ALTER TABLE bonus_types
ADD COLUMN IF NOT EXISTS allowed_countries TEXT[],
ADD COLUMN IF NOT EXISTS excluded_countries TEXT[];

-- Update Trustpilot Review Bonus to only allow Asian countries
UPDATE bonus_types
SET allowed_countries = ARRAY['IN', 'PK', 'BD', 'ID', 'MY', 'TH', 'VN', 'PH', 'LK', 'NP']
WHERE name = 'Trustpilot Review Bonus';

-- Add comment explaining the columns
COMMENT ON COLUMN bonus_types.allowed_countries IS 'ISO 3166-1 alpha-2 country codes. If set, only users from these countries can receive this bonus.';
COMMENT ON COLUMN bonus_types.excluded_countries IS 'ISO 3166-1 alpha-2 country codes. If set, users from these countries cannot receive this bonus.';

/*
  # Fix Users with Verified Documents Not Upgraded to Level 2

  1. Purpose
    - Find all users who have 2 or more verified KYC documents
    - But are still at KYC level < 2
    - Upgrade them to level 2 with status 'verified'
    - The existing trigger will automatically award the $20 KYC bonus

  2. Changes
    - Update user_profiles for users with 2+ verified documents
    - Set kyc_level = 2 and kyc_status = 'verified'
*/

-- Find and upgrade users with 2+ verified documents who aren't at level 2
WITH users_to_upgrade AS (
  SELECT 
    kd.user_id,
    COUNT(DISTINCT kd.id) as verified_count
  FROM kyc_documents kd
  WHERE kd.verified = true
    AND kd.document_type != 'face_verification'
  GROUP BY kd.user_id
  HAVING COUNT(DISTINCT kd.id) >= 2
)
UPDATE user_profiles
SET 
  kyc_level = 2,
  kyc_status = 'verified',
  updated_at = now()
WHERE id IN (SELECT user_id FROM users_to_upgrade)
  AND (kyc_level < 2 OR kyc_status != 'verified')
RETURNING id, username, full_name, kyc_level, kyc_status;

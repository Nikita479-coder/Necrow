/*
  # Add User Details and Wallets Permissions for Marketing Staff

  1. Changes
    - Add `view_user_details` permission to marketing staff (Derekbun9@gmail.com)
    - Add `view_wallets` permission to marketing staff (for deposits page access)
    - These allow viewing user profiles (with phone masked) and deposits page

  2. Security
    - Phone numbers remain masked via the PhoneRevealButton component
    - Staff must still request access to reveal phone numbers
*/

-- Add view_user_details permission for marketing staff
INSERT INTO staff_permission_overrides (id, staff_id, permission_id, is_granted, created_at)
VALUES (
  gen_random_uuid(),
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007',
  '698550c2-4250-47d5-a665-2316587d2d50',
  true,
  now()
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

-- Add view_wallets permission for marketing staff (for deposits page)
INSERT INTO staff_permission_overrides (id, staff_id, permission_id, is_granted, created_at)
VALUES (
  gen_random_uuid(),
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007',
  'b2f8ef7e-5c46-49f4-b455-4a026eb78f77',
  true,
  now()
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

/*
  # Add Marketing Staff Member - Derekbun9@gmail.com

  ## Overview
  Adds the user Derekbun9@gmail.com as a staff member with Marketing role
  and specific permission overrides for:
  - CRM access with phone masking
  - Support ticket management
  - User acquisition and referral tracking
  - Phone reveal request capability

  ## Changes
  1. Add user to admin_staff with Marketing role
  2. Add permission overrides for specific access
  3. All actions will be logged in staff_activity_logs

  ## Security Note
  - User cannot see full phone numbers (masked only)
  - User must request phone reveal from super admin
  - All activities are logged
*/

-- Add user as staff member with Marketing role
INSERT INTO admin_staff (id, role_id, is_active)
VALUES (
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007'::uuid,
  'f740d0b1-ca6e-473e-a6f9-4de079129241'::uuid,
  true
)
ON CONFLICT (id) DO UPDATE SET
  role_id = 'f740d0b1-ca6e-473e-a6f9-4de079129241'::uuid,
  is_active = true,
  updated_at = now();

-- Add permission overrides for this staff member
-- View Users permission
INSERT INTO staff_permission_overrides (staff_id, permission_id, is_granted)
VALUES (
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007'::uuid,
  'be86e03a-ed93-47c4-8391-fa2b3be7cc48'::uuid,
  true
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

-- View Transactions permission
INSERT INTO staff_permission_overrides (staff_id, permission_id, is_granted)
VALUES (
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007'::uuid,
  '907ee52a-6265-4c1e-9858-0bed685b35e8'::uuid,
  true
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

-- Send Emails permission
INSERT INTO staff_permission_overrides (staff_id, permission_id, is_granted)
VALUES (
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007'::uuid,
  '8a7140e8-e727-4409-a324-93558915c75c'::uuid,
  true
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

-- Manage Support permission
INSERT INTO staff_permission_overrides (staff_id, permission_id, is_granted)
VALUES (
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007'::uuid,
  '53fd4fcd-2f7b-4769-ae54-6636880ccbe2'::uuid,
  true
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

-- View Phones Masked permission
INSERT INTO staff_permission_overrides (staff_id, permission_id, is_granted)
VALUES (
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007'::uuid,
  '473dc658-f075-492e-a342-5ee30af6d151'::uuid,
  true
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

-- Request Phone Reveal permission
INSERT INTO staff_permission_overrides (staff_id, permission_id, is_granted)
VALUES (
  '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007'::uuid,
  '3aa70b9f-61e7-4367-bcea-138fe845f936'::uuid,
  true
)
ON CONFLICT (staff_id, permission_id) DO UPDATE SET is_granted = true;

-- Log the action
INSERT INTO admin_activity_logs (admin_id, action_type, action_description, metadata)
SELECT 
  (SELECT id FROM user_profiles WHERE is_admin = true LIMIT 1),
  'staff_added',
  'Added marketing staff member with CRM access and phone masking',
  jsonb_build_object(
    'staff_user_id', '9c4f9d1a-7b39-4767-9ac9-fdb52c6f2007',
    'role', 'Marketing',
    'permissions', ARRAY['view_users', 'view_transactions', 'send_emails', 'manage_support', 'view_phones_masked', 'request_phone_reveal']
  );

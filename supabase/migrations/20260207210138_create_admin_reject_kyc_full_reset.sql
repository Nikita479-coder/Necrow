/*
  # Create Admin KYC Full Reset Function

  1. Changes
    - Add `rejection_reason` column to `kyc_verifications` table to store why KYC was rejected
    - Create `admin_reject_kyc_full_reset` function that:
      - Resets KYC level to 0 in both user_profiles and kyc_verifications
      - Clears all personal information (name, DOB, address, etc.)
      - Marks all documents as rejected (keeps for audit)
      - Clears otto_session_id to allow fresh face verification
      - Deletes otto verification results/sessions so user can retry
      - Stores rejection reason for user to see
      - Sends notification to user

  2. Security
    - Function is SECURITY DEFINER to allow admin access
    - Only users with admin role can execute
*/

-- Add rejection_reason column to kyc_verifications if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'kyc_verifications' AND column_name = 'rejection_reason'
  ) THEN
    ALTER TABLE kyc_verifications ADD COLUMN rejection_reason text;
  END IF;
END $$;

-- Create the admin KYC full reset function
CREATE OR REPLACE FUNCTION admin_reject_kyc_full_reset(
  p_user_id uuid,
  p_rejection_reason text DEFAULT 'Your KYC verification has been rejected. Please submit new documents.'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_id uuid;
  v_is_admin boolean;
  v_user_email text;
  v_docs_updated int;
BEGIN
  -- Get current user
  v_admin_id := auth.uid();
  
  -- Check if user is admin
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = v_admin_id AND is_admin = true
  ) OR EXISTS (
    SELECT 1 FROM admin_staff 
    WHERE user_id = v_admin_id AND is_active = true
  ) INTO v_is_admin;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;
  
  -- Get user email for logging
  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = p_user_id;
  
  IF v_user_email IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  -- 1. Update user_profiles - reset KYC status and level
  UPDATE user_profiles
  SET 
    kyc_status = 'rejected',
    kyc_level = 0,
    kyc_verified_at = NULL,
    updated_at = now()
  WHERE id = p_user_id;
  
  -- 2. Update kyc_verifications - clear all personal info and reset level
  UPDATE kyc_verifications
  SET
    kyc_level = 0,
    kyc_status = 'rejected',
    rejection_reason = p_rejection_reason,
    -- Clear personal information
    first_name = NULL,
    last_name = NULL,
    date_of_birth = NULL,
    nationality = NULL,
    address = NULL,
    city = NULL,
    postal_code = NULL,
    country = NULL,
    id_type = NULL,
    -- Clear business information
    company_name = NULL,
    company_country = NULL,
    incorporation_date = NULL,
    business_nature = NULL,
    tax_id = NULL,
    -- Clear otto session to allow fresh verification
    otto_session_id = NULL,
    updated_at = now()
  WHERE user_id = p_user_id;
  
  -- If no kyc_verifications record exists, create one with rejected status
  INSERT INTO kyc_verifications (user_id, kyc_level, kyc_status, rejection_reason)
  VALUES (p_user_id, 0, 'rejected', p_rejection_reason)
  ON CONFLICT (user_id) DO NOTHING;
  
  -- 3. Mark all KYC documents as rejected (keep for audit)
  UPDATE kyc_documents
  SET 
    verified = false,
    verification_notes = COALESCE(verification_notes || ' | ', '') || 'Rejected: ' || p_rejection_reason,
    updated_at = now()
  WHERE user_id = p_user_id;
  
  GET DIAGNOSTICS v_docs_updated = ROW_COUNT;
  
  -- 4. Delete otto verification results and sessions to allow fresh verification
  DELETE FROM otto_verification_results
  WHERE user_id = p_user_id;
  
  DELETE FROM otto_verification_sessions
  WHERE user_id = p_user_id;
  
  -- 5. Create notification for user
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    read
  ) VALUES (
    p_user_id,
    'system',
    'KYC Verification Rejected',
    p_rejection_reason || ' Please submit new documents to complete verification.',
    false
  );
  
  -- 6. Log admin action
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details,
    created_at
  ) VALUES (
    v_admin_id,
    'kyc_rejected_full_reset',
    p_user_id,
    jsonb_build_object(
      'reason', p_rejection_reason,
      'user_email', v_user_email,
      'documents_marked_rejected', v_docs_updated
    ),
    now()
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'KYC fully reset for user',
    'user_id', p_user_id,
    'documents_rejected', v_docs_updated
  );
END;
$$;

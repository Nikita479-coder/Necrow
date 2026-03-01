/*
  # Fix admin_reject_kyc_full_reset function

  1. Changes
    - Remove references to deleted otto_verification_results and otto_verification_sessions tables
    - Fix admin logging to use correct table name (admin_activity_logs) and column (metadata)
    - Fix notification type column from 'type' to match valid check constraint values

  2. Notes
    - The otto verification system was removed in a previous migration
    - The admin_action_logs table doesn't exist; the correct table is admin_activity_logs
*/

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
  v_admin_id := auth.uid();
  
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
  
  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = p_user_id;
  
  IF v_user_email IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  UPDATE user_profiles
  SET 
    kyc_status = 'rejected',
    kyc_level = 0,
    kyc_verified_at = NULL,
    updated_at = now()
  WHERE id = p_user_id;
  
  UPDATE kyc_verifications
  SET
    kyc_level = 0,
    kyc_status = 'rejected',
    rejection_reason = p_rejection_reason,
    first_name = NULL,
    last_name = NULL,
    date_of_birth = NULL,
    nationality = NULL,
    address = NULL,
    city = NULL,
    postal_code = NULL,
    country = NULL,
    id_type = NULL,
    company_name = NULL,
    company_country = NULL,
    incorporation_date = NULL,
    business_nature = NULL,
    tax_id = NULL,
    otto_session_id = NULL,
    updated_at = now()
  WHERE user_id = p_user_id;
  
  INSERT INTO kyc_verifications (user_id, kyc_level, kyc_status, rejection_reason)
  VALUES (p_user_id, 0, 'rejected', p_rejection_reason)
  ON CONFLICT (user_id) DO NOTHING;
  
  UPDATE kyc_documents
  SET 
    verified = false,
    verification_notes = COALESCE(verification_notes || ' | ', '') || 'Rejected: ' || p_rejection_reason,
    updated_at = now()
  WHERE user_id = p_user_id;
  
  GET DIAGNOSTICS v_docs_updated = ROW_COUNT;
  
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
  
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    target_user_id,
    action_description,
    metadata,
    created_at
  ) VALUES (
    v_admin_id,
    'kyc_rejected_full_reset',
    p_user_id,
    'KYC rejected and reset for user ' || v_user_email,
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

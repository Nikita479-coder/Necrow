/*
  # Enhance IP Verification System and Create Functions

  ## Description
  Adds missing columns to ip_verification_codes table and creates all the 
  necessary RPC functions for the trusted devices system.

  ## Changes
  1. Add missing columns to ip_verification_codes (email, device_info, location, attempts)
  2. Drop and recreate functions with proper signatures
  3. Create check_ip_trusted function
  4. Create log_login_attempt function
  5. Create add_trusted_ip function
  6. Create revoke_trusted_ip function
  7. Create cleanup_expired_verification_codes function

  ## Security
  All functions use SECURITY DEFINER with explicit search_path
*/

-- Add missing columns to ip_verification_codes if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ip_verification_codes' AND column_name = 'email'
  ) THEN
    ALTER TABLE ip_verification_codes ADD COLUMN email text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ip_verification_codes' AND column_name = 'device_info'
  ) THEN
    ALTER TABLE ip_verification_codes ADD COLUMN device_info text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ip_verification_codes' AND column_name = 'location'
  ) THEN
    ALTER TABLE ip_verification_codes ADD COLUMN location jsonb DEFAULT '{}';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ip_verification_codes' AND column_name = 'attempts'
  ) THEN
    ALTER TABLE ip_verification_codes ADD COLUMN attempts integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ip_verification_codes' AND column_name = 'max_attempts'
  ) THEN
    ALTER TABLE ip_verification_codes ADD COLUMN max_attempts integer DEFAULT 5;
  END IF;
END $$;

-- Drop existing functions to recreate with correct signatures
DROP FUNCTION IF EXISTS check_ip_trusted(uuid, text);
DROP FUNCTION IF EXISTS log_login_attempt(uuid, text, text, jsonb, boolean, boolean);
DROP FUNCTION IF EXISTS add_trusted_ip(uuid, text, text, jsonb, integer);
DROP FUNCTION IF EXISTS revoke_trusted_ip(uuid);
DROP FUNCTION IF EXISTS create_ip_verification_code(uuid, text, text, text, jsonb);
DROP FUNCTION IF EXISTS verify_ip_code(uuid, text, integer);
DROP FUNCTION IF EXISTS cleanup_expired_verification_codes();

-- Function to check if an IP is trusted for a user
CREATE OR REPLACE FUNCTION check_ip_trusted(
  p_user_id uuid,
  p_ip_address text
)
RETURNS jsonb AS $$
DECLARE
  v_trusted_ip record;
  v_is_first_login boolean;
BEGIN
  -- Check if user has any trusted IPs (first login check)
  SELECT NOT EXISTS (
    SELECT 1 FROM trusted_ips 
    WHERE user_id = p_user_id AND is_trusted = true
  ) INTO v_is_first_login;

  -- If this is the user's first login, automatically trust this IP
  IF v_is_first_login THEN
    RETURN jsonb_build_object(
      'is_trusted', true,
      'is_first_login', true,
      'message', 'First login - IP automatically trusted'
    );
  END IF;

  -- Look for an existing trusted IP entry
  SELECT * INTO v_trusted_ip
  FROM trusted_ips
  WHERE user_id = p_user_id
    AND ip_address = p_ip_address
    AND is_trusted = true
    AND (trust_expires_at IS NULL OR trust_expires_at > now());

  IF FOUND THEN
    -- Update last_used timestamp
    UPDATE trusted_ips
    SET last_used = now()
    WHERE id = v_trusted_ip.id;

    RETURN jsonb_build_object(
      'is_trusted', true,
      'trusted_ip_id', v_trusted_ip.id,
      'first_seen', v_trusted_ip.first_seen,
      'trust_expires_at', v_trusted_ip.trust_expires_at
    );
  END IF;

  -- IP is not trusted
  RETURN jsonb_build_object(
    'is_trusted', false,
    'message', 'IP address not recognized. Verification required.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to log login attempts
CREATE OR REPLACE FUNCTION log_login_attempt(
  p_user_id uuid,
  p_ip_address text,
  p_device_info text DEFAULT NULL,
  p_location jsonb DEFAULT '{}',
  p_success boolean DEFAULT false,
  p_requires_verification boolean DEFAULT false
)
RETURNS uuid AS $$
DECLARE
  v_attempt_id uuid;
BEGIN
  INSERT INTO login_attempts (
    user_id,
    ip_address,
    device_info,
    location,
    success,
    requires_verification
  ) VALUES (
    p_user_id,
    p_ip_address,
    p_device_info,
    p_location,
    p_success,
    p_requires_verification
  )
  RETURNING id INTO v_attempt_id;

  RETURN v_attempt_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to add a trusted IP after verification
CREATE OR REPLACE FUNCTION add_trusted_ip(
  p_user_id uuid,
  p_ip_address text,
  p_device_info text DEFAULT NULL,
  p_location jsonb DEFAULT '{}',
  p_trust_duration_days integer DEFAULT 30
)
RETURNS uuid AS $$
DECLARE
  v_trusted_ip_id uuid;
  v_expires_at timestamptz;
BEGIN
  -- Calculate expiration
  IF p_trust_duration_days IS NOT NULL AND p_trust_duration_days > 0 THEN
    v_expires_at := now() + (p_trust_duration_days || ' days')::interval;
  ELSE
    v_expires_at := NULL; -- Never expires
  END IF;

  -- Check if entry exists
  SELECT id INTO v_trusted_ip_id
  FROM trusted_ips
  WHERE user_id = p_user_id AND ip_address = p_ip_address;

  IF FOUND THEN
    -- Update existing entry
    UPDATE trusted_ips
    SET device_info = COALESCE(p_device_info, device_info),
        location = COALESCE(p_location, location),
        last_used = now(),
        trust_expires_at = v_expires_at,
        is_trusted = true,
        updated_at = now()
    WHERE id = v_trusted_ip_id;
  ELSE
    -- Insert new entry
    INSERT INTO trusted_ips (
      user_id,
      ip_address,
      device_info,
      location,
      first_seen,
      last_used,
      trust_expires_at,
      is_trusted
    ) VALUES (
      p_user_id,
      p_ip_address,
      p_device_info,
      p_location,
      now(),
      now(),
      v_expires_at,
      true
    )
    RETURNING id INTO v_trusted_ip_id;
  END IF;

  RETURN v_trusted_ip_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to revoke a trusted IP
CREATE OR REPLACE FUNCTION revoke_trusted_ip(
  p_trusted_ip_id uuid
)
RETURNS boolean AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get the user_id to verify ownership
  SELECT user_id INTO v_user_id
  FROM trusted_ips
  WHERE id = p_trusted_ip_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trusted IP not found';
  END IF;

  -- Verify the caller owns this trusted IP
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to revoke this trusted IP';
  END IF;

  -- Mark as not trusted instead of deleting (for audit trail)
  UPDATE trusted_ips
  SET is_trusted = false,
      updated_at = now()
  WHERE id = p_trusted_ip_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to create a verification code
CREATE OR REPLACE FUNCTION create_ip_verification_code(
  p_user_id uuid,
  p_email text,
  p_ip_address text,
  p_device_info text DEFAULT NULL,
  p_location jsonb DEFAULT '{}'
)
RETURNS text AS $$
DECLARE
  v_code text;
BEGIN
  -- Generate a 6-digit code
  v_code := lpad(floor(random() * 1000000)::text, 6, '0');

  -- Invalidate any existing unused codes for this user/IP
  UPDATE ip_verification_codes
  SET used = true
  WHERE user_id = p_user_id
    AND ip_address = p_ip_address
    AND used = false;

  -- Insert the new code
  INSERT INTO ip_verification_codes (
    user_id,
    email,
    ip_address,
    device_info,
    location,
    code,
    expires_at,
    used,
    attempts
  ) VALUES (
    p_user_id,
    p_email,
    p_ip_address,
    p_device_info,
    p_location,
    v_code,
    now() + interval '15 minutes',
    false,
    0
  );

  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to verify an IP verification code
CREATE OR REPLACE FUNCTION verify_ip_code(
  p_user_id uuid,
  p_code text,
  p_trust_duration_days integer DEFAULT 30
)
RETURNS jsonb AS $$
DECLARE
  v_verification record;
  v_trusted_ip_id uuid;
BEGIN
  -- Find the verification code
  SELECT * INTO v_verification
  FROM ip_verification_codes
  WHERE user_id = p_user_id
    AND code = p_code
    AND used = false
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- Check if code exists but is expired or used
    SELECT * INTO v_verification
    FROM ip_verification_codes
    WHERE user_id = p_user_id
      AND code = p_code
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      IF v_verification.used THEN
        RETURN jsonb_build_object('success', false, 'error', 'Code has already been used');
      ELSIF v_verification.expires_at <= now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Code has expired');
      END IF;
    END IF;

    -- Increment attempts on latest code for this user
    UPDATE ip_verification_codes
    SET attempts = attempts + 1
    WHERE user_id = p_user_id
      AND used = false
      AND expires_at > now();

    RETURN jsonb_build_object('success', false, 'error', 'Invalid verification code');
  END IF;

  -- Check max attempts
  IF v_verification.attempts >= COALESCE(v_verification.max_attempts, 5) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Too many attempts. Please request a new code.');
  END IF;

  -- Mark code as used
  UPDATE ip_verification_codes
  SET used = true
  WHERE id = v_verification.id;

  -- Add the IP to trusted IPs
  SELECT add_trusted_ip(
    p_user_id,
    v_verification.ip_address,
    v_verification.device_info,
    v_verification.location,
    p_trust_duration_days
  ) INTO v_trusted_ip_id;

  RETURN jsonb_build_object(
    'success', true,
    'trusted_ip_id', v_trusted_ip_id,
    'ip_address', v_verification.ip_address,
    'message', 'Device verified and trusted'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Function to cleanup expired verification codes
CREATE OR REPLACE FUNCTION cleanup_expired_verification_codes()
RETURNS integer AS $$
DECLARE
  v_deleted_count integer;
BEGIN
  DELETE FROM ip_verification_codes
  WHERE expires_at < now() - interval '24 hours';

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_ip_trusted(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_login_attempt(uuid, text, text, jsonb, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION add_trusted_ip(uuid, text, text, jsonb, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION revoke_trusted_ip(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_ip_verification_code(uuid, text, text, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_ip_code(uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_verification_codes() TO authenticated;

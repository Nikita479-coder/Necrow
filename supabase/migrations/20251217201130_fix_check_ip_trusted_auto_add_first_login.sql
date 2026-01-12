/*
  # Fix check_ip_trusted to Auto-Add IP on First Login

  ## Description
  Updates the check_ip_trusted function to automatically add the IP address
  to trusted_ips when this is the user's first login (no existing trusted IPs).

  ## Changes
  - When user has no trusted IPs, automatically trust the current IP
  - This ensures the first login from any IP is automatically trusted
  - Subsequent logins from new IPs will require verification
*/

CREATE OR REPLACE FUNCTION check_ip_trusted(
  p_user_id uuid,
  p_ip_address text
)
RETURNS jsonb AS $$
DECLARE
  v_trusted_ip record;
  v_is_first_login boolean;
  v_new_trusted_ip_id uuid;
BEGIN
  -- Check if user has any trusted IPs (first login check)
  SELECT NOT EXISTS (
    SELECT 1 FROM trusted_ips 
    WHERE user_id = p_user_id AND is_trusted = true
  ) INTO v_is_first_login;

  -- If this is the user's first login, automatically trust this IP
  IF v_is_first_login THEN
    -- Add this IP as trusted (30 day expiration)
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
      NULL,
      '{}',
      now(),
      now(),
      now() + interval '30 days',
      true
    )
    ON CONFLICT (user_id, ip_address) DO UPDATE SET
      last_used = now(),
      is_trusted = true,
      trust_expires_at = now() + interval '30 days',
      updated_at = now()
    RETURNING id INTO v_new_trusted_ip_id;

    RETURN jsonb_build_object(
      'is_trusted', true,
      'is_first_login', true,
      'trusted_ip_id', v_new_trusted_ip_id,
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

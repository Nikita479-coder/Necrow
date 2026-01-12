/*
  # Fix Telegram Chat ID Type Comparison
  
  ## Issue
  The telegram_chat_id column is TEXT type, but the function parameter is BIGINT
  This causes type mismatch errors during comparison
  
  ## Solution
  Convert the bigint parameter to text for comparison
*/

CREATE OR REPLACE FUNCTION verify_telegram_linking_code(
  p_code text,
  p_chat_id bigint,
  p_username text DEFAULT NULL
)
RETURNS TABLE(success boolean, user_id uuid, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_record record;
  v_chat_id_text text;
BEGIN
  -- Convert chat_id to text for comparison
  v_chat_id_text := p_chat_id::text;
  
  -- Find the code
  SELECT tlc.*, up.telegram_chat_id as existing_chat_id
  INTO v_code_record
  FROM telegram_linking_codes tlc
  JOIN user_profiles up ON up.id = tlc.user_id
  WHERE tlc.code = upper(p_code)
  AND tlc.used_at IS NULL
  AND tlc.expires_at > now();
  
  IF v_code_record IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Invalid or expired code'::text;
    RETURN;
  END IF;
  
  -- Check if this chat_id is already linked to another account
  IF EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE telegram_chat_id = v_chat_id_text
    AND id != v_code_record.user_id
  ) THEN
    RETURN QUERY SELECT false, NULL::uuid, 'This Telegram account is already linked to another user'::text;
    RETURN;
  END IF;
  
  -- Mark code as used
  UPDATE telegram_linking_codes
  SET used_at = now()
  WHERE id = v_code_record.id;
  
  -- Update user profile with Telegram info
  UPDATE user_profiles
  SET 
    telegram_chat_id = v_chat_id_text,
    telegram_username = p_username,
    telegram_linked_at = now(),
    telegram_blocked = false
  WHERE id = v_code_record.user_id;
  
  RETURN QUERY SELECT true, v_code_record.user_id, 'Account linked successfully!'::text;
END;
$$;

-- Update the unlink function to handle text type
CREATE OR REPLACE FUNCTION unlink_telegram_account(p_chat_id bigint)
RETURNS TABLE(success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_chat_id_text text;
BEGIN
  v_chat_id_text := p_chat_id::text;
  
  -- Find the user with this chat_id
  SELECT id INTO v_user_id
  FROM user_profiles
  WHERE telegram_chat_id = v_chat_id_text;
  
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'No account linked to this Telegram'::text;
    RETURN;
  END IF;
  
  -- Clear telegram info
  UPDATE user_profiles
  SET 
    telegram_chat_id = NULL,
    telegram_username = NULL,
    telegram_linked_at = NULL,
    telegram_blocked = false
  WHERE id = v_user_id;
  
  RETURN QUERY SELECT true, 'Account unlinked successfully'::text;
END;
$$;

-- Update mark_telegram_blocked to handle text type
CREATE OR REPLACE FUNCTION mark_telegram_blocked(p_chat_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_chat_id_text text;
BEGIN
  v_chat_id_text := p_chat_id::text;
  
  UPDATE user_profiles
  SET telegram_blocked = true
  WHERE telegram_chat_id = v_chat_id_text;
END;
$$;

-- Update generate_telegram_linking_code to handle text type properly
CREATE OR REPLACE FUNCTION generate_telegram_linking_code(p_user_id uuid)
RETURNS TABLE(code text, expires_at timestamptz, bot_username text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_expires_at timestamptz;
  v_existing_chat_id text;
BEGIN
  -- Check if user already has telegram linked
  SELECT telegram_chat_id INTO v_existing_chat_id
  FROM user_profiles
  WHERE id = p_user_id;
  
  IF v_existing_chat_id IS NOT NULL THEN
    RAISE EXCEPTION 'Telegram already linked';
  END IF;
  
  -- Generate a random 8-character code
  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
  v_expires_at := now() + interval '15 minutes';
  
  -- Delete any existing codes for this user
  DELETE FROM telegram_linking_codes WHERE user_id = p_user_id;
  
  -- Insert new code
  INSERT INTO telegram_linking_codes (user_id, code, expires_at)
  VALUES (p_user_id, v_code, v_expires_at);
  
  -- Return the code and expiration with correct bot username
  RETURN QUERY SELECT v_code, v_expires_at, 'sharktrade_notifications_bot'::text;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION verify_telegram_linking_code(text, bigint, text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION unlink_telegram_account(bigint) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION mark_telegram_blocked(bigint) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION generate_telegram_linking_code(uuid) TO authenticated, anon, service_role;

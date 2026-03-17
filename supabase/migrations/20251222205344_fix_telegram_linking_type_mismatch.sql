/*
  # Fix Telegram Linking Code Type Mismatch
  
  ## Issue
  The verify_telegram_linking_code function has a type comparison error
  when checking if a chat_id is already linked to another account.
  
  ## Changes
  - Update the function to properly handle bigint comparison
  - Ensure all type casts are explicit
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
BEGIN
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
    WHERE telegram_chat_id = p_chat_id::bigint
    AND id != v_code_record.user_id::uuid
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
    telegram_chat_id = p_chat_id,
    telegram_username = p_username,
    telegram_linked_at = now(),
    telegram_blocked = false
  WHERE id = v_code_record.user_id;
  
  RETURN QUERY SELECT true, v_code_record.user_id, 'Account linked successfully!'::text;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION verify_telegram_linking_code(text, bigint, text) TO authenticated, anon, service_role;

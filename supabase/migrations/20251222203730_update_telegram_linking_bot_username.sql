/*
  # Update Telegram Bot Username in Linking Function

  1. Changes
    - Updates the `generate_telegram_linking_code` function to return the correct bot username
    - Bot username: sharktrade_notifications_bot

  2. Purpose
    - Ensures users are directed to the correct Telegram bot when linking their accounts
*/

CREATE OR REPLACE FUNCTION generate_telegram_linking_code(p_user_id uuid)
RETURNS TABLE(code text, expires_at timestamptz, bot_username text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_expires_at timestamptz;
  v_existing_chat_id bigint;
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
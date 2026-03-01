/*
  # Fix Telegram Followers Function Return Type

  1. Changes
    - Drop and recreate get_telegram_followers_for_trader function
    - Change telegram_chat_id return type from bigint to text
    - This matches the actual column type in user_profiles table

  2. Purpose
    - Fix the function to properly return followers with Telegram enabled
    - Resolve type mismatch error preventing notifications from being sent
*/

DROP FUNCTION IF EXISTS get_telegram_followers_for_trader(uuid);

CREATE OR REPLACE FUNCTION get_telegram_followers_for_trader(p_trader_id uuid)
RETURNS TABLE(
  user_id uuid,
  telegram_chat_id text,
  copy_relationship_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cr.follower_id as user_id,
    up.telegram_chat_id,
    cr.id as copy_relationship_id
  FROM copy_relationships cr
  JOIN user_profiles up ON up.id = cr.follower_id
  WHERE cr.trader_id = p_trader_id
  AND cr.status = 'active'
  AND cr.is_active = true
  AND up.telegram_chat_id IS NOT NULL
  AND up.telegram_blocked = false;
END;
$$;

GRANT EXECUTE ON FUNCTION get_telegram_followers_for_trader(uuid) TO authenticated;

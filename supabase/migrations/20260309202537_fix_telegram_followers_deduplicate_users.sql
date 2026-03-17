/*
  # Fix Telegram Followers Function - Deduplicate Users

  1. Changes
    - Update get_telegram_followers_for_trader to use DISTINCT ON (follower_id)
    - Users with both mock and real copy relationships now only receive one notification
    - Prioritizes real (non-mock) relationships over mock ones

  2. Purpose
    - Prevent duplicate Telegram notifications for users with multiple relationships
    - Reduce edge function execution time by sending fewer API calls
*/

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
  SELECT DISTINCT ON (cr.follower_id)
    cr.follower_id as user_id,
    up.telegram_chat_id,
    cr.id as copy_relationship_id
  FROM copy_relationships cr
  JOIN user_profiles up ON up.id = cr.follower_id
  WHERE cr.trader_id = p_trader_id
  AND cr.status = 'active'
  AND cr.is_active = true
  AND up.telegram_chat_id IS NOT NULL
  AND up.telegram_blocked = false
  ORDER BY cr.follower_id, cr.is_mock ASC;
END;
$$;

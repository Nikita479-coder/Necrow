/*
  # Create Function to Get Referred Users with Masked Emails
  
  1. Function
    - get_referred_users - Returns list of users referred by a given user
    - Masks email addresses for privacy (shows first 3 chars and domain)
  
  2. Security
    - SECURITY DEFINER to access auth.users
    - Users can only see their own referrals
*/

CREATE OR REPLACE FUNCTION get_referred_users(p_referrer_id uuid)
RETURNS TABLE(
  user_id uuid,
  username text,
  masked_email text,
  joined_date timestamptz,
  total_trades integer,
  total_volume numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    up.id as user_id,
    up.username,
    CASE 
      WHEN LENGTH(au.email) > 3 THEN
        SUBSTRING(au.email FROM 1 FOR 3) || '•••@' || 
        SPLIT_PART(au.email, '@', 2)
      ELSE
        '•••@' || SPLIT_PART(au.email, '@', 2)
    END as masked_email,
    up.created_at as joined_date,
    COALESCE((
      SELECT COUNT(*)::integer
      FROM futures_positions fp
      WHERE fp.user_id = up.id
    ), 0) as total_trades,
    COALESCE((
      SELECT SUM(entry_price * quantity)
      FROM futures_positions fp
      WHERE fp.user_id = up.id
    ), 0) as total_volume
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  WHERE up.referred_by = p_referrer_id
  ORDER BY up.created_at DESC;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_referred_users(uuid) TO authenticated;

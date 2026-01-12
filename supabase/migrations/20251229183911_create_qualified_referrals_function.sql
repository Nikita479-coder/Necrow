/*
  # Create Qualified Referrals Count Function
  
  1. New Function
    - `get_qualified_referral_count(p_user_id uuid)` - Returns count of referrals who deposited $100+
    
  2. Purpose
    - Supports the "Growing Network" reward task in Rewards Hub
    - Counts referred users who have made at least $100 USD in total deposits
    
  3. Security
    - SECURITY DEFINER to access user_profiles and transactions
    - Users can only check their own qualified referral count
*/

CREATE OR REPLACE FUNCTION get_qualified_referral_count(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(DISTINCT up.id)::integer INTO v_count
  FROM user_profiles up
  JOIN transactions t ON t.user_id = up.id
  WHERE up.referred_by = p_user_id
    AND t.transaction_type = 'deposit'
    AND t.status = 'completed'
  GROUP BY up.id
  HAVING SUM(t.amount) >= 100;
  
  SELECT COUNT(*)::integer INTO v_count
  FROM (
    SELECT up.id
    FROM user_profiles up
    JOIN transactions t ON t.user_id = up.id
    WHERE up.referred_by = p_user_id
      AND t.transaction_type = 'deposit'
      AND t.status = 'completed'
    GROUP BY up.id
    HAVING SUM(t.amount) >= 100
  ) qualified;
  
  RETURN COALESCE(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION get_qualified_referral_count(uuid) TO authenticated;

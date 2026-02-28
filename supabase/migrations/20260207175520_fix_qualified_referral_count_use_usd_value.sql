/*
  # Fix Qualified Referral Count to Use USD Value

  ## Problem
  The `get_qualified_referral_count` function was summing raw transaction amounts
  without considering currency conversion. A user depositing 0.2 BNB (~$125 USD)
  was being counted as $0.20 and not qualifying for the $100 minimum.

  ## Solution
  Update the function to use `outcome_amount` from `crypto_deposits` table which
  stores the actual USD equivalent value for all deposits.

  ## Changes
  - Replace transaction-based amount calculation with crypto_deposits outcome_amount
  - Sum USD values from finished crypto deposits for each referral
  - Maintain $100 minimum qualification threshold
*/

CREATE OR REPLACE FUNCTION public.get_qualified_referral_count(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*)::integer INTO v_count
  FROM (
    SELECT up.id
    FROM user_profiles up
    JOIN crypto_deposits cd ON cd.user_id = up.id
    WHERE up.referred_by = p_user_id
      AND cd.status = 'finished'
    GROUP BY up.id
    HAVING SUM(cd.outcome_amount) >= 100
  ) qualified;

  RETURN COALESCE(v_count, 0);
END;
$function$;

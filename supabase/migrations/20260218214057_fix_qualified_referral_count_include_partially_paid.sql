/*
  # Fix qualified referral count to include partially_paid deposits

  1. Changes
    - Updated `get_qualified_referral_count` function to count deposits with
      status 'finished', 'partially_paid', or 'overpaid' (all statuses where
      funds are actually credited to the user's wallet)
    - Previously only counted 'finished' deposits, which missed legitimate
      deposits that were slightly under the exact payment amount

  2. Impact
    - Users whose referrals made deposits that resulted in 'partially_paid'
      status will now see the correct qualified referral count
    - Aligns with the deposit completion function which credits wallets for
      all three statuses
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
  SELECT COUNT(*)::integer INTO v_count
  FROM (
    SELECT up.id
    FROM user_profiles up
    JOIN crypto_deposits cd ON cd.user_id = up.id
    WHERE up.referred_by = p_user_id
      AND cd.status IN ('finished', 'partially_paid', 'overpaid')
    GROUP BY up.id
    HAVING SUM(
      CASE
        WHEN UPPER(cd.pay_currency) LIKE 'USDT%'
          OR UPPER(cd.pay_currency) LIKE 'USDC%'
          OR UPPER(cd.pay_currency) LIKE 'DAI%'
          OR UPPER(cd.pay_currency) LIKE 'BUSD%'
        THEN cd.actually_paid
        ELSE cd.outcome_amount
      END
    ) >= 100
  ) qualified;

  RETURN COALESCE(v_count, 0);
END;
$$;

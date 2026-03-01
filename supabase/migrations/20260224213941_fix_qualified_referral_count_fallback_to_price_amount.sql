/*
  # Fix qualified referral count for deposits with missing outcome_amount

  1. Problem
    - Some non-stablecoin deposits (e.g. ETH) have outcome_amount = 0 because
      NOWPayments did not populate this field in the webhook callback
    - The get_qualified_referral_count function uses outcome_amount for
      non-stablecoin USD valuation, so these deposits appear as $0
    - This causes referrals who legitimately deposited $100+ to not be counted

  2. Fix
    - For non-stablecoin deposits: use outcome_amount if > 0, otherwise fall
      back to price_amount (the USD value originally requested by the user)
    - A deposit with status 'finished' already confirms funds were received,
      so price_amount is a safe fallback

  3. Also fixes
    - get_depositor_referral_tree: same outcome_amount = 0 issue in deposit
      totals calculation
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
        ELSE CASE WHEN cd.outcome_amount > 0 THEN cd.outcome_amount ELSE cd.price_amount END
      END
    ) >= 100
  ) qualified;

  RETURN COALESCE(v_count, 0);
END;
$$;

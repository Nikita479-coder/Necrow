/*
  # Fix Qualified Referral Count to Use Actually Paid for Stablecoins

  ## Problem
  The `get_qualified_referral_count` function uses `outcome_amount` from
  NOWPayments, which reflects their post-fee USD valuation. However, the
  user's wallet is credited with `actually_paid` (the actual crypto amount
  received). For stablecoin deposits (USDT, USDC), `actually_paid` IS the
  USD value and is more accurate. Example: a user deposits 101 USDT,
  gets 101 USDT in their wallet, but `outcome_amount` says $96.98 due to
  NOWPayments processing fees -- causing them to not qualify for the $100
  minimum.

  ## Solution
  Update the function to use `actually_paid` for stablecoin deposits
  (USDT*, USDC*, DAI*, BUSD*) since those are 1:1 with USD, and fall
  back to `outcome_amount` for non-stablecoin deposits (BTC, ETH, BNB, SOL)
  where `actually_paid` is in the native crypto denomination.

  ## Changes
  - Modified `get_qualified_referral_count` function
  - Uses case-insensitive check on `pay_currency` to detect stablecoins
  - Stablecoin deposits: USD value = `actually_paid`
  - Non-stablecoin deposits: USD value = `outcome_amount`
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
$function$;

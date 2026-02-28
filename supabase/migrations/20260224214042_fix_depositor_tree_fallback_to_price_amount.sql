/*
  # Fix depositor referral tree deposit totals for missing outcome_amount

  1. Problem
    - Same issue as get_qualified_referral_count: non-stablecoin deposits
      (ETH, BTC, etc.) can have outcome_amount = 0 from NOWPayments
    - The deposit_stats CTE sums outcome_amount directly, so these deposits
      show $0 total

  2. Fix
    - Use CASE logic: for stablecoins use actually_paid, for others use
      outcome_amount if > 0, otherwise fall back to price_amount
*/

CREATE OR REPLACE FUNCTION get_depositor_referral_tree(
  p_root_user_id uuid,
  p_include_non_depositors boolean DEFAULT false,
  p_min_deposit_amount numeric DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  email text,
  full_name text,
  username text,
  parent_id uuid,
  level integer,
  total_deposits numeric,
  deposit_count bigint,
  first_deposit_date timestamptz,
  last_deposit_date timestamptz,
  has_deposits boolean,
  referral_code text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
RETURN QUERY
WITH RECURSIVE referral_tree AS (
  SELECT
    up.id AS user_id,
    up.id AS parent_id,
    0 AS level
  FROM user_profiles up
  WHERE up.id = p_root_user_id

  UNION ALL

  SELECT
    up.id AS user_id,
    up.referred_by AS parent_id,
    rt.level + 1 AS level
  FROM user_profiles up
  INNER JOIN referral_tree rt ON up.referred_by = rt.user_id
  WHERE rt.level < 10
),
deposit_stats AS (
  SELECT
    cd.user_id,
    COALESCE(SUM(
      CASE
        WHEN UPPER(cd.pay_currency) LIKE 'USDT%'
          OR UPPER(cd.pay_currency) LIKE 'USDC%'
          OR UPPER(cd.pay_currency) LIKE 'DAI%'
          OR UPPER(cd.pay_currency) LIKE 'BUSD%'
        THEN cd.actually_paid
        ELSE CASE WHEN cd.outcome_amount > 0 THEN cd.outcome_amount ELSE cd.price_amount END
      END
    ), 0) AS total_deposits,
    COUNT(cd.payment_id) AS deposit_count,
    MIN(cd.completed_at) AS first_deposit_date,
    MAX(cd.completed_at) AS last_deposit_date
  FROM crypto_deposits cd
  WHERE cd.status IN ('finished', 'confirmed', 'partially_paid')
  GROUP BY cd.user_id
),
tree_with_deposits AS (
  SELECT
    rt.user_id,
    rt.parent_id,
    rt.level,
    COALESCE(ds.total_deposits, 0) AS total_deposits,
    COALESCE(ds.deposit_count, 0) AS deposit_count,
    ds.first_deposit_date,
    ds.last_deposit_date,
    (COALESCE(ds.total_deposits, 0) > 0) AS has_deposits
  FROM referral_tree rt
  LEFT JOIN deposit_stats ds ON ds.user_id = rt.user_id
),
users_with_depositor_children AS (
  SELECT DISTINCT twd1.user_id
  FROM tree_with_deposits twd1
  WHERE EXISTS (
    SELECT 1
    FROM tree_with_deposits twd2
    WHERE twd2.has_deposits = true
      AND twd2.level > twd1.level
      AND EXISTS (
        WITH RECURSIVE ancestry AS (
          SELECT twd2.user_id AS uid, twd2.parent_id AS pid
          UNION ALL
          SELECT a.pid, twd3.parent_id
          FROM ancestry a
          JOIN tree_with_deposits twd3 ON twd3.user_id = a.pid
          WHERE twd3.level > 0
        )
        SELECT 1 FROM ancestry WHERE pid = twd1.user_id OR uid = twd1.user_id
      )
  )
),
bridge_users AS (
  SELECT DISTINCT bpaths.parent_user_id
  FROM (
    WITH RECURSIVE path_to_root AS (
      SELECT
        twd.user_id AS depositor_id,
        twd.parent_id AS parent_user_id,
        twd.level
      FROM tree_with_deposits twd
      WHERE twd.has_deposits = true AND twd.level > 0

      UNION ALL

      SELECT
        ptr.depositor_id,
        twd.parent_id AS parent_user_id,
        twd.level
      FROM path_to_root ptr
      JOIN tree_with_deposits twd ON twd.user_id = ptr.parent_user_id
      WHERE twd.level > 0
    )
    SELECT path_to_root.parent_user_id FROM path_to_root
  ) bpaths
)
SELECT
  twd.user_id,
  au.email::text,
  up.full_name,
  up.username,
  CASE WHEN twd.level = 0 THEN NULL ELSE twd.parent_id END AS parent_id,
  twd.level,
  twd.total_deposits,
  twd.deposit_count,
  twd.first_deposit_date,
  twd.last_deposit_date,
  twd.has_deposits,
  up.referral_code,
  up.created_at
FROM tree_with_deposits twd
INNER JOIN user_profiles up ON up.id = twd.user_id
LEFT JOIN auth.users au ON au.id = twd.user_id
WHERE
  p_include_non_depositors = true
  OR twd.level = 0
  OR twd.has_deposits = true
  OR twd.user_id IN (SELECT parent_user_id FROM bridge_users)
ORDER BY twd.level, twd.total_deposits DESC NULLS LAST;
END;
$$;

/*
  # Refresh All Affiliate Boost Caches After FTD Backfill

  1. What This Does
    - Calls `get_exclusive_affiliate_boost()` for every active exclusive affiliate
    - This recalculates their 30-day FTD count from the now-populated `ftd_at` / `ftd_amount` fields
    - Updates the cached tier/multiplier in `exclusive_affiliate_network_stats`

  2. Why
    - The previous migration backfilled FTD data for all 62 depositing users
    - Affiliate dashboards read cached boost values from `exclusive_affiliate_network_stats`
    - Without this refresh, dashboards would still show stale (zero) FTD counts

  3. Safety
    - Read-heavy operation; only writes to the cache columns on `exclusive_affiliate_network_stats`
    - Idempotent: running again just re-caches the same calculated values
*/

DO $$
DECLARE
  v_affiliate record;
  v_result jsonb;
BEGIN
  FOR v_affiliate IN
    SELECT user_id FROM exclusive_affiliates WHERE is_active = true
  LOOP
    v_result := get_exclusive_affiliate_boost(v_affiliate.user_id);
  END LOOP;
END;
$$;

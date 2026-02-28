/*
  # Rollback: Remove incorrectly enrolled exclusive affiliates

  The previous migration enrolled ALL 2,161 users as exclusive affiliates.
  Only users from EU countries, US, CA, and AU should have been enrolled (~202 users).
  This migration removes the 1,959 users from non-target regions.

  1. Changes
    - Deletes notifications sent to incorrectly enrolled users
    - Deletes network stats for incorrectly enrolled users
    - Deletes balance records for incorrectly enrolled users
    - Deletes exclusive_affiliates records for non-target-region users

  2. Important Notes
    - 36 pre-existing affiliates are NOT touched (they have enrolled_by set or were created earlier)
    - 202 correctly enrolled EU/US/CA/AU users are NOT touched
    - All removed records were just created with zero balances and zero stats
*/

DO $$
DECLARE
  v_target_countries text[] := ARRAY[
    'US','CA','AU',
    'AD','AL','AT','AZ','BA','BE','BG','BY','CH','CZ','DE',
    'DK','EE','ES','FI','FR','GB','GE','GR','HR','HU','IE','IS',
    'IT','LI','LT','LU','LV','MC','MD','ME','MK','MT','NL','NO',
    'PL','PT','RO','RS','RU','SE','SI','SK','SM','TR','UA','VA','XK'
  ];
  v_deleted_notifications int;
  v_deleted_stats int;
  v_deleted_balances int;
  v_deleted_affiliates int;
BEGIN
  -- Step 1: Delete notifications for incorrectly enrolled users
  DELETE FROM notifications n
  WHERE n.type = 'system'
    AND n.title = 'Welcome to Exclusive Affiliate Program!'
    AND n.user_id IN (
      SELECT ea.user_id
      FROM exclusive_affiliates ea
      JOIN user_profiles up ON up.id = ea.user_id
      WHERE ea.enrolled_by IS NULL
        AND (up.country IS NULL OR up.country != ALL(v_target_countries))
    );
  GET DIAGNOSTICS v_deleted_notifications = ROW_COUNT;
  RAISE NOTICE 'Deleted % notifications', v_deleted_notifications;

  -- Step 2: Delete network stats for incorrectly enrolled users
  DELETE FROM exclusive_affiliate_network_stats ns
  WHERE ns.affiliate_id IN (
    SELECT ea.id
    FROM exclusive_affiliates ea
    JOIN user_profiles up ON up.id = ea.user_id
    WHERE ea.enrolled_by IS NULL
      AND (up.country IS NULL OR up.country != ALL(v_target_countries))
  );
  GET DIAGNOSTICS v_deleted_stats = ROW_COUNT;
  RAISE NOTICE 'Deleted % network stats', v_deleted_stats;

  -- Step 3: Delete balances for incorrectly enrolled users
  DELETE FROM exclusive_affiliate_balances ab
  WHERE ab.user_id IN (
    SELECT ea.user_id
    FROM exclusive_affiliates ea
    JOIN user_profiles up ON up.id = ea.user_id
    WHERE ea.enrolled_by IS NULL
      AND (up.country IS NULL OR up.country != ALL(v_target_countries))
  );
  GET DIAGNOSTICS v_deleted_balances = ROW_COUNT;
  RAISE NOTICE 'Deleted % balances', v_deleted_balances;

  -- Step 4: Delete the exclusive affiliate records themselves
  DELETE FROM exclusive_affiliates ea
  USING user_profiles up
  WHERE up.id = ea.user_id
    AND ea.enrolled_by IS NULL
    AND (up.country IS NULL OR up.country != ALL(v_target_countries));
  GET DIAGNOSTICS v_deleted_affiliates = ROW_COUNT;
  RAISE NOTICE 'Deleted % affiliate records', v_deleted_affiliates;
END $$;
/*
  # Bulk Enroll All Users as Exclusive Affiliates

  1. Changes
    - Inserts all users who are NOT already in `exclusive_affiliates` into the program
    - Creates matching balance records in `exclusive_affiliate_balances`
    - Creates matching network stats records in `exclusive_affiliate_network_stats`
    - Sends a welcome notification to each newly enrolled user

  2. Commission Rates Applied
    - deposit_commission_rates: level_1=5%, level_2=4%, level_3=3%, level_4=2%, level_5=1%, levels 6-10=1%
    - copy_profit_rates: level_1=5%, level_2=4%, level_3=3%, level_4=2%, level_5=1%, levels 6-10=1%
    - fee_share_rates: all levels = 0%

  3. Safety
    - Uses ON CONFLICT DO NOTHING to skip users who already have records
    - Does not modify any existing affiliate configurations
    - Approximately 2165 users will be enrolled
*/

INSERT INTO exclusive_affiliates (user_id, enrolled_by, deposit_commission_rates, fee_share_rates, copy_profit_rates, is_active, is_boost_eligible)
SELECT
  up.id,
  NULL,
  '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1, "level_6": 1, "level_7": 1, "level_8": 1, "level_9": 1, "level_10": 1}'::jsonb,
  '{"level_1": 0, "level_2": 0, "level_3": 0, "level_4": 0, "level_5": 0, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}'::jsonb,
  '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1, "level_6": 1, "level_7": 1, "level_8": 1, "level_9": 1, "level_10": 1}'::jsonb,
  true,
  true
FROM user_profiles up
WHERE up.id NOT IN (SELECT user_id FROM exclusive_affiliates)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO exclusive_affiliate_balances (user_id)
SELECT ea.user_id
FROM exclusive_affiliates ea
WHERE ea.user_id NOT IN (SELECT user_id FROM exclusive_affiliate_balances)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
SELECT ea.user_id
FROM exclusive_affiliates ea
WHERE ea.user_id NOT IN (SELECT affiliate_id FROM exclusive_affiliate_network_stats)
ON CONFLICT (affiliate_id) DO NOTHING;

INSERT INTO notifications (user_id, type, title, message, read)
SELECT
  ea.user_id,
  'system',
  'Welcome to Exclusive Affiliate Program!',
  'You have been enrolled in our exclusive multi-level affiliate program with up to 10 levels of commissions. Start sharing your referral link to earn!',
  false
FROM exclusive_affiliates ea
WHERE ea.created_at >= now() - interval '1 minute'
AND ea.enrolled_by IS NULL;
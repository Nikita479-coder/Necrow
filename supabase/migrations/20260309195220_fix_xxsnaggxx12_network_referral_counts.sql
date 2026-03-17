/*
  # Fix Xxsnaggxx12 network referral counts

  Xxsnaggxx12 (xxsnaggxx12@gmail.com) was enrolled as an exclusive affiliate
  after all 3 direct referrals had already signed up. The network stats
  show 0 counts but should reflect:

  - Level 1 (3 users): Nikola, Zara, Alexey (all signed up before enrollment)
  - Level 2 (1 user): Urgen (referred by Alexey)

  No additional commissions are owed -- Nikola and Zara have no deposits.
  The $4.40 level_2_earnings from Urgen's deposit is already correct.
*/

UPDATE exclusive_affiliate_network_stats
SET
  level_1_count = 3,
  level_2_count = 1,
  updated_at = now()
WHERE affiliate_id = '69e539d8-666c-48ed-b46e-ade5d884d13b';

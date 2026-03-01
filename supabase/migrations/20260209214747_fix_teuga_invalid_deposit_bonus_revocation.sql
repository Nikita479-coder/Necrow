/*
  # Revoke Invalid Deposit Bonus for Teuga Philippe

  1. Changes
    - Teuga (35ddb641-c9b9-4aac-9534-b36a61deafb6) had 4 completed deposits
      (Jan 8, Jan 17, Jan 27, Feb 9). The first 3 were before the bonus system.
    - His 4th deposit on Feb 9 incorrectly triggered a First Deposit Bonus
      (100% of $55.79 = $55.79)
    - Since he has already exceeded all 3 bonus tiers, no bonus should have
      been awarded. Revoking the incorrect bonus.

  2. Records Updated
    - `user_deposit_bonuses`: removed incorrect tier 1 record
    - `locked_bonuses`: expired the active locked bonus
    - `notifications`: removed the incorrect bonus notification
*/

DO $$
BEGIN
  UPDATE locked_bonuses
  SET status = 'expired',
      current_amount = 0,
      updated_at = now()
  WHERE id = 'c2784870-7fa9-4599-ab63-cfabdd5a7bec';

  DELETE FROM user_deposit_bonuses
  WHERE id = '4ac8ceee-5e6c-4c36-93a9-7946a89bcd5a';

  DELETE FROM notifications
  WHERE id = '24a06ab5-937f-403e-8170-23bfd5355ccc';
END $$;

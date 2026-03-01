/*
  # Correct Catalina's Deposit Bonus from Tier 1 to Tier 3

  1. Changes
    - Catalina (ea185136-8c96-421c-b31b-26abec6c1b68) deposited $10 on Feb 9
    - This was her 3rd completed deposit ($100 on Feb 3, $50 on Feb 4, $10 on Feb 9)
    - The old tier logic counted bonus records instead of actual deposits, so it
      incorrectly awarded tier 1 (First Deposit Bonus, 100% = $10)
    - Corrected to tier 3 (Third Deposit Bonus, 20% = $2)

  2. Records Updated
    - `user_deposit_bonuses`: tier_number 1 → 3, bonus_amount 10 → 2, bonus_percentage 100 → 20
    - `locked_bonuses`: original_amount & current_amount 10 → 2, bonus_type updated
    - `notifications`: title and message updated to reflect third deposit bonus
*/

DO $$
DECLARE
  v_third_deposit_bonus_type_id uuid := 'e88180ef-b6e6-4334-8310-eea94d7b9a03';
BEGIN
  UPDATE user_deposit_bonuses
  SET tier_number = 3,
      bonus_amount = 2,
      bonus_percentage = 20
  WHERE id = '6a9f499b-d9c7-4599-ad6a-47b44634917d';

  UPDATE locked_bonuses
  SET original_amount = 2,
      current_amount = 2,
      bonus_type_id = v_third_deposit_bonus_type_id,
      bonus_type_name = 'Third Deposit Bonus',
      notes = 'Third Deposit Bonus - 20% match on deposit of $10.00',
      updated_at = now()
  WHERE id = '57e56e45-a9e1-43ab-bc32-de0dc0aebf56';

  UPDATE notifications
  SET title = 'Third Deposit Bonus Awarded!',
      message = 'You received $2.00 USDT as your third deposit bonus (20% match)! Use it for futures trading - profits are yours to keep.'
  WHERE id = '67d4ec5d-14bd-4e4c-bffc-1d13b61f6939';
END $$;

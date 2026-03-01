/*
  # Update A112SH User with 10-Level Commission Rates

  ## Overview
  Updates the exclusive affiliate user A112SH (a112sh001@gmail.com) with custom
  10-level commission rates for deposits and trading fees.

  ## Commission Structure
  - Deposit Commissions:
    - Level 1: 15%
    - Level 2: 10%
    - Level 3: 8%
    - Level 4: 6%
    - Level 5: 5%
    - Level 6: 4%
    - Level 7: 3%
    - Level 8: 2%
    - Level 9: 1%
    - Level 10: 1%
    
  - Trading Fee Revenue Share (same pattern):
    - Level 1: 15%
    - Level 2: 10%
    - Level 3: 8%
    - Level 4: 6%
    - Level 5: 5%
    - Level 6: 4%
    - Level 7: 3%
    - Level 8: 2%
    - Level 9: 1%
    - Level 10: 1%

  ## Security
  - No RLS changes
*/

UPDATE exclusive_affiliates
SET 
  deposit_commission_rates = '{
    "level_1": 15,
    "level_2": 10,
    "level_3": 8,
    "level_4": 6,
    "level_5": 5,
    "level_6": 4,
    "level_7": 3,
    "level_8": 2,
    "level_9": 1,
    "level_10": 1
  }'::jsonb,
  fee_share_rates = '{
    "level_1": 15,
    "level_2": 10,
    "level_3": 8,
    "level_4": 6,
    "level_5": 5,
    "level_6": 4,
    "level_7": 3,
    "level_8": 2,
    "level_9": 1,
    "level_10": 1
  }'::jsonb,
  copy_profit_rates = '{
    "level_1": 15,
    "level_2": 10,
    "level_3": 8,
    "level_4": 6,
    "level_5": 5,
    "level_6": 4,
    "level_7": 3,
    "level_8": 2,
    "level_9": 1,
    "level_10": 1
  }'::jsonb,
  updated_at = now()
WHERE user_id = (
  SELECT id FROM auth.users WHERE email = 'a112sh001@gmail.com'
);

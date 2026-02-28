/*
  # Remove Copy Profit Rates for A112SH

  1. Changes
    - Set copy_profit_rates to all zeros for user A112SH
    - User only has deposit and trading fee commissions, not copy profit
*/

UPDATE exclusive_affiliates
SET copy_profit_rates = '{"level_1": 0, "level_2": 0, "level_3": 0, "level_4": 0, "level_5": 0, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}'::jsonb
WHERE user_id = '51b65324-8f66-4c6c-97e5-6ab41812d062';

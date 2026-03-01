/*
  # Rename VIP Levels to New Tier Names

  1. Changes
    - Update VIP level names from numbered system to tier-based system
    - VIP 1 → Beginner
    - VIP 2 → Intermediate  
    - VIP 3 → Advanced
    - VIP 4 → VIP 1
    - VIP 5 → VIP 2
    - VIP 6 → Diamond

  2. Security
    - No changes to RLS policies
*/

-- Update VIP level names
UPDATE vip_levels SET level_name = 'Beginner' WHERE level_number = 1;
UPDATE vip_levels SET level_name = 'Intermediate' WHERE level_number = 2;
UPDATE vip_levels SET level_name = 'Advanced' WHERE level_number = 3;
UPDATE vip_levels SET level_name = 'VIP 1' WHERE level_number = 4;
UPDATE vip_levels SET level_name = 'VIP 2' WHERE level_number = 5;
UPDATE vip_levels SET level_name = 'Diamond' WHERE level_number = 6;

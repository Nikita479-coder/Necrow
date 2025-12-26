/*
  # Update VIP Volume Requirements (5x Increase)

  1. Changes
    - Multiply all volume requirements by 5
    - Beginner: $0 - $50,000 (was $0 - $10,000)
    - Intermediate: $50,001 - $500,000 (was $10,001 - $100,000)
    - Advanced: $500,001 - $2,500,000 (was $100,001 - $500,000)
    - VIP 1: $2,500,001 - $12,500,000 (was $500,001 - $2,500,000)
    - VIP 2: $12,500,001 - $125,000,000 (was $2,500,001 - $25,000,000)
    - Diamond: $125,000,001+ (was $25,000,001+)

  2. Security
    - No changes to RLS policies
*/

-- Drop the unique constraint temporarily
ALTER TABLE vip_levels DROP CONSTRAINT IF EXISTS unique_volume_range;

-- Update VIP level volume requirements (5x) - update in reverse order to avoid conflicts
UPDATE vip_levels SET min_volume_30d = 125000001, max_volume_30d = NULL WHERE level_number = 6;
UPDATE vip_levels SET min_volume_30d = 12500001, max_volume_30d = 125000000 WHERE level_number = 5;
UPDATE vip_levels SET min_volume_30d = 2500001, max_volume_30d = 12500000 WHERE level_number = 4;
UPDATE vip_levels SET min_volume_30d = 500001, max_volume_30d = 2500000 WHERE level_number = 3;
UPDATE vip_levels SET min_volume_30d = 50001, max_volume_30d = 500000 WHERE level_number = 2;
UPDATE vip_levels SET min_volume_30d = 0, max_volume_30d = 50000 WHERE level_number = 1;

-- Recreate the unique constraint
ALTER TABLE vip_levels ADD CONSTRAINT unique_volume_range UNIQUE (min_volume_30d, max_volume_30d);

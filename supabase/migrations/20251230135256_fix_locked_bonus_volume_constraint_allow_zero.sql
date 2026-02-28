/*
  # Fix Locked Bonus Volume Constraint

  1. Changes
    - Allow volume_required to be 0 (for bonuses that don't require trading volume to unlock)
    - This enables KYC bonuses and other bonuses that have no volume requirement

  2. Security
    - No security changes
*/

ALTER TABLE locked_bonuses 
DROP CONSTRAINT IF EXISTS check_bonus_volume_required_positive;

ALTER TABLE locked_bonuses 
ADD CONSTRAINT check_bonus_volume_required_non_negative 
CHECK (bonus_trading_volume_required >= 0);

/*
  # Multiply Satoshi Academy ROI by 3

  1. Changes
    - Updates Satoshi Academy trader ROI values (7d, 30d, 90d, all-time) by multiplying each by 3
    - This increases visibility and attractiveness of the featured trader

  2. Original Values -> New Values
    - roi_7d: 6.63% -> 19.88%
    - roi_30d: 28.50% -> 85.50%
    - roi_90d: 85.50% -> 256.50%
    - roi_all_time: 171.00% -> 513.00%
*/

UPDATE traders
SET 
  roi_7d = roi_7d * 3,
  roi_30d = roi_30d * 3,
  roi_90d = roi_90d * 3,
  roi_all_time = roi_all_time * 3,
  updated_at = now()
WHERE name = 'Satoshi Academy';

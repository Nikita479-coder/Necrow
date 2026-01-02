/*
  # Add Base PNL Period Columns to Traders

  1. Changes
    - Add base PNL columns for each time period (7d, 30d, 90d, all_time)
    - These base values are added to actual trade performance for display
    
  2. New Columns
    - base_pnl_7d: Base 7-day PNL to add
    - base_pnl_30d: Base 30-day PNL to add  
    - base_pnl_90d: Base 90-day PNL to add
    - base_roi_7d: Base 7-day ROI percentage to add
    - base_roi_30d: Base 30-day ROI percentage to add
    - base_roi_90d: Base 90-day ROI percentage to add
*/

ALTER TABLE traders
ADD COLUMN IF NOT EXISTS base_pnl_7d numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_pnl_30d numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_pnl_90d numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_roi_7d numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_roi_30d numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_roi_90d numeric DEFAULT 0;

-- Set base values for Satoshi Academy based on target monthly ROI of 82.5%
-- Starting capital: 15,000,000
-- 30D target: 82.5% ROI = 12,375,000 PNL
-- 7D target: ~19.2% ROI (82.5/4.3) = ~2,880,000 PNL
-- 90D target: ~247.5% ROI = ~37,125,000 PNL

UPDATE traders
SET 
  base_pnl_7d = 2880000,
  base_pnl_30d = 12375000,
  base_pnl_90d = 37125000,
  base_roi_7d = 19.2,
  base_roi_30d = 82.5,
  base_roi_90d = 247.5
WHERE name = 'Satoshi Academy';

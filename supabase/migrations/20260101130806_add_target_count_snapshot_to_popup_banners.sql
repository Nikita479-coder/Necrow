/*
  # Add Target Count Snapshot to Popup Banners

  1. Changes
    - Add `target_count_snapshot` column to store the target audience size at creation time
    - This preserves the original target audience count even as user base changes
  
  2. Purpose
    - Display the target audience count from when the banner was created
    - Prevents confusion from changing audience sizes over time
*/

ALTER TABLE popup_banners
ADD COLUMN IF NOT EXISTS target_count_snapshot integer DEFAULT 0;

COMMENT ON COLUMN popup_banners.target_count_snapshot IS 'Snapshot of target audience size at banner creation time';

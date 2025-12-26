/*
  # Add TP/SL Notification Types

  ## Summary
  Expands the notifications system to support Take Profit and Stop Loss
  position closure notifications.

  ## Changes
  1. Add new notification types for TP/SL events:
     - `position_tp_hit` - Take Profit triggered
     - `position_sl_hit` - Stop Loss triggered
     - `position_closed` - Position manually closed

  ## Security
  - No changes to RLS policies
  - Uses existing send_notification function
*/

-- Drop existing constraint if it exists
DO $$
BEGIN
  ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Add new constraint with additional types
ALTER TABLE notifications
ADD CONSTRAINT notifications_type_check 
CHECK (type IN (
  'referral_payout',
  'trade_executed',
  'kyc_update',
  'account_update',
  'system',
  'position_tp_hit',
  'position_sl_hit',
  'position_closed'
));
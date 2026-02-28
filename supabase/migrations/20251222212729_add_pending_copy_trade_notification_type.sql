/*
  # Add Pending Copy Trade Notification Type

  1. Changes
    - Add 'pending_copy_trade' to allowed notification types
    - Enables in-app notifications for trade signals requiring user response

  2. Purpose
    - Allow followers to receive and respond to pending trades
    - Complete the pending trade notification system
*/

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN (
    'referral_payout', 'trade_executed', 'kyc_update', 'account_update', 'system', 
    'shark_card_issued', 'tpsl_triggered', 'tpsl_cancelled', 
    'withdrawal_blocked', 'withdrawal_unblocked', 'vip_level_upgraded',
    'position_closed', 'vip_downgrade', 'shark_card_application', 
    'position_tp_hit', 'vip_upgrade', 'shark_card_approved', 'shark_card_declined',
    'pending_copy_trade'
  ));

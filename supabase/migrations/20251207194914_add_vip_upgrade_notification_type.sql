/*
  # Add VIP Upgrade Notification Type

  1. Changes
    - Add 'vip_upgrade' to the existing notification types
    - Keep all existing notification types

  2. Purpose
    - Support VIP snapshot change detection notifications
    - Allow system to notify users of tier upgrades
*/

-- Drop the existing constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Recreate with all existing types plus vip_upgrade
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN (
    'referral_payout',
    'trade_executed',
    'kyc_update',
    'account_update',
    'system',
    'position_closed',
    'position_tp_hit',
    'position_sl_hit',
    'pending_trade',
    'trade_accepted',
    'trade_rejected',
    'shark_card_application',
    'shark_card_approved',
    'shark_card_declined',
    'shark_card_issued',
    'vip_downgrade',
    'vip_refill',
    'vip_upgrade',
    'withdrawal_blocked',
    'withdrawal_unblocked'
  ));
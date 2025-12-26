/*
  # Add copy_trade Notification Type

  1. Changes
    - Add 'copy_trade' to notifications type constraint
    - Used when a follower accepts a pending trade

  2. Purpose
    - Fix constraint violation when creating success notifications
*/

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
CHECK (type = ANY (ARRAY[
  'referral_payout'::text,
  'trade_executed'::text,
  'kyc_update'::text,
  'account_update'::text,
  'system'::text,
  'shark_card_issued'::text,
  'tpsl_triggered'::text,
  'tpsl_cancelled'::text,
  'withdrawal_blocked'::text,
  'withdrawal_unblocked'::text,
  'vip_level_upgraded'::text,
  'position_closed'::text,
  'vip_downgrade'::text,
  'shark_card_application'::text,
  'position_tp_hit'::text,
  'vip_upgrade'::text,
  'shark_card_approved'::text,
  'shark_card_declined'::text,
  'pending_copy_trade'::text,
  'copy_trade'::text
]));

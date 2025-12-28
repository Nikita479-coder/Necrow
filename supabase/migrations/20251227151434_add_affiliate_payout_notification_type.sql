/*
  # Add Affiliate Payout Notification Type

  ## Summary
  Adds 'affiliate_payout' to the allowed notification types for affiliate commission notifications.

  ## Changes
  1. Drops existing notifications_type_check constraint
  2. Recreates constraint with 'affiliate_payout' added
*/

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'referral_payout', 'trade_executed', 'kyc_update', 'account_update', 'system',
    'position_tp_hit', 'position_sl_hit', 'position_closed',
    'pending_copy_trade', 'copy_trade',
    'vip_upgrade', 'vip_downgrade',
    'shark_card_application', 'shark_card_approved', 'shark_card_declined', 'shark_card_issued',
    'deposit_detected', 'deposit_credited', 'deposit_failed', 'deposit_expired',
    'withdrawal_approved', 'withdrawal_completed', 'withdrawal_rejected',
    'bonus',
    'affiliate_payout'
  ])
);
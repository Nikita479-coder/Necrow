/*
  # Add withdrawal_approved notification type

  1. Changes
    - Add 'withdrawal_approved' to the notifications type check constraint
    - This allows the system to send notifications when withdrawals are approved
*/

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'referral_payout'::text,
    'trade_executed'::text,
    'kyc_update'::text,
    'account_update'::text,
    'system'::text,
    'copy_trade'::text,
    'position_closed'::text,
    'position_sl_hit'::text,
    'position_tp_hit'::text,
    'position_liquidated'::text,
    'vip_downgrade'::text,
    'vip_upgrade'::text,
    'shark_card_application'::text,
    'withdrawal_completed'::text,
    'withdrawal_rejected'::text,
    'withdrawal_approved'::text,
    'bonus'::text,
    'affiliate_payout'::text,
    'pending_copy_trade'::text,
    'deposit_completed'::text,
    'deposit_failed'::text,
    'broadcast'::text,
    'reward'::text,
    'promotion'::text
  ])
);

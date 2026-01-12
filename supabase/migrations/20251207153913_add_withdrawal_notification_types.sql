/*
  # Add withdrawal block notification types
  
  1. Changes
    - Add 'withdrawal_blocked' and 'withdrawal_unblocked' to notifications type constraint
    - Allows the system to notify users about withdrawal status changes
*/

-- Drop the existing constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Recreate with new types
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'referral_payout'::text,
    'trade_executed'::text,
    'kyc_update'::text,
    'account_update'::text,
    'system'::text,
    'position_closed'::text,
    'position_tp_hit'::text,
    'position_sl_hit'::text,
    'pending_trade'::text,
    'trade_accepted'::text,
    'trade_rejected'::text,
    'shark_card_application'::text,
    'shark_card_approved'::text,
    'shark_card_declined'::text,
    'shark_card_issued'::text,
    'vip_downgrade'::text,
    'vip_refill'::text,
    'withdrawal_blocked'::text,
    'withdrawal_unblocked'::text
  ])
);
/*
  # Add Deposit Notification Types (v2)

  ## Summary
  Adds notification types for deposit-related events while preserving all existing types.

  ## New Notification Types
  - `deposit_detected` - Deposit detected and confirming
  - `deposit_credited` - Deposit completed and credited to wallet
  - `deposit_failed` - Deposit failed
  - `deposit_expired` - Deposit address expired
  - `withdrawal_approved` - Withdrawal request approved
  - `withdrawal_completed` - Withdrawal completed
  - `withdrawal_rejected` - Withdrawal request rejected

  ## Security
  - No changes to RLS policies
*/

-- Drop existing constraint
DO $$
BEGIN
  ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Add new constraint with all existing + new deposit notification types
ALTER TABLE notifications
ADD CONSTRAINT notifications_type_check 
CHECK (type IN (
  -- Existing types
  'referral_payout',
  'trade_executed',
  'kyc_update',
  'account_update',
  'system',
  'position_tp_hit',
  'position_sl_hit',
  'position_closed',
  'pending_copy_trade',
  'copy_trade',
  'vip_upgrade',
  'vip_downgrade',
  'shark_card_application',
  'shark_card_approved',
  'shark_card_declined',
  'shark_card_issued',
  -- New deposit types
  'deposit_detected',
  'deposit_credited',
  'deposit_failed',
  'deposit_expired',
  -- New withdrawal types
  'withdrawal_approved',
  'withdrawal_completed',
  'withdrawal_rejected'
));

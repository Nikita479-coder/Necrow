/*
  # Create Email Notification Preferences System

  1. New Table
    - `email_notification_preferences`
      - `user_id` (uuid, primary key, foreign key to auth.users)
      - `notification_type` (text) - type of notification
      - `email_enabled` (boolean) - whether email is enabled for this type
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Notification Types Supported
    - Trading: trade_executed, position_closed, position_tp_hit, position_sl_hit, liquidation
    - Copy Trading: pending_trade, trade_accepted, trade_rejected
    - Account: kyc_update, account_update, vip_upgrade, vip_downgrade
    - Financial: withdrawal_approved, withdrawal_rejected, withdrawal_completed, withdrawal_blocked, withdrawal_unblocked, deposit_completed, referral_payout
    - Shark Card: shark_card_application, shark_card_approved, shark_card_declined, shark_card_issued, vip_refill
    - System: system

  3. Security
    - Enable RLS on email_notification_preferences table
    - Users can read and update their own preferences
*/

-- Create email notification preferences table
CREATE TABLE IF NOT EXISTS email_notification_preferences (
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type text NOT NULL,
  email_enabled boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, notification_type),
  CONSTRAINT valid_notification_type CHECK (
    notification_type IN (
      -- Trading
      'trade_executed',
      'position_closed',
      'position_tp_hit',
      'position_sl_hit',
      'liquidation',
      -- Copy Trading
      'pending_trade',
      'trade_accepted',
      'trade_rejected',
      -- Account
      'kyc_update',
      'account_update',
      'vip_upgrade',
      'vip_downgrade',
      -- Financial
      'withdrawal_approved',
      'withdrawal_rejected',
      'withdrawal_completed',
      'withdrawal_blocked',
      'withdrawal_unblocked',
      'deposit_completed',
      'referral_payout',
      -- Shark Card & VIP
      'shark_card_application',
      'shark_card_approved',
      'shark_card_declined',
      'shark_card_issued',
      'vip_refill',
      -- System
      'system'
    )
  )
);

-- Enable RLS
ALTER TABLE email_notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can view their own preferences
CREATE POLICY "Users can view own email preferences"
  ON email_notification_preferences
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "Users can update own email preferences"
  ON email_notification_preferences
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create function to get user's email preferences (returns all types with defaults)
CREATE OR REPLACE FUNCTION get_email_notification_preferences(p_user_id uuid)
RETURNS TABLE (
  notification_type text,
  email_enabled boolean
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH all_types AS (
    SELECT unnest(ARRAY[
      'trade_executed',
      'position_closed',
      'position_tp_hit',
      'position_sl_hit',
      'liquidation',
      'pending_trade',
      'trade_accepted',
      'trade_rejected',
      'kyc_update',
      'account_update',
      'vip_upgrade',
      'vip_downgrade',
      'withdrawal_approved',
      'withdrawal_rejected',
      'withdrawal_completed',
      'withdrawal_blocked',
      'withdrawal_unblocked',
      'deposit_completed',
      'referral_payout',
      'shark_card_application',
      'shark_card_approved',
      'shark_card_declined',
      'shark_card_issued',
      'vip_refill',
      'system'
    ]) AS type
  )
  SELECT 
    at.type,
    COALESCE(enp.email_enabled, true) as email_enabled
  FROM all_types at
  LEFT JOIN email_notification_preferences enp 
    ON enp.user_id = p_user_id AND enp.notification_type = at.type
  ORDER BY at.type;
END;
$$;

-- Create function to update email preference
CREATE OR REPLACE FUNCTION update_email_notification_preference(
  p_user_id uuid,
  p_notification_type text,
  p_email_enabled boolean
)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check user is updating their own preferences
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Cannot update other users preferences';
  END IF;

  INSERT INTO email_notification_preferences (user_id, notification_type, email_enabled, updated_at)
  VALUES (p_user_id, p_notification_type, p_email_enabled, now())
  ON CONFLICT (user_id, notification_type)
  DO UPDATE SET 
    email_enabled = EXCLUDED.email_enabled,
    updated_at = now();
END;
$$;

-- Create function to check if user has email enabled for a notification type
CREATE OR REPLACE FUNCTION is_email_notification_enabled(
  p_user_id uuid,
  p_notification_type text
)
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_enabled boolean;
BEGIN
  SELECT COALESCE(email_enabled, true)
  INTO v_enabled
  FROM email_notification_preferences
  WHERE user_id = p_user_id 
    AND notification_type = p_notification_type;
  
  -- Default to true if no preference set
  RETURN COALESCE(v_enabled, true);
END;
$$;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_email_prefs_user_id ON email_notification_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_email_prefs_type ON email_notification_preferences(notification_type);
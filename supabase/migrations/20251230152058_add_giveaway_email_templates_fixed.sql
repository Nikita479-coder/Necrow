/*
  # Add Giveaway Email Templates

  1. Email Templates
    - giveaway_ticket_earned
    - giveaway_winner_notification
    - giveaway_draw_reminder
    - fee_voucher_expiring

  2. Updates notification types constraint
*/

-- Update notification type constraint to include giveaway types
DO $$
BEGIN
  ALTER TABLE notifications
  DROP CONSTRAINT IF EXISTS notifications_notification_type_check;
  
  ALTER TABLE notifications
  ADD CONSTRAINT notifications_notification_type_check
  CHECK (notification_type IN (
    'trade', 'deposit', 'withdrawal', 'kyc', 'security', 'reward', 'system',
    'referral', 'staking', 'copy_trade', 'pending_copy_trade', 'vip_upgrade',
    'tp_hit', 'sl_hit', 'liquidation', 'bonus', 'affiliate_payout',
    'deposit_confirmed', 'deposit_pending', 'withdrawal_approved', 'withdrawal_rejected',
    'giveaway_ticket_earned', 'giveaway_winner', 'giveaway_prize_credited', 
    'giveaway_draw_reminder', 'fee_voucher_earned', 'fee_voucher_expiring'
  ));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Insert Giveaway Email Templates with correct category
INSERT INTO email_templates (name, subject, body, category, variables, is_active)
VALUES 
(
  'giveaway_ticket_earned',
  'You Earned {{ticket_count}} Giveaway Tickets!',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
    <div style="text-align: center; margin-bottom: 30px;">
      <h1 style="color: #f0b90b; margin: 0; font-size: 28px;">Giveaway Tickets Earned!</h1>
    </div>
    <div style="background: linear-gradient(135deg, #1a1d21 0%, #2a2d31 100%); border-radius: 16px; padding: 30px; border: 1px solid #f0b90b33;">
      <p style="color: #ffffff; font-size: 16px; margin-bottom: 20px;">Hi {{username}},</p>
      <p style="color: #9ca3af; font-size: 14px; line-height: 1.6;">
        Your deposit of <span style="color: #f0b90b; font-weight: bold;">{{deposit_amount}} USDT</span> has earned you:
      </p>
      <div style="background: #f0b90b15; border-radius: 12px; padding: 20px; text-align: center; margin: 20px 0;">
        <p style="color: #f0b90b; font-size: 48px; font-weight: bold; margin: 0;">{{ticket_count}}</p>
        <p style="color: #9ca3af; font-size: 14px; margin: 5px 0 0 0;">TICKETS</p>
      </div>
      <p style="color: #9ca3af; font-size: 14px; line-height: 1.6;">
        Tier: {{tier_name}} | Campaign: {{campaign_name}} | Eligible: {{eligible_date}}
      </p>
    </div>
  </div>
</body>
</html>',
  'promotion',
  '["username", "deposit_amount", "ticket_count", "tier_name", "campaign_name", "eligible_date"]',
  true
),
(
  'giveaway_winner_notification',
  'Congratulations! You Won {{prize_name}}!',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
    <div style="text-align: center; margin-bottom: 30px;">
      <h1 style="color: #f0b90b; margin: 0; font-size: 32px;">YOU WON!</h1>
    </div>
    <div style="background: linear-gradient(135deg, #1a1d21 0%, #2a2d31 100%); border-radius: 16px; padding: 30px; border: 2px solid #f0b90b;">
      <p style="color: #ffffff; font-size: 16px; margin-bottom: 20px;">Congratulations {{username}}!</p>
      <p style="color: #9ca3af; font-size: 14px;">You won in the {{campaign_name}}!</p>
      <div style="background: #f0b90b15; border-radius: 12px; padding: 25px; text-align: center; margin: 25px 0;">
        <p style="color: #ffffff; font-size: 24px; font-weight: bold; margin: 0;">{{prize_name}}</p>
        <p style="color: #f0b90b; font-size: 36px; font-weight: bold; margin: 10px 0 0 0;">{{prize_value}}</p>
      </div>
      <p style="color: #9ca3af; font-size: 14px;">Your prize has been credited to your account.</p>
    </div>
  </div>
</body>
</html>',
  'promotion',
  '["username", "campaign_name", "prize_name", "prize_value"]',
  true
),
(
  'giveaway_draw_reminder',
  'Draw Tomorrow! You Have {{ticket_count}} Tickets',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
    <div style="text-align: center; margin-bottom: 30px;">
      <h1 style="color: #f0b90b; margin: 0; font-size: 28px;">Draw Tomorrow!</h1>
    </div>
    <div style="background: linear-gradient(135deg, #1a1d21 0%, #2a2d31 100%); border-radius: 16px; padding: 30px; border: 1px solid #f0b90b33;">
      <p style="color: #ffffff; font-size: 16px; margin-bottom: 20px;">Hi {{username}},</p>
      <p style="color: #9ca3af; font-size: 14px;">The {{campaign_name}} draw is tomorrow!</p>
      <div style="background: #f0b90b15; border-radius: 12px; padding: 20px; text-align: center; margin: 20px 0;">
        <p style="color: #9ca3af; font-size: 14px; margin: 0 0 5px 0;">Your Tickets</p>
        <p style="color: #f0b90b; font-size: 48px; font-weight: bold; margin: 0;">{{ticket_count}}</p>
      </div>
      <p style="color: #9ca3af; font-size: 14px;">Draw Date: {{draw_date}} | Prize Pool: {{prize_pool}}</p>
    </div>
  </div>
</body>
</html>',
  'promotion',
  '["username", "campaign_name", "ticket_count", "draw_date", "prize_pool"]',
  true
),
(
  'fee_voucher_expiring',
  'Your Fee Voucher Expires in {{days_left}} Days',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
    <div style="text-align: center; margin-bottom: 30px;">
      <h1 style="color: #f59e0b; margin: 0; font-size: 28px;">Fee Voucher Expiring!</h1>
    </div>
    <div style="background: linear-gradient(135deg, #1a1d21 0%, #2a2d31 100%); border-radius: 16px; padding: 30px; border: 1px solid #f59e0b33;">
      <p style="color: #ffffff; font-size: 16px; margin-bottom: 20px;">Hi {{username}},</p>
      <p style="color: #9ca3af; font-size: 14px;">Your fee voucher is expiring soon!</p>
      <div style="background: #f59e0b15; border-radius: 12px; padding: 20px; text-align: center; margin: 20px 0;">
        <p style="color: #f59e0b; font-size: 36px; font-weight: bold; margin: 0;">{{voucher_balance}} USDT</p>
        <p style="color: #ef4444; font-size: 14px; margin: 10px 0 0 0;">Expires in {{days_left}} days</p>
      </div>
      <p style="color: #9ca3af; font-size: 14px;">Trade now to use your voucher and save on fees.</p>
    </div>
  </div>
</body>
</html>',
  'alert',
  '["username", "voucher_balance", "days_left"]',
  true
)
ON CONFLICT (name) DO UPDATE SET
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  variables = EXCLUDED.variables,
  updated_at = now();

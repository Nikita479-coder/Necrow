/*
  # Add VIP Templates and Bonuses

  ## Description
  - Adds 'vip' category to email templates
  - Creates VIP retention email templates
  - Creates VIP retention bonus types
  - Updates constraints to include all existing categories
*/

-- Add 'vip' to allowed email template categories
ALTER TABLE email_templates DROP CONSTRAINT IF EXISTS email_templates_category_check;
ALTER TABLE email_templates ADD CONSTRAINT email_templates_category_check 
  CHECK (category = ANY (ARRAY['welcome'::text, 'kyc'::text, 'bonus'::text, 'promotion'::text, 'alert'::text, 'trading'::text, 'general'::text, 'vip'::text]));

-- Update bonus types category constraint to include all existing categories
ALTER TABLE bonus_types DROP CONSTRAINT IF EXISTS bonus_types_category_check;
ALTER TABLE bonus_types ADD CONSTRAINT bonus_types_category_check 
  CHECK (category = ANY (ARRAY['welcome'::text, 'deposit'::text, 'referral'::text, 'trading'::text, 'loyalty'::text, 'promotion'::text, 'vip_retention'::text, 'special'::text, 'vip'::text]));

-- Insert VIP retention email templates
INSERT INTO email_templates (
  name,
  subject,
  body,
  category,
  variables,
  is_active
) VALUES
(
  'VIP Tier Drop - 1 Level',
  'We Miss You at {{previous_tier}}!',
  '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;"><div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px; text-align: center; color: white;"><h1 style="margin: 0; font-size: 32px;">We Miss You!</h1></div><div style="padding: 40px; background: #f7f7f7;"><p style="font-size: 18px; color: #333;">Hi {{user_name}},</p><p style="font-size: 16px; color: #555; line-height: 1.6;">We noticed your VIP status has changed from <strong>{{previous_tier}}</strong> to <strong>{{new_tier}}</strong>.</p><div style="background: white; border-left: 4px solid #667eea; padding: 20px; margin: 30px 0;"><h3 style="margin-top: 0; color: #667eea;">Exclusive Retention Offer</h3><p style="font-size: 24px; color: #333; margin: 10px 0;"><strong>{{bonus_amount}} {{bonus_currency}}</strong> Bonus</p></div><div style="text-align: center; margin: 30px 0;"><a href="{{platform_url}}" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-size: 18px; font-weight: bold;">View Your Account</a></div><p>Your 30-day volume: <strong>{{volume_30d}} USDT</strong></p><p style="font-size: 16px; color: #555;">Best regards,<br><strong>The VIP Team</strong></p></div></div>',
  'vip',
  '["user_name", "previous_tier", "new_tier", "bonus_amount", "bonus_currency", "volume_30d", "platform_url"]',
  true
),
(
  'VIP Major Downgrade - 2+ Levels',
  '{{user_name}}, Let''s Get You Back to {{previous_tier}}!',
  '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;"><div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 40px; text-align: center; color: white;"><h1 style="margin: 0; font-size: 32px;">We Want You Back!</h1></div><div style="padding: 40px; background: #f7f7f7;"><p style="font-size: 18px; color: #333;">Hi {{user_name}},</p><p style="font-size: 16px; color: #555; line-height: 1.6;">We noticed a significant change in your VIP status from <strong>{{previous_tier}}</strong> to <strong>{{new_tier}}</strong>.</p><div style="background: white; border: 2px solid #f5576c; padding: 25px; margin: 30px 0; border-radius: 10px; text-align: center;"><h3 style="margin-top: 0; color: #f5576c;">Special Recovery Package</h3><p style="font-size: 32px; color: #333; margin: 15px 0; font-weight: bold;">{{bonus_amount}} {{bonus_currency}}</p></div><div style="text-align: center; margin: 30px 0;"><a href="{{platform_url}}" style="display: inline-block; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 18px 50px; text-decoration: none; border-radius: 5px; font-size: 20px; font-weight: bold;">View Your Account</a></div><p>Previous Tier: {{previous_tier}} | Current: {{new_tier}} | Volume: {{volume_30d}} USDT</p><p style="font-size: 16px; color: #555;">Best regards,<br><strong>Your VIP Success Team</strong></p></div></div>',
  'vip',
  '["user_name", "previous_tier", "new_tier", "bonus_amount", "bonus_currency", "volume_30d", "platform_url"]',
  true
),
(
  'VIP to Regular Downgrade',
  '{{user_name}}, Special Offer to Rejoin VIP!',
  '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;"><div style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); padding: 40px; text-align: center; color: white;"><h1 style="margin: 0; font-size: 32px;">Come Back to VIP!</h1></div><div style="padding: 40px; background: #f7f7f7;"><p style="font-size: 18px; color: #333;">Hi {{user_name}},</p><p style="font-size: 16px; color: #555; line-height: 1.6;">Your VIP status has changed to <strong>Regular</strong> tier. We miss having you as part of our exclusive VIP community!</p><div style="background: white; padding: 30px; margin: 30px 0; border-radius: 10px; text-align: center;"><h3 style="margin-top: 0; color: #4facfe;">Welcome Back Bonus</h3><p style="font-size: 36px; color: #333; margin: 15px 0; font-weight: bold;">{{bonus_amount}} {{bonus_currency}}</p></div><div style="text-align: center; margin: 30px 0;"><a href="{{platform_url}}" style="display: inline-block; background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); color: white; padding: 18px 50px; text-decoration: none; border-radius: 5px; font-size: 20px; font-weight: bold;">View Your Account</a></div><p>Regain VIP status by reaching the minimum trading volume in the next 30 days!</p><p style="font-size: 16px; color: #555;">Best regards,<br><strong>The VIP Team</strong></p></div></div>',
  'vip',
  '["user_name", "bonus_amount", "bonus_currency", "platform_url"]',
  true
)
ON CONFLICT (name) DO UPDATE SET
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  category = EXCLUDED.category,
  variables = EXCLUDED.variables,
  updated_at = NOW();

-- Insert VIP retention bonus types
INSERT INTO bonus_types (
  name,
  description,
  default_amount,
  category,
  expiry_days,
  is_active
) VALUES
(
  'VIP Tier Drop - 1 Level Retention',
  'Retention bonus for users who dropped 1 VIP tier',
  100.00,
  'vip_retention',
  30,
  true
),
(
  'VIP Tier Drop - 2 Levels Retention',
  'Retention bonus for users who dropped 2 VIP tiers',
  250.00,
  'vip_retention',
  30,
  true
),
(
  'VIP Tier Drop - 3+ Levels Retention',
  'Retention bonus for users who dropped 3 or more VIP tiers',
  500.00,
  'vip_retention',
  30,
  true
),
(
  'VIP to Regular Retention',
  'Special retention bonus for users who fell from VIP to Regular status',
  150.00,
  'vip_retention',
  30,
  true
)
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  default_amount = EXCLUDED.default_amount,
  category = EXCLUDED.category,
  updated_at = NOW();
/*
  # Add Referral Program Email Template and Bonus Type

  ## Summary
  Creates a new email template for the "Earn Together" referral program,
  targeting existing users to encourage them to invite friends and build
  passive income through lifetime commissions.

  ## New Templates
  - Earn Together Referral Program - Email promoting referral benefits

  ## New Bonus Types
  - Referral Welcome Bonus ($20) - Awarded to both referrer and referee on first deposit

  ## Changes
  1. Insert new referral-focused email template
  2. Insert referral welcome bonus type for the $20 instant reward
*/

-- Insert referral program email template
INSERT INTO email_templates (name, subject, body, category, variables, is_active, created_by) VALUES
(
  'Earn Together Referral Program',
  'Share {{platform_name}}, Earn Together: New Referral Program is Live!',
  'Your Network is Your Net Worth, {{FirstName}}.

Introducing the {{platform_name}} "Earn Together" Referral Program—a powerful way for you to build a passive income stream simply by sharing the platform you trust.

A Genuine Win-Win:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👥 You (The Referrer) Earn:
   • Up to 70% commission on your referred friend''s net trading fees
   • Lifetime earnings that grow with their activity
   • Real-time payouts in USDT

🎁 Your Friend (The Referee) Earns:
   • Up to 15% rebate on their trading fees forever
   • $20 welcome bonus instantly after completing their first qualified deposit
   • Access to all premium trading features

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Why This Program Stands Out:

✓ Long-Term Earnings
  Unlike one-off payments, you earn from your referee''s activity forever, 
  aligning with their growth and success.

✓ Daily Payouts
  Commissions are calculated and distributed in real-time in USDT directly 
  to your wallet. No waiting, no delays.

✓ Simple Sharing
  Your unique referral link and dashboard make tracking earnings effortless. 
  See exactly who joined and how much you''ve earned.

✓ No Limits
  Refer as many traders as you want. The more you share, the more you earn.

Start Building Your Earnings Today:

Your Unique Referral Link: {{referral_link}}

Track Your Earnings: Visit your referral dashboard at {{website_url}}/referral to see:
  • Number of active referrals
  • Total commission earned
  • Real-time earnings updates
  • Your referee activity

Pro Tips for Maximum Earnings:

1. Share with active traders who will generate volume
2. Explain the mutual benefits (they get rebates too)
3. Post your link in trading communities you trust
4. Update your social media bio with your referral link

Questions About the Program?

• How do I get my referral link? Log in and visit {{website_url}}/referral
• When do I get paid? Commissions are paid in real-time as fees are collected
• Is there a limit? No limit on referrals or earnings
• What if my friend stops trading? You still keep all earnings from their past activity

Thank you for being part of our community, {{FirstName}}. Together, we grow stronger.

Best regards,
The {{platform_name}} Team

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This email was sent to {{email}}. Manage your communication preferences in your account settings.',
  'promotion',
  '["{{FirstName}}", "{{email}}", "{{platform_name}}", "{{support_email}}", "{{website_url}}", "{{referral_link}}"]'::jsonb,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

-- Insert referral welcome bonus (if not exists)
INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, created_by) VALUES
(
  'Referral Welcome Bonus - Both Parties',
  'Awarded to both the referrer and referee when the referee completes their first qualified deposit. $20 USDT instant reward.',
  20.00,
  'referral',
  NULL,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

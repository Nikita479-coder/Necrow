/*
  # Create Sample Email Templates and Bonus Types

  ## Summary
  Populates the database with pre-configured email templates and bonus types
  that admins can use immediately or modify as needed.

  ## New Data

  ### Email Templates
  1. Welcome Email - Greet new users
  2. KYC Approved - Notify users of KYC approval
  3. KYC Rejected - Notify users of KYC rejection
  4. Bonus Awarded - Notify users when they receive a bonus
  5. Account Suspended - Notify users of account suspension
  6. Promotion Announcement - Generic promotional email
  7. Trading Alert - High risk position warning

  ### Bonus Types
  1. Welcome Bonus - For new users
  2. Deposit Bonus - For making deposits
  3. Trading Bonus - For reaching trading milestones
  4. VIP Bonus - For VIP tier upgrades
  5. Referral Bonus - For successful referrals
  6. Special Promotion - Limited time offers
*/

-- Insert sample email templates
INSERT INTO email_templates (name, subject, body, category, variables, is_active, created_by) VALUES
(
  'Welcome Email',
  'Welcome to {{platform_name}}, {{username}}!',
  'Hello {{username}},

Welcome to {{platform_name}}! We''re excited to have you join our growing community of traders.

Your account has been successfully created and you can now start exploring our platform. Here''s what you can do:

• Complete your KYC verification to unlock full trading features
• Make your first deposit and start trading
• Explore our futures, spot, and copy trading features
• Refer friends and earn commissions

If you have any questions, our support team is here to help at {{support_email}}.

Happy trading!

Best regards,
The {{platform_name}} Team',
  'welcome',
  '["{{username}}", "{{email}}", "{{platform_name}}", "{{support_email}}"]'::jsonb,
  true,
  NULL
),
(
  'KYC Approved',
  'Your KYC Verification Has Been Approved',
  'Hello {{username}},

Great news! Your KYC verification has been approved and your account is now at Level {{kyc_level}}.

You can now enjoy:
• Higher deposit and withdrawal limits
• Access to advanced trading features
• Priority customer support
• Lower trading fees

Thank you for completing your verification. If you have any questions, please contact us at {{support_email}}.

Best regards,
The {{platform_name}} Team',
  'kyc',
  '["{{username}}", "{{kyc_level}}", "{{platform_name}}", "{{support_email}}"]'::jsonb,
  true,
  NULL
),
(
  'KYC Rejected',
  'Your KYC Verification Requires Attention',
  'Hello {{username}},

We''ve reviewed your KYC submission and unfortunately we need additional information to complete your verification.

Common reasons for rejection:
• Document quality is too low or unclear
• Information doesn''t match
• Expired identification documents

Please submit clear, valid documents at your earliest convenience. If you have questions about the requirements, please contact us at {{support_email}}.

Best regards,
The {{platform_name}} Team',
  'kyc',
  '["{{username}}", "{{platform_name}}", "{{support_email}}"]'::jsonb,
  true,
  NULL
),
(
  'Bonus Awarded',
  'You''ve Received a Bonus: ${{bonus_amount}}',
  'Hello {{username}},

Congratulations! You''ve been awarded a bonus of ${{bonus_amount}} USDT!

This bonus has been automatically credited to your account and is ready to use. Check your wallet to see your updated balance.

{{custom_message}}

Keep up the great trading!

Best regards,
The {{platform_name}} Team',
  'bonus',
  '["{{username}}", "{{bonus_amount}}", "{{custom_message}}", "{{platform_name}}"]'::jsonb,
  true,
  NULL
),
(
  'Account Suspended',
  'Important: Your Account Has Been Suspended',
  'Hello {{username}},

Your account has been temporarily suspended.

Reason: {{custom_message}}

If you believe this is an error or would like to appeal this decision, please contact our support team at {{support_email}} immediately.

Best regards,
The {{platform_name}} Team',
  'alert',
  '["{{username}}", "{{custom_message}}", "{{platform_name}}", "{{support_email}}"]'::jsonb,
  true,
  NULL
),
(
  'Promotion Announcement',
  'Special Promotion: {{custom_message}}',
  'Hello {{username}},

We have an exciting promotion just for you!

{{custom_message}}

Don''t miss out on this limited-time opportunity. Visit {{website_url}} to learn more.

Best regards,
The {{platform_name}} Team',
  'promotion',
  '["{{username}}", "{{custom_message}}", "{{platform_name}}", "{{website_url}}"]'::jsonb,
  true,
  NULL
),
(
  'Trading Risk Alert',
  'Important: Position Risk Warning',
  'Hello {{username}},

This is an important notification regarding your trading account.

{{custom_message}}

We recommend reviewing your open positions and considering risk management strategies. If you need assistance, please contact us at {{support_email}}.

Best regards,
The {{platform_name}} Risk Management Team',
  'trading',
  '["{{username}}", "{{custom_message}}", "{{platform_name}}", "{{support_email}}"]'::jsonb,
  true,
  NULL
);

-- Insert sample bonus types
INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, created_by) VALUES
(
  'Welcome Bonus',
  'Bonus awarded to new users upon completing registration and initial verification',
  50.00,
  'welcome',
  30,
  true,
  NULL
),
(
  'First Deposit Bonus',
  'Bonus awarded when users make their first deposit (typically a percentage match)',
  100.00,
  'deposit',
  30,
  true,
  NULL
),
(
  'Trading Volume Milestone',
  'Bonus awarded when users reach specific trading volume milestones',
  200.00,
  'trading',
  NULL,
  true,
  NULL
),
(
  'VIP Tier Upgrade',
  'Bonus awarded when users are promoted to a new VIP tier',
  500.00,
  'vip',
  NULL,
  true,
  NULL
),
(
  'Referral Success Bonus',
  'Bonus awarded when a referred user completes their first trade',
  25.00,
  'referral',
  90,
  true,
  NULL
),
(
  'Monthly Loyalty Bonus',
  'Monthly bonus for active traders based on their trading activity',
  150.00,
  'promotion',
  30,
  true,
  NULL
),
(
  'Special Event Bonus',
  'One-time bonus for special events, competitions, or circumstances',
  75.00,
  'special',
  NULL,
  true,
  NULL
),
(
  'Compensation Bonus',
  'Bonus awarded to users as compensation for issues or errors',
  50.00,
  'special',
  NULL,
  true,
  NULL
);

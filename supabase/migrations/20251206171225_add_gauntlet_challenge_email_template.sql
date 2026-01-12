/*
  # Add The Gauntlet Challenge Email Template

  ## Summary
  Creates a new email template for "The Gauntlet Challenge" - a week-long discipline test
  where traders must achieve 15% profit with zero losing days to win a 5,000 USDT bonus.

  ## Changes
  1. Insert new email template for The Gauntlet Challenge
  2. Create corresponding bonus type for the challenge
*/

-- Insert The Gauntlet Challenge email template
INSERT INTO email_templates (name, subject, body, category, variables, is_active, created_by) VALUES
(
  'The Gauntlet Challenge',
  '{{FirstName}}, Do You Have the Discipline? Survive The Gauntlet for a 5x Payout',
  'This is not for everyone. The Gauntlet is a merciless, week-long challenge that filters for supreme discipline. The reward is equally extreme.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚔️ THE GAUNTLET RULES

Opt-in with 1,000 USDT of your capital (can be spot or futures).

Goal: Achieve a 15% net profit on that capital within 5 trading days.

The Catch: You must close every single day green (net positive PnL). One red day, and you''re out.

The Reward: If you succeed, we credit you a 5,000 USDT bonus (5x your stake).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 CHALLENGE REQUIREMENTS

✓ Minimum opt-in capital: 1,000 USDT
✓ Duration: 5 consecutive trading days
✓ Target: 15% net profit (150 USDT minimum on 1,000 USDT stake)
✓ Daily requirement: EVERY day must close with positive PnL
✓ One losing day = automatic disqualification
✓ Success = 5,000 USDT bonus (5x payout)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏰ CHALLENGE TIMELINE

Start Date: {{StartDate}}
End Date: {{EndDate}}
Trading Days: Monday - Friday (5 days)
Daily Cutoff: 23:59 UTC each day
Final PnL Check: {{EndDate}} at 23:59 UTC

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 WHY THIS IS THE ULTIMATE TEST

Most traders can hit a 15% profit target easily. But can you do it while staying green EVERY SINGLE DAY?

This challenge tests:
• Risk Management: Can you protect your capital daily?
• Discipline: Can you resist revenge trading after small losses?
• Consistency: Can you stack green days without blowing up?
• Patience: Can you walk away when conditions aren''t favorable?

One bad day ends everything. This separates the disciplined from the gamblers.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 HOW TO PARTICIPATE

1. Contact our support team before {{StartDate}}
   Tell them you want to enter The Gauntlet Challenge

2. Designate your 1,000 USDT challenge capital
   This can be in spot wallets, futures wallets, or a combination

3. Trade for 5 consecutive days
   We track your daily PnL automatically

4. Hit 15% profit with zero red days
   Every day must close positive

5. Contact support after completion
   We''ll verify your results and credit your 5,000 USDT bonus within 24 hours

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚨 DISQUALIFICATION CONDITIONS

You are instantly eliminated if:
• Any single day closes with negative PnL
• You withdraw capital before the challenge ends
• Your designated capital falls below 850 USDT at any daily cutoff
• You attempt to manipulate trades or timestamps
• You fail to achieve 15% total profit by day 5

No exceptions. No second chances. The Gauntlet is unforgiving.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💰 CLAIMING YOUR BONUS

If you successfully complete The Gauntlet:

1. Contact our support team immediately after {{EndDate}} 23:59 UTC
2. Reference "Gauntlet Challenge Completion"
3. Our team will verify your trading history
4. 5,000 USDT will be credited to your main wallet within 24 hours

You MUST contact support to claim your bonus. Bonuses are not automatically credited.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏆 ESTIMATED SUCCESS RATE: < 5%

Based on similar challenges on other platforms, fewer than 1 in 20 traders complete this successfully.

Most fail on Day 2 or Day 3 when they try to force trades to "catch up."

The winners are patient. They take small, calculated wins. They walk away when the market isn''t cooperating.

Can you be in that elite 5%?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚔️ ACCEPT THE CHALLENGE

Challenge Period: {{StartDate}} - {{EndDate}}
Entry Deadline: {{StartDate}} 00:00 UTC
Minimum Capital: 1,000 USDT
Bonus Payout: 5,000 USDT

[CONTACT SUPPORT TO ENTER] → {{website_url}}/support
[VIEW FULL GAUNTLET RULES] → {{website_url}}/events/gauntlet

This is about consistency, not luck. Are your risk management and patience bulletproof?

Accept the challenge if you dare, {{FirstName}}.

For the disciplined only,
The {{platform_name}} Team

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Challenge Rules & Terms:
• Minimum 1,000 USDT opt-in capital required
• Must achieve 15% net profit (150 USDT minimum) over 5 days
• ALL 5 days must close with positive PnL
• One losing day = instant disqualification
• Bonus must be claimed via support ticket after completion
• Capital cannot be withdrawn during challenge period
• {{platform_name}} reserves the right to audit all trades
• Wash trading or manipulation = permanent disqualification
• Bonus paid in USDT to main wallet after verification

Full Terms: {{website_url}}/terms/gauntlet-challenge

This email was sent to {{email}}.',
  'promotion',
  '["{{FirstName}}", "{{email}}", "{{platform_name}}", "{{website_url}}", "{{StartDate}}", "{{EndDate}}"]'::jsonb,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

-- Create bonus type for The Gauntlet Challenge
INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active) VALUES
(
  'Gauntlet Challenge 5,000 USDT',
  'Week-long discipline test: Achieve 15% profit with zero losing days over 5 consecutive trading days. Entry requires 1,000 USDT capital commitment. Must contact support to claim bonus after successful completion.',
  5000.00,
  'promotion',
  30,
  true
)
ON CONFLICT (name) DO NOTHING;

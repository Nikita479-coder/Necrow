/*
  # Add Performance Bonus Program Email Template and Bonus Types

  ## Summary
  Creates a new email template for active/experienced traders with a tiered
  bonus program based on net deposits and trading volume. Also adds three
  new bonus types for the different performance tiers.

  ## New Templates
  - Performance Bonus Program - Email targeting experienced traders with tiered bonuses

  ## New Bonus Types
  - Performance Tier 1 ($100) - $3K deposit + $1M volume
  - Performance Tier 2 ($800) - $50K deposit + $15M volume  
  - Performance Tier 3 ($30,000) - $250K deposit + $150M volume

  ## Changes
  1. Insert new email template with complete performance bonus details
  2. Insert three tiered bonus types for the program
*/

-- Insert performance bonus email template
INSERT INTO email_templates (name, subject, body, category, variables, is_active, created_by) VALUES
(
  'Performance Bonus Program - Active Trader',
  '{{FirstName}}, Your Trading Volume Deserves Up to $30,000 in Rewards',
  'Unlock Tiered Bonuses Matched to Your Strategy, {{FirstName}}.

Serious capital and volume deserve serious recognition. We are launching an exclusive program that rewards your deposit and trading activity with bonuses of up to $30,000 USDT.

How the Performance Bonus Program Works:
We''ve designed a clear, tiered structure. The more you commit, the greater your reward.

╔═══════════════════════════════════════════════════════════════╗
║ Your Net Deposit │ Your 30-Day Trading Volume │ Your Bonus   ║
╠═══════════════════════════════════════════════════════════════╣
║ ≥ $3,000         │ ≥ $1M                      │ $100 USDT    ║
║ ≥ $50,000        │ ≥ $15M                     │ $800 USDT    ║
║ ≥ $250,000       │ ≥ $150 Million             │ $30,000 USDT ║
╚═══════════════════════════════════════════════════════════════╝

Terms: Bonuses are awarded on qualifying net deposits and trading volume within 30 days of program entry. Taker orders required for top tiers.

For the Institutional Mindset:

✓ VIP Fee Structure: Qualifying traders gain access to our VIP program with progressively lower trading fees.

✓ Advanced Tools: Enjoy institutional-grade charting, multiple order types, and high liquidity on major pairs.

✓ Dedicated Support: Priority access to our account management team.

Ready to Unlock Your Bonus?

Log in to your account at {{website_url}} to review your current deposit and trading volume. Our system automatically tracks your progress and awards bonuses when you qualify.

Questions? Our dedicated trader support team is available 24/7 at {{support_email}}.

Best regards,
The {{platform_name}} VIP Team

---

This email was sent to {{email}}. If you no longer wish to receive performance bonus updates, please adjust your email preferences in your account settings.',
  'promotion',
  '["{{FirstName}}", "{{email}}", "{{platform_name}}", "{{support_email}}", "{{website_url}}"]'::jsonb,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

-- Insert tiered performance bonus types
INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, created_by) VALUES
(
  'Performance Tier 1 - Entry Level',
  'Awarded for net deposit ≥$3,000 and 30-day trading volume ≥$1M. Entry-level performance bonus for active traders.',
  100.00,
  'trading',
  NULL,
  true,
  NULL
),
(
  'Performance Tier 2 - Advanced',
  'Awarded for net deposit ≥$50,000 and 30-day trading volume ≥$15M. Advanced performance bonus for serious traders.',
  800.00,
  'trading',
  NULL,
  true,
  NULL
),
(
  'Performance Tier 3 - Institutional',
  'Awarded for net deposit ≥$250,000 and 30-day trading volume ≥$150M. Institutional-level performance bonus for high-volume traders with taker order requirements.',
  30000.00,
  'trading',
  NULL,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

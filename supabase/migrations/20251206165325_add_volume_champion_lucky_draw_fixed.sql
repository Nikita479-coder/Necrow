/*
  # Add Volume Champion Lucky Draw Email Template and System

  ## Summary
  Creates a new email template promoting the Volume Champion program where
  users earn 1 lucky draw ticket for every $10,000 in trading volume.
  Monthly prize: 1 BTC.

  ## New Templates
  - Volume Champion Lucky Draw - Email promoting volume-based lucky draw tickets

  ## New Bonus Types
  - Monthly 1 BTC Lucky Draw Winner - Grand prize for monthly draw
  - Lucky Draw Ticket - Tracking entry for volume-based draws

  ## New Tables
  - lucky_draw_tickets - Tracks user tickets earned per month based on volume
  - lucky_draw_winners - Records monthly draw winners and prize distribution

  ## Changes
  1. Insert new volume champion email template
  2. Insert bonus types for lucky draw system
  3. Creates tables for ticket tracking and winner records
  4. Creates functions to calculate tickets and get user stats
*/

-- Insert Volume Champion email template
INSERT INTO email_templates (name, subject, body, category, variables, is_active, created_by) VALUES
(
  'Volume Champion Lucky Draw',
  '🏆 Become a Volume Champion: Every $10K Traded = 1 Chance to Win 1 BTC!',
  'Trade Big. Win Bigger, {{FirstName}}.

Introducing the {{platform_name}} Volume Champion Program—where your trading activity automatically enters you into our exclusive Monthly 1 BTC Lucky Draw.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎰 How It Works:

For Every $10,000 You Trade → You Get 1 Lucky Draw Ticket

Simple Math:
• Trade $10,000 = 1 ticket
• Trade $50,000 = 5 tickets
• Trade $100,000 = 10 tickets
• Trade $1,000,000 = 100 tickets

More volume = More chances to win. There''s no limit!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💰 Monthly Grand Prize: 1 BTC

Every month, we randomly draw ONE lucky winner from all qualified tickets.
The prize? A full Bitcoin—directly deposited into your wallet.

Current Month Stats:
• Total Tickets Issued: {{total_tickets}}
• Your Current Tickets: {{user_tickets}}
• Your Win Probability: {{win_percentage}}%
• Days Until Draw: {{days_until_draw}}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Why Volume Champion?

✓ Automatic Entry
  No manual entry needed. Trade as you normally do, and tickets accumulate 
  automatically. Every futures trade, every swap counts toward your total.

✓ Unlimited Tickets
  There''s no cap on how many tickets you can earn. The more you trade, 
  the better your odds.

✓ Fair & Transparent
  Winner selection is provably random. All entries and results are recorded 
  on-chain for complete transparency.

✓ Monthly Opportunities
  Didn''t win this month? Your new volume next month gives you fresh chances. 
  Every month is a new opportunity.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This Isn''t a Single Promotion—It''s a Reward Menu

Volume Champion is just one way to earn on {{platform_name}}. Choose what fits your trading style:

🎯 Referral Program: Earn up to 70% commission on friends'' trading fees
🏅 VIP Levels: Unlock lower fees and exclusive rebates
💎 Staking Rewards: Earn passive income on idle assets
🎁 Trading Bonuses: Claim deposit match and welcome rewards

Explore Features, Claim Rewards:
[SEE THE FULL REWARD MENU] → {{website_url}}/rewards

Track your current lucky draw tickets and volume in real-time:
[VIEW YOUR TICKETS] → {{website_url}}/rewards

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pro Tips to Maximize Your Chances:

1. Focus on High-Volume Strategies
   Scalping and day trading naturally generate more volume = more tickets

2. Use Leverage Wisely
   Leveraged positions increase your notional volume (but trade responsibly)

3. Diversify Your Pairs
   All trading pairs count. Spread across markets to increase total volume

4. Check Your Progress Daily
   Monitor your ticket count in the Rewards Hub to stay motivated

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Important Details:

Draw Date: Last day of each month at 23:59 UTC
Qualifying Volume: All completed futures and swap trades
Minimum: At least $10,000 total volume to qualify (1 ticket minimum)
Winner Notification: Within 24 hours via email and platform notification
Prize Distribution: Instant deposit to winner''s main wallet in BTC

Previous Winners:
{{previous_winners}}

Could you be next?

Discover. Earn. Repeat.

Start trading today and watch your tickets add up. Every trade brings you 
closer to winning 1 BTC.

[START TRADING NOW] → {{website_url}}/futures

Good luck, {{FirstName}}! May the odds be ever in your favor.

Best regards,
The {{platform_name}} Team

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This email was sent to {{email}}. Manage your communication preferences in your account settings.
Terms and Conditions apply. Visit {{website_url}}/terms for full details.',
  'promotion',
  '["{{FirstName}}", "{{email}}", "{{platform_name}}", "{{website_url}}", "{{total_tickets}}", "{{user_tickets}}", "{{win_percentage}}", "{{days_until_draw}}", "{{previous_winners}}"]'::jsonb,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

-- Insert bonus types for lucky draw system (using valid categories)
INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, created_by) VALUES
(
  'Monthly 1 BTC Lucky Draw Winner',
  'Grand prize for winning the monthly Volume Champion lucky draw. 1 full Bitcoin deposited directly to winner''s wallet.',
  1.00,
  'special',
  NULL,
  true,
  NULL
),
(
  'Lucky Draw Ticket',
  'Entry ticket for monthly BTC lucky draw. Earned automatically: 1 ticket per $10,000 trading volume. No expiry, valid for current month draw.',
  0.00,
  'promotion',
  NULL,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

-- Create table for tracking lucky draw tickets
CREATE TABLE IF NOT EXISTS lucky_draw_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month_year text NOT NULL,
  tickets_earned integer NOT NULL DEFAULT 0,
  volume_traded numeric(20,2) NOT NULL DEFAULT 0,
  last_updated timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, month_year)
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_lucky_draw_tickets_month ON lucky_draw_tickets(month_year);
CREATE INDEX IF NOT EXISTS idx_lucky_draw_tickets_user ON lucky_draw_tickets(user_id);

-- Enable RLS
ALTER TABLE lucky_draw_tickets ENABLE ROW LEVEL SECURITY;

-- RLS Policies for lucky_draw_tickets
CREATE POLICY "Users can view own tickets"
  ON lucky_draw_tickets FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert tickets"
  ON lucky_draw_tickets FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update tickets"
  ON lucky_draw_tickets FOR UPDATE
  TO authenticated
  USING (true);

-- Create table for tracking draw winners
CREATE TABLE IF NOT EXISTS lucky_draw_winners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month_year text NOT NULL,
  prize_btc numeric(10,8) NOT NULL DEFAULT 1.0,
  total_tickets_in_draw integer NOT NULL,
  winner_tickets integer NOT NULL,
  drawn_at timestamptz DEFAULT now(),
  prize_paid boolean DEFAULT false,
  prize_paid_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(month_year)
);

-- Enable RLS
ALTER TABLE lucky_draw_winners ENABLE ROW LEVEL SECURITY;

-- RLS Policies for lucky_draw_winners
CREATE POLICY "Anyone can view winners"
  ON lucky_draw_winners FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert winners"
  ON lucky_draw_winners FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid()) = true
  );

CREATE POLICY "Admins can update winners"
  ON lucky_draw_winners FOR UPDATE
  TO authenticated
  USING (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid()) = true
  );

-- Function to calculate and update user tickets based on volume
CREATE OR REPLACE FUNCTION update_lucky_draw_tickets()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_month text;
  user_record record;
BEGIN
  current_month := to_char(now(), 'YYYY-MM');
  
  -- Calculate volume for all users for current month
  FOR user_record IN
    SELECT 
      user_id,
      SUM(size * entry_price) as total_volume
    FROM futures_positions
    WHERE 
      date_trunc('month', opened_at) = date_trunc('month', now())
    GROUP BY user_id
  LOOP
    -- Insert or update tickets
    INSERT INTO lucky_draw_tickets (
      user_id,
      month_year,
      tickets_earned,
      volume_traded,
      last_updated
    ) VALUES (
      user_record.user_id,
      current_month,
      FLOOR(user_record.total_volume / 10000)::integer,
      user_record.total_volume,
      now()
    )
    ON CONFLICT (user_id, month_year) 
    DO UPDATE SET
      tickets_earned = FLOOR(EXCLUDED.volume_traded / 10000)::integer,
      volume_traded = EXCLUDED.volume_traded,
      last_updated = now();
  END LOOP;
  
END;
$$;

-- Function to get user's current month tickets
CREATE OR REPLACE FUNCTION get_user_lucky_draw_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_month text;
  user_tickets integer;
  total_tickets integer;
  win_percentage numeric;
  result jsonb;
BEGIN
  current_month := to_char(now(), 'YYYY-MM');
  
  -- Get user tickets
  SELECT COALESCE(tickets_earned, 0)
  INTO user_tickets
  FROM lucky_draw_tickets
  WHERE user_id = p_user_id AND month_year = current_month;
  
  -- Get total tickets
  SELECT COALESCE(SUM(tickets_earned), 0)
  INTO total_tickets
  FROM lucky_draw_tickets
  WHERE month_year = current_month;
  
  -- Calculate win percentage
  IF total_tickets > 0 AND user_tickets > 0 THEN
    win_percentage := ROUND((user_tickets::numeric / total_tickets::numeric) * 100, 4);
  ELSE
    win_percentage := 0;
  END IF;
  
  result := jsonb_build_object(
    'user_tickets', user_tickets,
    'total_tickets', total_tickets,
    'win_percentage', win_percentage,
    'month', current_month
  );
  
  RETURN result;
END;
$$;

/*
  # Add Futures Frenzy 24-Hour Event System

  ## Summary
  Creates email template and bonus system for a 24-hour trading event called
  "Futures Frenzy" featuring:
  - Volume Ladder: Top 10 traders by volume win 500-5,000 USDT
  - Lottery Mania: 1 ticket per 10,000 USDT volume, 10 winners get 1,000 USDT each
  - Win-Streak Bonus: 5+ profitable trades = 50 USDT bonus

  ## New Templates
  - Futures Frenzy 24-Hour Blitz - Event announcement email

  ## New Bonus Types
  - Futures Frenzy Event Prize - Main event prizes (Volume Ladder & Lottery)
  - Win-Streak Bonus 50 USDT - 5+ profitable trades bonus

  ## New Tables
  - frenzy_events - Tracks scheduled 24-hour frenzy events
  - frenzy_participants - Tracks user participation and stats per event
  - frenzy_lottery_tickets - Tracks lottery tickets earned during event

  ## Changes
  1. Insert Futures Frenzy email template
  2. Insert two bonus types for the event
  3. Create tables for event tracking
  4. Create functions to track volume, lottery tickets, and win-streaks
*/

-- Insert Futures Frenzy email template
INSERT INTO email_templates (name, subject, body, category, variables, is_active, created_by) VALUES
(
  'Futures Frenzy 24-Hour Blitz',
  '{{FirstName}}, Mark Your Calendar: This {{DayOfWeek}} is the 24-Hour Futures Frenzy',
  'Clear Your Schedule for {{EventDate}}.

From 00:00 to 23:59 UTC, we''re triggering a 24-Hour Futures Frenzy with hyper-charged rewards. This is not your regular trading day—this is an all-out sprint for massive prizes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ FRENZY MECHANICS

This is a triple-threat event. Compete on the leaderboard, earn lottery tickets, and chase win-streaks. Multiple ways to win means maximum opportunity.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏆 VOLUME LADDER: Climb the Public Leaderboard

The more you trade, the higher you climb. The Top 10 traders by 24-hour futures volume win guaranteed prizes:

🥇 Rank 1: 5,000 USDT
🥈 Rank 2: 3,000 USDT
🥉 Rank 3: 2,000 USDT
🏅 Rank 4: 1,500 USDT
🏅 Rank 5: 1,200 USDT
🏅 Rank 6: 1,000 USDT
🏅 Rank 7: 800 USDT
🏅 Rank 8: 700 USDT
🏅 Rank 9: 600 USDT
🏅 Rank 10: 500 USDT

Total Prize Pool: 16,300 USDT

The leaderboard updates in REAL-TIME. Watch your rank climb with every trade. Maximum competition. Maximum transparency.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎰 LOTTERY MANIA: Every 10K USDT = 1 Ticket

Don''t think you''ll hit the Top 10? You still have a shot at winning BIG.

For every 10,000 USDT in futures volume you generate during the 24 hours, you automatically earn 1 lottery ticket.

• Trade 10,000 USDT = 1 ticket
• Trade 50,000 USDT = 5 tickets
• Trade 100,000 USDT = 10 tickets
• Trade 500,000 USDT = 50 tickets

At 23:59 UTC when the Frenzy ends, we draw 10 random winning tickets.
Each winner receives 1,000 USDT instantly deposited to their wallet.

Total Lottery Prize Pool: 10,000 USDT (10 winners × 1,000 USDT)

More volume = more tickets = higher odds of winning. No cap on tickets.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔥 WIN-STREAK BONUS: Skill-Based Reward

This isn''t just about volume—it''s about WINNING trades.

Any trader who closes 5 or more profitable trades during the 24-hour Frenzy earns an automatic 50 USDT bonus.

Requirements:
✓ Minimum 5 closed positions with positive PnL
✓ All trades must be opened AND closed during the Frenzy window
✓ Bonus paid automatically within 1 hour of event end

Show us your trading skills and stack that 50 USDT on top of your other winnings.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 EVENT DETAILS

Date: {{EventDate}}
Start Time: 00:00 UTC
End Time: 23:59 UTC (sharp cutoff)
Duration: Exactly 24 hours
Qualifying Markets: All futures pairs
Leaderboard: Live updates every 60 seconds
Prize Distribution: Within 2 hours of event end

Current Registered Participants: {{ParticipantCount}}
Estimated Total Prize Pool: 26,300+ USDT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 STRATEGIC PREPARATION

This is a sprint, not a marathon. Here''s how to prepare:

1. Pre-Load Your Futures Wallet
   Ensure you have sufficient margin BEFORE the event starts. No time to transfer funds mid-Frenzy.

2. Choose Your Pairs
   Scout volatile pairs with high liquidity. BTC, ETH, and major alts typically see the most action.

3. Set Your Risk Limits
   24 hours is long. Don''t blow your account in the first hour. Pace yourself.

4. Monitor the Leaderboard
   Real-time ranks visible throughout the event. Know where you stand.

5. Go for Win-Streaks
   Even if you''re not chasing volume prizes, 5 profitable trades = guaranteed 50 USDT.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CAN YOU WIN MULTIPLE PRIZES?

YES. Absolutely.

You can win ALL THREE categories in a single event:
• Volume Ladder prize (if you rank Top 10)
• Lottery prize (if your ticket is drawn)
• Win-Streak Bonus (if you hit 5+ profitable trades)

Example: If you rank #3 on the leaderboard (2,000 USDT), your lottery ticket gets drawn (1,000 USDT), AND you close 6 winning trades (50 USDT), you walk away with 3,050 USDT total.

Stack your wins. Maximize your earnings.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SET YOUR REMINDER

This Friday, {{EventDate}}, starting at 00:00 UTC.

[VIEW THE FULL FRENZY RULES] → {{website_url}}/events/frenzy
[SET CALENDAR REMINDER] → {{calendar_link}}

Prepare your capital. Prepare your strategy. Prepare to WIN.

See you on the battlefield, {{FirstName}}.

Prepare for the Frenzy,
The {{platform_name}} Team

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Event Rules & Terms:
• Only futures trades executed during the 24-hour window count
• Positions opened before the event do NOT count toward volume
• Leaderboard ranks are final as of 23:59:59 UTC
• Lottery draw is provably random and transparent
• All prizes paid in USDT to main wallet
• {{platform_name}} reserves the right to disqualify suspicious activity

Full Terms: {{website_url}}/terms/frenzy

This email was sent to {{email}}.',
  'promotion',
  '["{{FirstName}}", "{{email}}", "{{platform_name}}", "{{website_url}}", "{{EventDate}}", "{{DayOfWeek}}", "{{ParticipantCount}}", "{{calendar_link}}"]'::jsonb,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

-- Insert bonus types for Futures Frenzy
INSERT INTO bonus_types (name, description, default_amount, category, expiry_days, is_active, created_by) VALUES
(
  'Futures Frenzy Event Prize',
  'Prize from 24-hour Futures Frenzy event. Includes Volume Ladder prizes (500-5,000 USDT for Top 10) and Lottery Mania prizes (1,000 USDT per winning ticket). Variable amount based on rank or lottery win.',
  1000.00,
  'promotion',
  NULL,
  true,
  NULL
),
(
  'Win-Streak Bonus 50 USDT',
  'Skill-based bonus for traders who close 5 or more profitable trades during the 24-hour Futures Frenzy event. Automatic 50 USDT reward.',
  50.00,
  'trading',
  NULL,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

-- Create table for tracking frenzy events
CREATE TABLE IF NOT EXISTS frenzy_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name text NOT NULL,
  event_date date NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
  total_prize_pool numeric(10,2) NOT NULL DEFAULT 26300.00,
  participant_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(event_date)
);

-- Enable RLS
ALTER TABLE frenzy_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies for frenzy_events
CREATE POLICY "Anyone can view events"
  ON frenzy_events FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert events"
  ON frenzy_events FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true)
  );

CREATE POLICY "Admins can update events"
  ON frenzy_events FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- Create table for tracking participant stats
CREATE TABLE IF NOT EXISTS frenzy_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES frenzy_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  total_volume numeric(20,2) NOT NULL DEFAULT 0,
  lottery_tickets integer NOT NULL DEFAULT 0,
  profitable_trades integer NOT NULL DEFAULT 0,
  total_trades integer NOT NULL DEFAULT 0,
  leaderboard_rank integer,
  volume_prize numeric(10,2) DEFAULT 0,
  lottery_prize numeric(10,2) DEFAULT 0,
  win_streak_bonus numeric(10,2) DEFAULT 0,
  total_winnings numeric(10,2) DEFAULT 0,
  last_updated timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  UNIQUE(event_id, user_id)
);

-- Enable RLS
ALTER TABLE frenzy_participants ENABLE ROW LEVEL SECURITY;

-- RLS Policies for frenzy_participants
CREATE POLICY "Anyone can view participants"
  ON frenzy_participants FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can insert participants"
  ON frenzy_participants FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update participants"
  ON frenzy_participants FOR UPDATE
  TO authenticated
  USING (true);

-- Create table for lottery tickets
CREATE TABLE IF NOT EXISTS frenzy_lottery_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES frenzy_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ticket_number integer NOT NULL,
  is_winner boolean DEFAULT false,
  prize_amount numeric(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE frenzy_lottery_tickets ENABLE ROW LEVEL SECURITY;

-- RLS Policies for frenzy_lottery_tickets
CREATE POLICY "Anyone can view tickets"
  ON frenzy_lottery_tickets FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can insert tickets"
  ON frenzy_lottery_tickets FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update tickets"
  ON frenzy_lottery_tickets FOR UPDATE
  TO authenticated
  USING (true);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_frenzy_participants_event ON frenzy_participants(event_id);
CREATE INDEX IF NOT EXISTS idx_frenzy_participants_volume ON frenzy_participants(event_id, total_volume DESC);
CREATE INDEX IF NOT EXISTS idx_frenzy_lottery_event ON frenzy_lottery_tickets(event_id);

-- Function to update participant stats during active event
CREATE OR REPLACE FUNCTION update_frenzy_participant_stats(p_event_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event record;
  v_total_volume numeric;
  v_profitable_count integer;
  v_total_count integer;
  v_lottery_tickets integer;
BEGIN
  -- Get event details
  SELECT * INTO v_event FROM frenzy_events WHERE id = p_event_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event not found';
  END IF;
  
  -- Calculate volume from positions opened during event
  SELECT 
    COALESCE(SUM(size * entry_price), 0)
  INTO v_total_volume
  FROM futures_positions
  WHERE 
    user_id = p_user_id
    AND opened_at >= v_event.start_time
    AND opened_at <= v_event.end_time;
  
  -- Count profitable and total trades (only closed positions)
  SELECT 
    COUNT(*) FILTER (WHERE pnl > 0),
    COUNT(*)
  INTO v_profitable_count, v_total_count
  FROM futures_positions
  WHERE 
    user_id = p_user_id
    AND opened_at >= v_event.start_time
    AND opened_at <= v_event.end_time
    AND status = 'closed';
  
  -- Calculate lottery tickets (1 per 10,000 USDT)
  v_lottery_tickets := FLOOR(v_total_volume / 10000)::integer;
  
  -- Insert or update participant record
  INSERT INTO frenzy_participants (
    event_id,
    user_id,
    total_volume,
    lottery_tickets,
    profitable_trades,
    total_trades,
    last_updated
  ) VALUES (
    p_event_id,
    p_user_id,
    v_total_volume,
    v_lottery_tickets,
    v_profitable_count,
    v_total_count,
    now()
  )
  ON CONFLICT (event_id, user_id) 
  DO UPDATE SET
    total_volume = EXCLUDED.total_volume,
    lottery_tickets = EXCLUDED.lottery_tickets,
    profitable_trades = EXCLUDED.profitable_trades,
    total_trades = EXCLUDED.total_trades,
    last_updated = now();
    
END;
$$;

-- Function to get leaderboard for an event
CREATE OR REPLACE FUNCTION get_frenzy_leaderboard(p_event_id uuid)
RETURNS TABLE(
  rank integer,
  user_id uuid,
  email text,
  total_volume numeric,
  lottery_tickets integer,
  profitable_trades integer,
  prize_amount numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH ranked_participants AS (
    SELECT 
      fp.user_id,
      fp.total_volume,
      fp.lottery_tickets,
      fp.profitable_trades,
      ROW_NUMBER() OVER (ORDER BY fp.total_volume DESC) as rank
    FROM frenzy_participants fp
    WHERE fp.event_id = p_event_id
  ),
  prize_mapping AS (
    SELECT 1 as rank, 5000.00 as prize
    UNION ALL SELECT 2, 3000.00
    UNION ALL SELECT 3, 2000.00
    UNION ALL SELECT 4, 1500.00
    UNION ALL SELECT 5, 1200.00
    UNION ALL SELECT 6, 1000.00
    UNION ALL SELECT 7, 800.00
    UNION ALL SELECT 8, 700.00
    UNION ALL SELECT 9, 600.00
    UNION ALL SELECT 10, 500.00
  )
  SELECT 
    rp.rank::integer,
    rp.user_id,
    au.email,
    rp.total_volume,
    rp.lottery_tickets,
    rp.profitable_trades,
    COALESCE(pm.prize, 0) as prize_amount
  FROM ranked_participants rp
  LEFT JOIN prize_mapping pm ON pm.rank = rp.rank
  JOIN auth.users au ON au.id = rp.user_id
  ORDER BY rp.rank;
END;
$$;

-- Function to check if user qualifies for win-streak bonus
CREATE OR REPLACE FUNCTION check_win_streak_bonus(p_event_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profitable_count integer;
BEGIN
  SELECT profitable_trades
  INTO v_profitable_count
  FROM frenzy_participants
  WHERE event_id = p_event_id AND user_id = p_user_id;
  
  RETURN COALESCE(v_profitable_count, 0) >= 5;
END;
$$;

-- Function to update all participants for an event
CREATE OR REPLACE FUNCTION update_all_frenzy_participants(p_event_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
  v_user record;
BEGIN
  -- Loop through all users who traded during the event
  FOR v_user IN
    SELECT DISTINCT user_id
    FROM futures_positions
    WHERE opened_at >= (SELECT start_time FROM frenzy_events WHERE id = p_event_id)
      AND opened_at <= (SELECT end_time FROM frenzy_events WHERE id = p_event_id)
  LOOP
    PERFORM update_frenzy_participant_stats(p_event_id, v_user.user_id);
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$;

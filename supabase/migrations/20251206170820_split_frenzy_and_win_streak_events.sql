/*
  # Split Futures Frenzy and Win-Streak Bonus into Separate Events

  ## Summary
  Separates the Futures Frenzy event into TWO distinct events:
  1. Futures Frenzy (Volume Ladder + Lottery Mania only)
  2. Win-Streak Bonus Challenge (Separate skill-based event)

  ## Changes
  1. Update Futures Frenzy email to REMOVE Win-Streak Bonus section
  2. Create NEW Win-Streak Bonus Challenge email template
  3. Both events remain as separate bonus types
*/

-- Update Futures Frenzy email template to REMOVE Win-Streak Bonus
UPDATE email_templates
SET 
  body = 'Clear Your Schedule for {{EventDate}}.

From 00:00 to 23:59 UTC, we''re triggering a 24-Hour Futures Frenzy with hyper-charged rewards. This is not your regular trading day—this is an all-out sprint for massive prizes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ FRENZY MECHANICS

This is a dual-threat event. Compete on the leaderboard AND earn lottery tickets. Multiple ways to win means maximum opportunity.

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

📊 EVENT DETAILS

Date: {{EventDate}}
Start Time: 00:00 UTC
End Time: 23:59 UTC (sharp cutoff)
Duration: Exactly 24 hours
Qualifying Markets: All futures pairs
Leaderboard: Live updates every 60 seconds
Prize Distribution: Within 2 hours of event end

Current Registered Participants: {{ParticipantCount}}
Total Prize Pool: 26,300 USDT

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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CAN YOU WIN BOTH PRIZES?

YES. Absolutely.

You can win BOTH categories in a single event:
• Volume Ladder prize (if you rank Top 10)
• Lottery prize (if your ticket is drawn)

Example: If you rank #3 on the leaderboard (2,000 USDT) AND your lottery ticket gets drawn (1,000 USDT), you walk away with 3,000 USDT total.

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
  updated_at = now()
WHERE name = 'Futures Frenzy 24-Hour Blitz';

-- Insert NEW Win-Streak Bonus Challenge email template
INSERT INTO email_templates (name, subject, body, category, variables, is_active, created_by) VALUES
(
  'Win-Streak Bonus Challenge',
  '{{FirstName}}, Prove Your Trading Skill: 5 Wins = 50 USDT',
  'Hey {{FirstName}},

This {{DayOfWeek}}, {{EventDate}}, we''re launching a pure skill-based challenge. No volume requirements. No leaderboard competition. Just you vs. the market.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔥 WIN-STREAK BONUS CHALLENGE

This isn''t about how much you trade—it''s about how WELL you trade.

Close 5 or more profitable futures trades during the 24-hour window, and we automatically deposit 50 USDT into your wallet.

That''s it. Simple. Pure. Skill-based.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ QUALIFICATION REQUIREMENTS

To earn the 50 USDT Win-Streak Bonus, you must:

✓ Close a minimum of 5 futures positions with positive PnL
✓ All positions must be OPENED during the 24-hour event window
✓ All positions must be CLOSED during the 24-hour event window
✓ Each winning trade must have profit > 0 USDT (any amount counts)

No minimum position size. No minimum profit per trade. Just 5 wins.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 EVENT DETAILS

Date: {{EventDate}}
Start Time: 00:00 UTC
End Time: 23:59 UTC (sharp cutoff)
Duration: Exactly 24 hours
Qualifying Markets: All futures trading pairs
Bonus Amount: 50 USDT (flat rate)
Payment Timeline: Within 1 hour of event end
Eligibility: Unlimited winners (everyone who qualifies gets paid)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 STRATEGIC TIPS

This is a marathon of precision, not a sprint of volume. Here''s how to approach it:

1. Quality Over Quantity
   You only need 5 wins. Don''t force trades. Wait for high-probability setups.

2. Use Tight Stop-Losses
   Protect your capital. One big loss can wipe out multiple small wins.

3. Take Profits Early
   You don''t need home runs. Singles and doubles count the same as grand slams here.

4. Diversify Pairs
   Don''t tunnel vision on one market. If BTC is choppy, try ETH or altcoins.

5. Track Your Progress
   You can view your profitable closed trades in real-time in your dashboard during the event.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 WHY THIS CHALLENGE IS DIFFERENT

Most trading events reward volume. The biggest traders win.

This challenge rewards SKILL. Retail traders with $100 accounts can compete equally with whales trading $100,000.

Your win rate is all that matters. Your wallet size means nothing.

This levels the playing field. Everyone has a fair shot at 50 USDT.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 AUTOMATIC TRACKING & PAYMENT

You don''t need to register or opt in. We automatically track every futures position you open and close during the event window.

At 23:59 UTC when the event ends:
• Our system counts your profitable closed trades
• If you hit 5+ wins, you qualify
• 50 USDT is automatically deposited to your main wallet within 1 hour
• You''ll receive a notification confirming payment

Zero hassle. Zero paperwork. Just trade and win.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CAN YOU WIN MULTIPLE TIMES?

No. This is a one-time bonus per user per event.

However, if you qualify for this AND other concurrent events (like the Futures Frenzy Volume Ladder or Lottery Mania), you can stack bonuses.

Example:
• Win-Streak Bonus: 50 USDT
• Lottery Mania ticket draw: 1,000 USDT
• Volume Ladder Rank #8: 700 USDT
Total Earnings: 1,750 USDT

Check your email for other active events during this period.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏰ SET YOUR REMINDER

Event Date: {{EventDate}}
Start: 00:00 UTC
End: 23:59 UTC

[VIEW FULL CHALLENGE RULES] → {{website_url}}/events/win-streak
[SET CALENDAR REMINDER] → {{calendar_link}}

5 profitable trades. 50 USDT. 24 hours.

Prove your skill, {{FirstName}}.

Good luck,
The {{platform_name}} Team

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Challenge Rules & Terms:
• Only futures positions opened AND closed during the 24-hour window qualify
• Profitable = any positive PnL amount (> 0 USDT)
• Minimum 5 winning trades required
• One bonus per user per event
• Wash trading or manipulation = instant disqualification
• {{platform_name}} reserves the right to review suspicious activity
• Bonus paid in USDT to main wallet

Full Terms: {{website_url}}/terms/win-streak-challenge

This email was sent to {{email}}.',
  'promotion',
  '["{{FirstName}}", "{{email}}", "{{platform_name}}", "{{website_url}}", "{{EventDate}}", "{{DayOfWeek}}", "{{calendar_link}}"]'::jsonb,
  true,
  NULL
)
ON CONFLICT (name) DO NOTHING;

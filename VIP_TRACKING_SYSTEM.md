# VIP Tier Tracking & Monitoring System

## Overview

The VIP Tier Tracking System automatically monitors VIP level changes and provides comprehensive visibility when users drop or upgrade VIP tiers. This monitoring dashboard helps identify users who may need retention efforts, allowing you to manually manage retention campaigns, bonuses, and communications through your preferred channels.

## Architecture

### Database Tables

#### 1. **vip_level_history**
Complete audit log of all VIP tier changes.

**Columns:**
- `id` - Unique identifier
- `user_id` - User who experienced the change
- `previous_level` - Previous VIP level (0-5)
- `new_level` - New VIP level (0-5)
- `previous_tier_name` - Previous tier name (Regular, Bronze, Silver, Gold, Platinum, Diamond)
- `new_tier_name` - New tier name
- `change_type` - Type of change (upgrade, downgrade, maintained)
- `volume_30d` - 30-day trading volume at time of change
- `reason` - Optional reason for change
- `changed_at` - Timestamp of change
- `created_at` - Record creation timestamp

**Purpose:** Maintains complete history for analytics and auditing

#### 2. **vip_tier_downgrades**
Tracks downgrades requiring admin action.

**Columns:**
- `id` - Unique identifier
- `user_id` - User who was downgraded
- `previous_level` - Previous VIP level
- `new_level` - New VIP level
- `previous_tier_name` - Previous tier name
- `new_tier_name` - New tier name
- `tier_difference` - Number of levels dropped
- `volume_30d` - 30-day trading volume
- `status` - Status (pending, email_sent, bonus_sent, completed, ignored)
- `bonus_amount` - Amount of retention bonus
- `bonus_currency` - Bonus currency (default: USDT)
- `email_sent` - Whether email was sent
- `email_sent_at` - When email was sent
- `bonus_sent` - Whether bonus was sent
- `bonus_sent_at` - When bonus was sent
- `admin_notes` - Admin notes
- `detected_at` - When downgrade was detected
- `actioned_at` - When admin took action
- `actioned_by` - Admin who took action

**Purpose:** Action queue for retention campaigns

#### 3. **vip_retention_campaigns**
Campaign configuration and tracking.

**Columns:**
- `id` - Campaign identifier
- `campaign_name` - Campaign name
- `description` - Campaign description
- `tier_drop_from` - Starting tier level
- `tier_drop_to` - Ending tier level
- `bonus_amount` - Bonus amount for campaign
- `bonus_currency` - Bonus currency
- `email_template_id` - Associated email template
- `is_active` - Whether campaign is active
- `auto_send_bonus` - Auto-send bonus (future feature)
- `auto_send_email` - Auto-send email (future feature)
- `users_eligible` - Count of eligible users
- `bonuses_sent` - Count of bonuses sent
- `emails_sent` - Count of emails sent
- `total_bonus_value` - Total value of bonuses sent
- `created_by` - Admin who created campaign
- `created_at` - Campaign creation date
- `updated_at` - Last update timestamp

**Purpose:** Future campaign automation and tracking

## How It Works

### Automatic Detection

1. **VIP Level Calculation**
   - System automatically calculates VIP levels based on 30-day trading volume
   - Updates `user_vip_status` table with new level

2. **Trigger Activation**
   - `track_vip_changes` trigger fires on `user_vip_status` update
   - Detects when `current_level` changes

3. **History Recording**
   - Inserts record into `vip_level_history` with complete details
   - Captures previous/new levels, tier names, volume, and change type

4. **Downgrade Detection**
   - If change type is "downgrade", creates record in `vip_tier_downgrades`
   - Status set to "pending" for admin action
   - User receives notification about tier change

### VIP Tier Levels

| Level | Tier Name | Description |
|-------|-----------|-------------|
| 0 | Regular | Standard user |
| 1 | Bronze | Entry-level VIP |
| 2 | Silver | Mid-tier VIP |
| 3 | Gold | Premium VIP |
| 4 | Platinum | Elite VIP |
| 5 | Diamond | Highest VIP |

## Email Templates

Three pre-configured email templates are included:

### 1. VIP Tier Drop - 1 Level
**When:** User drops exactly 1 tier level
**Example:** Diamond → Platinum, Gold → Silver
**Bonus:** $100 USDT (default)
**Tone:** Friendly and encouraging

**Variables:**
- `{{user_name}}` - User's name
- `{{previous_tier}}` - Previous tier name
- `{{new_tier}}` - New tier name
- `{{bonus_amount}}` - Bonus amount
- `{{bonus_currency}}` - Currency (USDT)
- `{{volume_30d}}` - 30-day volume
- `{{platform_url}}` - Platform URL

### 2. VIP Major Downgrade - 2+ Levels
**When:** User drops 2 or more tier levels
**Example:** Diamond → Silver, Platinum → Bronze
**Bonus:** $250-500 USDT (based on drop)
**Tone:** Urgent and supportive

**Variables:** Same as above

### 3. VIP to Regular Downgrade
**When:** User drops from any VIP tier to Regular
**Example:** Bronze → Regular, Silver → Regular
**Bonus:** $150 USDT
**Tone:** Welcoming them back to VIP

**Variables:** Same as above (no previous_tier, new_tier)

## Bonus Types

Four bonus types pre-configured:

| Bonus Name | Amount | Trigger Condition |
|------------|--------|------------------|
| VIP Tier Drop - 1 Level Retention | $100 | 1 level drop, min previous level 1 |
| VIP Tier Drop - 2 Levels Retention | $250 | 2 levels drop, min previous level 2 |
| VIP Tier Drop - 3+ Levels Retention | $500 | 3+ levels drop, min previous level 3 |
| VIP to Regular Retention | $150 | Any VIP → Regular |

**Settings:**
- Category: `vip_retention`
- Expiry: 30 days
- Status: Active

## Admin Interface

### Access
Navigate to: **Admin Dashboard → VIP Tracking**

### Features

#### 1. Statistics Dashboard
At-a-glance metrics showing:
- **Total Downgrades** - All-time VIP tier drops
- **Total Upgrades** - All-time VIP tier improvements
- **Last 7 Days** - Recent downgrade activity
- **Last 30 Days** - Monthly downgrade trends

#### 2. Downgrades Tab
Shows all VIP tier downgrades for monitoring.

**For each downgrade, displays:**
- User name and email
- Previous tier → Current tier
- Severity level (Minor, Moderate, Major)
- Number of levels dropped
- 30-day trading volume
- Suggested bonus amount (for reference)
- Detection date and time
- High priority flag for 2+ level drops

**Severity Levels:**
- **Minor** - 1 level drop (Yellow indicator)
- **Moderate** - 2 level drop (Orange indicator)
- **Major** - 3+ level drop (Red indicator)

**Suggested Bonuses:**
- 1 level drop: $100 USDT
- 2 level drop: $250 USDT
- 3+ level drops: $500 USDT
- VIP to Regular: $150 USDT

#### 3. Upgrades Tab
Shows all VIP tier upgrades for positive monitoring.

**Displays:**
- User information
- Previous tier → New tier
- 30-day volume that triggered upgrade
- Upgrade date

**Use Cases:**
- Identify power users
- Send congratulatory messages
- Offer premium services
- Track growth patterns

#### 4. All Changes Tab
Complete history of all VIP level changes.

**Displays:**
- All tier changes (upgrades, downgrades, maintenance)
- User details
- Volume data
- Timestamps
- Change types

**Analytics Value:**
- Spot patterns and trends
- Identify seasonal behavior
- Track user lifecycle
- Measure VIP program health

### Workflow (Manual Process)

1. **Daily Monitoring**
   - Check VIP Tracking dashboard
   - Review statistics for recent activity
   - Identify high-priority downgrades (2+ levels)

2. **User Assessment**
   - Review user's complete profile
   - Check trading history and patterns
   - Assess lifetime value
   - Determine retention approach

3. **Manual Retention Actions**
   - Use Email Templates section to send personalized emails
   - Use Bonus Types section to award retention bonuses
   - Use User Detail page to adjust balances
   - Contact high-value users personally
   - Document actions in admin notes

4. **Follow-Up Monitoring**
   - Track user's response to retention efforts
   - Monitor if they return to previous tier
   - Adjust retention strategy based on results
   - Analyze upgrade/downgrade patterns

## Automation vs Manual

### Automated Features
- ✅ Automatic VIP level detection
- ✅ Automatic downgrade record creation
- ✅ User notification on tier change
- ✅ Complete history logging
- ✅ Statistics calculation
- ✅ Severity classification

### Manual Actions (Your Control)
- ✅ Email sending through Email Templates page
- ✅ Bonus awarding through Bonus Types or User Detail page
- ✅ User communication strategy
- ✅ Retention campaign decisions
- ✅ Personalized outreach
- ✅ Budget control for retention offers

## Example Scenarios

### Scenario 1: Diamond → Platinum (1 Level Drop)
**What Happens:**
1. User's 30-day volume drops below Diamond threshold
2. VIP calculation runs, updates to Platinum
3. Trigger fires, creates history record
4. Downgrade record created with status "pending"
5. User receives notification

**Admin Action:**
1. Sees downgrade in "Downgrades" tab
2. Reviews user: was Diamond, now Platinum
3. Sees suggested $100 USDT bonus
4. Opens user in User Detail page
5. Manually sends email via Email Templates
6. Manually awards bonus via User Detail balance adjustment
7. Documents action

**Result:**
- User encouraged to increase trading
- $100 bonus helps boost activity
- Retention increases

### Scenario 2: Platinum → Silver (2 Level Drop)
**What Happens:**
1. Significant drop in trading activity
2. VIP level drops 2 tiers
3. System detects major downgrade
4. Higher-severity template selected

**Admin Action:**
1. Sees major downgrade flagged as "High Priority"
2. Reviews user's complete history
3. Personally contacts user via email or phone
4. Awards $250-500 USDT bonus based on user value
5. Documents retention strategy

**Result:**
- More substantial retention effort
- Higher bonus reflects user's previous value
- Personal touch for valued customer

### Scenario 3: Bronze → Regular (VIP Loss)
**What Happens:**
1. User falls below minimum VIP threshold
2. Loses all VIP benefits
3. Special template for VIP re-activation

**Admin Action:**
1. Identifies user who lost VIP status
2. Assesses if user was engaged previously
3. Sends personalized welcome-back communication
4. Awards $150 bonus if deemed appropriate
5. Provides clear path to VIP re-entry

**Result:**
- User motivated to regain VIP status
- Clear path to re-activation
- Maintains connection with platform

## Benefits

### For Business
- **Visibility:** Know immediately when VIPs drop tiers
- **Data-Driven:** Make informed retention decisions
- **Prioritization:** Focus on high-value users first
- **Budget Control:** Manually decide retention spending
- **Flexibility:** Custom approach for each user
- **Analytics:** Track patterns and trends
- **Scalable:** Handles unlimited tier changes

### For Users
- **Noticed:** Automatic notification when tier changes
- **Informed:** Clear understanding of tier status
- **Valued:** When admin chooses to reach out personally
- **Motivated:** Opportunity to recover tier with support

## Best Practices

### For Admins

1. **Daily Monitoring**
   - Check VIP Tracking dashboard daily
   - Review statistics for unusual activity
   - Focus on "High Priority" downgrades first
   - Note suggested bonus amounts

2. **User Evaluation**
   - Check user's complete profile and history
   - Assess lifetime value and engagement
   - Review recent trading patterns
   - Determine personalized approach

3. **Retention Strategy**
   - Minor drops (1 level): Consider automated email + standard bonus
   - Moderate drops (2 levels): Personal email + higher bonus
   - Major drops (3+ levels): Direct contact + custom retention package
   - VIP to Regular: Assess re-engagement potential

4. **Taking Action**
   - Go to Email Templates to send appropriate message
   - Go to User Detail to award bonus via balance adjustment
   - Go to Bonus Types to create custom bonus if needed
   - Document decision and outcome

5. **Follow-Up**
   - Monitor user's response over 7-14 days
   - Check if volume increases
   - Adjust strategy for similar cases
   - Track ROI on retention efforts

6. **Pattern Analysis**
   - Review All Changes tab for trends
   - Identify common downgrade triggers
   - Spot seasonal patterns
   - Refine retention approach based on data

### For System Maintenance

1. **Regular Monitoring**
   - Monitor trigger execution
   - Check for failed emails
   - Verify bonus deliveries

2. **Template Updates**
   - Refresh email templates quarterly
   - A/B test subject lines
   - Update bonus offers seasonally

3. **Performance**
   - Archive old history records (>1 year)
   - Monitor database table sizes
   - Optimize queries if slow

## Technical Notes

### Database Functions

**`get_vip_tier_name(vip_level integer)`**
- Converts level number to tier name
- Used in history and downgrade records

**`track_vip_level_change()`**
- Trigger function on `user_vip_status` updates
- Handles all automatic detection and logging

### Trigger Details

**Trigger:** `track_vip_changes`
- **On:** `user_vip_status` table
- **Event:** `AFTER UPDATE OF current_level`
- **Condition:** `OLD.current_level IS DISTINCT FROM NEW.current_level`
- **Function:** `track_vip_level_change()`

### Email Integration

Uses the platform's send-email edge function:
```typescript
fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${ANON_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    to: user_email,
    subject: processed_subject,
    html: processed_body
  })
});
```

### Bonus Integration

Uses the admin balance adjustment function:
```sql
SELECT admin_adjust_balance(
  p_user_id := user_id,
  p_amount := bonus_amount,
  p_currency := 'USDT',
  p_wallet_type := 'main',
  p_reason := 'VIP Retention Bonus',
  p_admin_id := admin_id
);
```

## Security

### Row-Level Security (RLS)
All VIP tracking tables have RLS enabled:
- Only admins can view VIP history
- Only admins can view downgrades
- Only admins can manage campaigns

### Admin Authentication
- Checks `auth.jwt()->>'user_metadata'->>'is_admin'`
- Ensures only authenticated admins can access

### Audit Trail
- All actions logged with admin ID
- Timestamps for all status changes
- Complete history maintained

## Analytics Queries

### Top Tier Changers (Last 30 Days)
```sql
SELECT
  user_id,
  COUNT(*) as change_count,
  SUM(CASE WHEN change_type = 'downgrade' THEN 1 ELSE 0 END) as downgrades,
  SUM(CASE WHEN change_type = 'upgrade' THEN 1 ELSE 0 END) as upgrades
FROM vip_level_history
WHERE changed_at > NOW() - INTERVAL '30 days'
GROUP BY user_id
ORDER BY change_count DESC
LIMIT 10;
```

### Retention Campaign Effectiveness
```sql
SELECT
  status,
  COUNT(*) as count,
  AVG(bonus_amount) as avg_bonus,
  AVG(tier_difference) as avg_drop
FROM vip_tier_downgrades
WHERE detected_at > NOW() - INTERVAL '30 days'
GROUP BY status;
```

### Volume Correlation
```sql
SELECT
  previous_tier_name,
  new_tier_name,
  AVG(volume_30d) as avg_volume,
  COUNT(*) as occurrences
FROM vip_level_history
WHERE change_type = 'downgrade'
GROUP BY previous_tier_name, new_tier_name
ORDER BY occurrences DESC;
```

## Troubleshooting

### Issue: Downgrades not being detected
**Solution:** Check that VIP calculation is running and updating `user_vip_status`

### Issue: Emails not sending
**Solution:** Verify send-email edge function is deployed and template exists

### Issue: Bonuses not crediting
**Solution:** Check admin_adjust_balance function and wallet existence

### Issue: Trigger not firing
**Solution:** Verify trigger exists on `user_vip_status` table

## Integration with Other Admin Tools

### Email Templates Page
Use to send retention emails:
- Pre-configured VIP templates available
- Customize message per user
- Track email sending

### Bonus Types Page
Create retention bonuses:
- VIP retention category bonuses
- Set amounts and expiry
- Track bonus effectiveness

### User Detail Page
Take direct action:
- Adjust balance manually
- View complete trading history
- Send bonuses
- Add admin notes

### Admin Dashboard
Monitor overall health:
- Link to VIP Tracking from dashboard
- Combined view with other metrics
- Platform-wide retention stats

## Support

For issues or questions:
- Review this documentation
- Check database logs
- Contact development team
- Reference risk management system docs

## Changelog

### Version 1.0 (Current)
- Initial VIP tracking system
- Automatic downgrade detection
- Email templates (3)
- Bonus types (4)
- Admin interface
- Complete history tracking
- Manual retention workflows

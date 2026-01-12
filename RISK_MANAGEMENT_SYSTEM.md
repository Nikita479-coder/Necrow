# Risk Management System Documentation

## Overview

The Risk Management System is a comprehensive, automated solution for monitoring and assessing user risk across the platform. It calculates risk scores in real-time based on multiple factors and automatically generates alerts when thresholds are exceeded.

## Architecture

### Database Structure

#### Core Tables

1. **risk_scores** - Stores calculated risk scores for each user
   - `user_id` - User identifier (unique)
   - `overall_score` - Total risk score (0-100)
   - `trading_score` - Trading behavior score (0-30)
   - `kyc_score` - KYC verification score (0-30)
   - `behavior_score` - Account behavior score (0-25)
   - `risk_level` - Risk classification (low/medium/high/critical)
   - `factors` - JSON with detailed calculation breakdown
   - `last_calculated_at` - Last calculation timestamp

2. **risk_alerts** - Auto-generated and manual risk alerts
   - `user_id` - Affected user
   - `alert_type` - Type of alert (critical_risk_level, high_leverage_usage, etc.)
   - `severity` - Alert severity (low/medium/high/critical)
   - `description` - Alert description
   - `status` - Alert status (active/investigating/resolved/false_positive)
   - `is_auto_generated` - Whether automatically generated
   - `metadata` - Additional alert data

3. **user_risk_flags** - Manual risk flags applied by admins
   - `user_id` - Flagged user
   - `flag_type` - Flag type (suspicious_activity, whale, vip, etc.)
   - `reason` - Reason for flag
   - `is_active` - Active status
   - `expires_at` - Optional expiration date

4. **withdrawal_approvals** - High-value withdrawal queue
   - `user_id` - User requesting withdrawal
   - `amount` - Withdrawal amount
   - `currency` - Currency
   - `risk_score` - User's risk score at time of request
   - `status` - Approval status (pending/approved/rejected)

5. **position_monitoring_logs** - Large/risky position tracking
   - `user_id` - User
   - `position_id` - Position identifier
   - `event_type` - Event type (large_position_opened, liquidation_risk, etc.)
   - `details` - Event details
   - `notified_admin` - Whether admin was notified

## Risk Score Calculation

### Overall Score (0-100 points)

The overall risk score is the sum of four component scores:

#### 1. KYC Score (0-30 points)
Assesses identity verification completeness:
- **Not Verified**: 30 points
- **Pending Verification**: 15 points
- **Fully Verified**: 0 points

#### 2. Trading Score (0-30 points)
Analyzes trading patterns and risk-taking behavior:
- **High Leverage (>50x)**:
  - More than 5 positions in 30 days: +10 points
  - 2-5 positions in 30 days: +5 points

- **Liquidations**:
  - More than 3 in 30 days: +10 points
  - 1-3 in 30 days: +5 points

- **Position Sizing**:
  - Average position size >50% of balance: +5 points

- **PnL Volatility**:
  - Standard deviation >$1000: +5 points

#### 3. Behavior Score (0-25 points)
Monitors account security and suspicious patterns:
- **Failed Logins**:
  - More than 10 in 7 days: +10 points
  - 5-10 in 7 days: +5 points

- **Multiple Devices**:
  - More than 5 devices in 30 days: +5 points
  - 3-5 devices in 30 days: +3 points

- **IP Changes**:
  - More than 10 different IPs in 7 days: +5 points
  - 5-10 different IPs in 7 days: +3 points

- **Transaction Velocity**:
  - More than 50 transactions in 1 hour: +5 points
  - 20-50 transactions in 1 hour: +3 points

#### 4. Account Age Score (0-15 points)
Newer accounts carry higher risk:
- **Less than 7 days**: 15 points
- **7-30 days**: 10 points
- **30-90 days**: 5 points
- **Over 90 days**: 0 points

### Risk Levels

Based on the overall score:
- **Low Risk**: 0-30 points
- **Medium Risk**: 31-50 points
- **High Risk**: 51-70 points
- **Critical Risk**: 71-100 points

## Automated Risk Monitoring

### Triggers

The system automatically recalculates risk scores when:

1. **Trading Events**
   - Position opened, closed, or liquidated
   - Triggers: `update_risk_on_position_change`

2. **KYC Status Changes**
   - Verification status updated
   - Triggers: `update_risk_on_kyc_change`

3. **Security Events**
   - Failed login attempts
   - Suspicious IP detected
   - Triggers: `update_risk_on_security_event`

4. **Large Transactions**
   - Withdrawal initiated
   - Triggers: `check_withdrawal_risk`

### Automated Alerts

The system generates alerts automatically:

#### Critical Risk Level Alert
- **Trigger**: Overall score reaches 71+ points
- **Severity**: Critical
- **Action**: Immediate admin notification

#### High Leverage Warning
- **Trigger**: User opens >5 positions with >50x leverage in 30 days
- **Severity**: High
- **Action**: Monitor closely

#### Frequent Liquidations Alert
- **Trigger**: User liquidated >3 times in 30 days
- **Severity**: High
- **Action**: Consider limiting leverage

#### Suspicious Login Activity
- **Trigger**: >10 failed login attempts in 7 days
- **Severity**: Medium
- **Action**: Enhanced security monitoring

### Position Monitoring

Large or risky positions are automatically logged:

- **Large Position Opened**: Margin allocated >$10,000
- **Liquidation Risk**: Position liquidated
- **Unusual PnL**: Extreme profit/loss detected

## Withdrawal Approval System

High-risk withdrawals are automatically flagged for manual approval:

### Auto-Approval Criteria

Withdrawals requiring approval:
1. Amount over $10,000
2. Amount exceeds 50% of total balance
3. High/Critical risk user withdrawing >$1,000

### Approval Process

1. User initiates withdrawal
2. System checks risk criteria
3. If flagged, creates `withdrawal_approval` record
4. Admin reviews and approves/rejects
5. Approved withdrawals process normally

## Database Functions

### Core Functions

#### `update_user_risk_score(p_user_id uuid)`
Calculates and updates all risk scores for a user.

**Usage:**
```sql
SELECT update_user_risk_score('user-uuid-here');
```

#### `check_and_generate_risk_alerts(p_user_id uuid)`
Checks thresholds and generates appropriate alerts.

**Usage:**
```sql
SELECT check_and_generate_risk_alerts('user-uuid-here');
```

#### `recalculate_all_risk_scores()`
Batch recalculates risk scores for all users.

**Usage:**
```sql
SELECT recalculate_all_risk_scores();
```

#### `scheduled_risk_score_update()`
Updates risk scores for users with recent activity (last 24 hours).

**Usage (via cron/scheduler):**
```sql
SELECT scheduled_risk_score_update();
```

### Individual Score Functions

- `calculate_kyc_risk_score(p_user_id uuid)` - Returns KYC score
- `calculate_trading_risk_score(p_user_id uuid)` - Returns trading score
- `calculate_behavior_risk_score(p_user_id uuid)` - Returns behavior score
- `calculate_account_age_risk_score(p_user_id uuid)` - Returns age score

## Admin Interface

### Risk Management Tab

Located in: **Admin Dashboard → User Detail → Risk Management**

Features:
- Real-time risk score display
- Component score breakdown (KYC, Trading, Behavior, Age)
- Detailed risk factors view
- Active risk flags
- Recent alerts history
- Manual recalculation button
- Comprehensive documentation viewer

### Manual Actions

Admins can:
1. **Recalculate Score**: Force immediate recalculation
2. **View Documentation**: In-app risk system documentation
3. **Add Risk Flags**: Manually flag users for specific reasons
4. **Acknowledge Alerts**: Mark alerts as reviewed
5. **Approve Withdrawals**: Review and approve high-risk withdrawals

## Best Practices

### For Admins

1. **Regular Monitoring**
   - Check critical risk users daily
   - Review unacknowledged alerts
   - Monitor withdrawal approval queue

2. **Risk Flag Management**
   - Use appropriate flag types
   - Set expiration dates for temporary flags
   - Document reasons clearly

3. **Alert Response**
   - Acknowledge alerts promptly
   - Investigate high-severity alerts
   - Document resolution actions

4. **Withdrawal Approvals**
   - Review user history
   - Check for suspicious patterns
   - Contact users if needed
   - Document approval decisions

### For System Maintenance

1. **Scheduled Updates**
   - Run `scheduled_risk_score_update()` every 6-12 hours
   - Monitor database performance
   - Archive old alerts periodically

2. **Threshold Tuning**
   - Review alert thresholds monthly
   - Adjust based on false positive rate
   - Document threshold changes

3. **Performance Optimization**
   - Monitor trigger execution time
   - Index optimization for large tables
   - Consider partitioning for growth

## Integration Points

### Frontend Integration

**User Risk Component:**
```typescript
import AdminUserRisk from '../components/admin/AdminUserRisk';

<AdminUserRisk userId={userId} />
```

**Documentation Component:**
```typescript
import RiskManagementDocs from '../components/admin/RiskManagementDocs';

<RiskManagementDocs />
```

### API Integration

**Recalculate Risk Score:**
```typescript
const { error } = await supabase.rpc('update_user_risk_score', {
  p_user_id: userId
});
```

**Check Alerts:**
```typescript
const { error } = await supabase.rpc('check_and_generate_risk_alerts', {
  p_user_id: userId
});
```

## Security Considerations

1. **Row-Level Security (RLS)**
   - All risk tables have RLS enabled
   - Only admins can access risk data
   - Users cannot view their own risk scores

2. **Data Privacy**
   - Risk scores are internal only
   - Never expose to end users
   - Secure audit trail maintained

3. **Automated Actions**
   - All automated actions logged
   - Admin notifications for critical events
   - Audit trail for all risk changes

## Monitoring & Alerts

### System Health Checks

Monitor these metrics:
- Risk score calculation time
- Alert generation rate
- False positive rate
- Withdrawal approval queue length
- Trigger execution success rate

### Alert Channels

Admins are notified via:
- In-app notification system
- Support ticket system (if critical)
- Admin activity logs

## Troubleshooting

### Common Issues

**Issue**: Risk scores not updating
**Solution**: Check trigger status, manually run `update_user_risk_score()`

**Issue**: Too many false positive alerts
**Solution**: Adjust threshold values in alert generation function

**Issue**: Slow risk calculations
**Solution**: Check database indexes, optimize queries, consider caching

**Issue**: Missing risk factors
**Solution**: Verify data exists in source tables (positions, security_logs, etc.)

## Future Enhancements

Potential improvements:
1. Machine learning-based risk prediction
2. Historical risk score trending
3. Peer comparison analytics
4. Custom rule builder for admins
5. Email/SMS notifications for critical alerts
6. Risk score API for external integrations
7. Advanced pattern detection (money laundering, etc.)
8. Geographic risk factors
9. Social network analysis
10. Predictive liquidation warnings

## Changelog

### Version 1.0 (Current)
- Initial risk management system
- Automated score calculation
- Real-time triggers
- Alert generation
- Withdrawal approval system
- Admin interface
- Comprehensive documentation

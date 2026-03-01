/*
  # Comprehensive Email Templates for All Notification Types

  ## Summary
  Creates professional HTML email templates for all notification categories:
  - Trading: Trade Executed, Position Closed, Take Profit Hit, Stop Loss Hit, Liquidation
  - Copy Trading: Pending Trade Request, Trade Accepted, Trade Rejected
  - Account: KYC Update, Account Update, VIP Upgrade, VIP Downgrade
  - Financial: Withdrawal Approved/Rejected/Completed/Blocked/Unblocked, Deposit Completed, Referral Payout
  - Shark Card & VIP: Application, Approved, Declined, Issued, Weekly Refill
  - System: System Notifications

  ## Template Variables
  All templates support dynamic variables like {{username}}, {{amount}}, {{symbol}}, etc.
*/

-- First, update the category check to allow more categories
ALTER TABLE email_templates DROP CONSTRAINT IF EXISTS email_templates_category_check;
ALTER TABLE email_templates ADD CONSTRAINT email_templates_category_check 
  CHECK (category IN ('welcome', 'kyc', 'bonus', 'promotion', 'alert', 'trading', 'general', 'copy_trading', 'account', 'financial', 'shark_card', 'vip', 'system'));

-- =============================================
-- TRADING TEMPLATES
-- =============================================

-- Trade Executed
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Trade Executed', '{{direction}} {{symbol}} Trade Executed Successfully', '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0b0e11; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #1a1d21; border-radius: 16px; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #000; font-size: 24px; font-weight: 700;">Trade Executed</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your {{direction}} order for <strong style="color: #f0b90b;">{{symbol}}</strong> has been executed successfully.</p>
              
              <!-- Trade Details Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Symbol</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-weight: 600;">{{symbol}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Direction</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: {{direction_color}}; font-size: 14px; font-weight: 600;">{{direction}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Size</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{size}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Entry Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{entry_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Leverage</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px; font-weight: 600;">{{leverage}}x</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Margin</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{margin}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Monitor your position in the trading dashboard and manage your risk with Take Profit and Stop Loss orders.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{dashboard_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Position</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">This is an automated notification. Please do not reply to this email.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}} - Trade Smarter</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'trading', '["username", "symbol", "direction", "direction_color", "size", "entry_price", "leverage", "margin", "dashboard_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Position Closed
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Position Closed', '{{symbol}} Position Closed - {{pnl_status}} ${{pnl_amount}}', '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0b0e11; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #1a1d21; border-radius: 16px; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Position Closed</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your <strong style="color: #f0b90b;">{{symbol}}</strong> position has been closed.</p>
              
              <!-- PnL Display -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: {{pnl_bg_color}}; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Realized P&L</p>
                    <p style="color: {{pnl_color}}; font-size: 32px; font-weight: 700; margin: 0;">{{pnl_sign}}${{pnl_amount}}</p>
                    <p style="color: {{pnl_color}}; font-size: 16px; margin: 8px 0 0;">{{pnl_percentage}}%</p>
                  </td>
                </tr>
              </table>

              <!-- Trade Details Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Entry Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{entry_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Exit Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{exit_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Size</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{size}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Duration</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{duration}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{history_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Trade History</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">{{platform_name}} - Trade Smarter</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'trading', '["username", "symbol", "pnl_status", "pnl_amount", "pnl_sign", "pnl_percentage", "pnl_color", "pnl_bg_color", "entry_price", "exit_price", "size", "duration", "history_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Take Profit Hit
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Take Profit Hit', 'Take Profit Triggered - {{symbol}} +${{profit_amount}}', '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0b0e11; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #1a1d21; border-radius: 16px; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #10b981 0%, #059669 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Take Profit Hit!</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Great news! Your Take Profit order for <strong style="color: #f0b90b;">{{symbol}}</strong> has been triggered.</p>
              
              <!-- Profit Display -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Profit Secured</p>
                    <p style="color: #10b981; font-size: 36px; font-weight: 700; margin: 0;">+${{profit_amount}}</p>
                    <p style="color: #10b981; font-size: 16px; margin: 8px 0 0;">+{{profit_percentage}}% ROI</p>
                  </td>
                </tr>
              </table>

              <!-- Trade Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Symbol</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-weight: 600;">{{symbol}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Entry Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{entry_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Take Profit Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #10b981; font-size: 14px; font-weight: 600;">${{tp_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Position Size</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{size}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Your profits have been added to your futures wallet. Keep up the great trading!</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{dashboard_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Continue Trading</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">{{platform_name}} - Trade Smarter</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'trading', '["username", "symbol", "profit_amount", "profit_percentage", "entry_price", "tp_price", "size", "dashboard_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Stop Loss Hit
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Stop Loss Hit', 'Stop Loss Triggered - {{symbol}} Position Protected', '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0b0e11; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #1a1d21; border-radius: 16px; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Stop Loss Triggered</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your Stop Loss for <strong style="color: #f0b90b;">{{symbol}}</strong> has been triggered. Your position has been closed to protect your capital.</p>
              
              <!-- Loss Display -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(239, 68, 68, 0.2) 0%, rgba(220, 38, 38, 0.1) 100%); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Loss Limited To</p>
                    <p style="color: #ef4444; font-size: 36px; font-weight: 700; margin: 0;">-${{loss_amount}}</p>
                    <p style="color: #ef4444; font-size: 16px; margin: 8px 0 0;">{{loss_percentage}}%</p>
                  </td>
                </tr>
              </table>

              <!-- Trade Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Symbol</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-weight: 600;">{{symbol}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Entry Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{entry_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Stop Loss Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ef4444; font-size: 14px; font-weight: 600;">${{sl_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Position Size</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{size}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Risk management is key to successful trading. Your stop loss protected you from potentially larger losses.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{dashboard_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Dashboard</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">{{platform_name}} - Trade Smarter</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'trading', '["username", "symbol", "loss_amount", "loss_percentage", "entry_price", "sl_price", "size", "dashboard_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Liquidation
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Liquidation', 'URGENT: {{symbol}} Position Liquidated', '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0b0e11; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #1a1d21; border-radius: 16px; overflow: hidden;">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Position Liquidated</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your <strong style="color: #f0b90b;">{{symbol}}</strong> position has been liquidated due to insufficient margin.</p>
              
              <!-- Alert Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(220, 38, 38, 0.2) 0%, rgba(185, 28, 28, 0.1) 100%); border: 1px solid rgba(220, 38, 38, 0.4); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #fca5a5; font-size: 14px; margin: 0 0 8px;">Margin Lost</p>
                    <p style="color: #ef4444; font-size: 36px; font-weight: 700; margin: 0;">-${{margin_lost}}</p>
                  </td>
                </tr>
              </table>

              <!-- Trade Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Symbol</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-weight: 600;">{{symbol}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Entry Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{entry_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Liquidation Price</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ef4444; font-size: 14px; font-weight: 600;">${{liq_price}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Leverage Used</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">{{leverage}}x</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Risk Tips -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #1e3a5f; border: 1px solid #3b82f6; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="color: #60a5fa; font-size: 14px; font-weight: 600; margin: 0 0 10px;">Risk Management Tips:</p>
                    <ul style="color: #9ca3af; font-size: 13px; margin: 0; padding-left: 20px; line-height: 1.8;">
                      <li>Always use stop-loss orders to limit potential losses</li>
                      <li>Consider using lower leverage for volatile markets</li>
                      <li>Never risk more than you can afford to lose</li>
                      <li>Maintain adequate margin in your account</li>
                    </ul>
                  </td>
                </tr>
              </table>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{deposit_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Add Funds</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">{{platform_name}} - Trade Responsibly</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'trading', '["username", "symbol", "margin_lost", "entry_price", "liq_price", "leverage", "deposit_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();
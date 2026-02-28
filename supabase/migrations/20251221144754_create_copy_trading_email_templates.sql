/*
  # Copy Trading Email Templates

  ## Templates Created
  - Pending Trade Request: Notification when a trader opens a new trade
  - Trade Accepted: Confirmation when user accepts a copy trade
  - Trade Rejected: Confirmation when user rejects a copy trade
*/

-- Pending Trade Request
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Pending Trade Request', 'New Trade Signal from {{trader_name}} - Action Required', '<!DOCTYPE html>
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
            <td style="background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">New Trade Signal</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;"><strong style="color: #f0b90b;">{{trader_name}}</strong> has opened a new trade that you can copy!</p>
              
              <!-- Trade Signal Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(139, 92, 246, 0.2) 0%, rgba(124, 58, 237, 0.1) 100%); border: 1px solid rgba(139, 92, 246, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px; text-align: center;">
                    <p style="color: #c4b5fd; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 8px;">Trade Signal</p>
                    <p style="color: {{direction_color}}; font-size: 28px; font-weight: 700; margin: 0;">{{direction}} {{symbol}}</p>
                    <p style="color: #9ca3af; font-size: 14px; margin: 10px 0 0;">at ${{entry_price}}</p>
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
                          <span style="color: #9ca3af; font-size: 14px;">Trader</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px; font-weight: 600;">{{trader_name}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Win Rate</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #10b981; font-size: 14px;">{{win_rate}}%</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Leverage</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{leverage}}x</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Expires In</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #fbbf24; font-size: 14px; font-weight: 600;">{{expires_in}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #fbbf24; font-size: 14px; line-height: 1.6; margin: 0 0 25px; text-align: center;">This trade request will expire soon. Act now to copy this trade!</p>
              
              <!-- CTA Buttons -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{review_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 50px; border-radius: 8px; font-weight: 700; font-size: 15px;">Review Trade</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">You are receiving this because you are copying {{trader_name}}.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'copy_trading', '["username", "trader_name", "symbol", "direction", "direction_color", "entry_price", "win_rate", "leverage", "expires_in", "review_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Trade Accepted
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Trade Accepted', 'Trade Copied Successfully - {{symbol}} {{direction}}', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Trade Copied!</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">You have successfully copied the <strong style="color: #f0b90b;">{{symbol}}</strong> trade from {{trader_name}}.</p>
              
              <!-- Success Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px; text-align: center;">
                    <div style="width: 60px; height: 60px; background: rgba(16, 185, 129, 0.2); border-radius: 50%; margin: 0 auto 15px; line-height: 60px;">
                      <span style="color: #10b981; font-size: 28px;">&#10003;</span>
                    </div>
                    <p style="color: #10b981; font-size: 18px; font-weight: 600; margin: 0;">Position Opened</p>
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
                          <span style="color: #9ca3af; font-size: 14px;">Direction</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: {{direction_color}}; font-size: 14px; font-weight: 600;">{{direction}}</span>
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
                          <span style="color: #9ca3af; font-size: 14px;">Your Allocation</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">${{allocation}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Trader</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{trader_name}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Your position will be automatically managed based on the trader''s actions. You''ll receive notifications when the position is closed.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{positions_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Positions</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">{{platform_name}} - Copy the Best, Trade Like the Best</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'copy_trading', '["username", "symbol", "direction", "direction_color", "entry_price", "allocation", "trader_name", "positions_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Trade Rejected
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Trade Rejected', 'Trade Signal Declined - {{symbol}}', '<!DOCTYPE html>
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
            <td style="background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Trade Declined</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">You have declined the trade signal for <strong style="color: #f0b90b;">{{symbol}}</strong> from {{trader_name}}.</p>
              
              <!-- Info Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Trade Signal</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: {{direction_color}}; font-size: 14px; font-weight: 600;">{{direction}} {{symbol}}</span>
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
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Trader</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{trader_name}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">No action was taken on your account. You will continue to receive future trade signals from {{trader_name}} unless you stop copying them.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{copy_trading_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Manage Copy Trading</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'copy_trading', '["username", "symbol", "direction", "direction_color", "entry_price", "trader_name", "copy_trading_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();
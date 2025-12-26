/*
  # Account Email Templates

  ## Templates Created
  - KYC Update: Status update for KYC verification
  - Account Update: General account changes notification
  - VIP Upgrade: Congratulations on VIP tier upgrade
  - VIP Downgrade: Notice of VIP tier change
*/

-- KYC Update
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('KYC Update', 'KYC Verification Update - {{kyc_status}}', '<!DOCTYPE html>
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
            <td style="background: linear-gradient(135deg, {{header_color_start}} 0%, {{header_color_end}} 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">KYC Verification Update</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your KYC verification status has been updated.</p>
              
              <!-- Status Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: {{status_bg}}; border: 1px solid {{status_border}}; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Current Status</p>
                    <p style="color: {{status_color}}; font-size: 28px; font-weight: 700; margin: 0;">{{kyc_status}}</p>
                    <p style="color: #9ca3af; font-size: 14px; margin: 10px 0 0;">Level {{kyc_level}}</p>
                  </td>
                </tr>
              </table>

              <!-- Message -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #ffffff; font-size: 15px; line-height: 1.7; margin: 0;">{{status_message}}</p>
                  </td>
                </tr>
              </table>

              {{#if rejection_reason}}
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="color: #ef4444; font-size: 14px; font-weight: 600; margin: 0 0 8px;">Reason:</p>
                    <p style="color: #fca5a5; font-size: 14px; margin: 0;">{{rejection_reason}}</p>
                  </td>
                </tr>
              </table>
              {{/if}}
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{kyc_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">{{cta_text}}</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">If you have questions, contact our support team.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'account', '["username", "kyc_status", "kyc_level", "status_message", "rejection_reason", "header_color_start", "header_color_end", "status_bg", "status_border", "status_color", "cta_text", "kyc_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Account Update
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Account Update', 'Important: Account Settings Updated', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Account Updated</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your account settings have been updated. Here''s a summary of the changes:</p>
              
              <!-- Changes Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #f0b90b; font-size: 14px; font-weight: 600; margin: 0 0 15px;">Changes Made:</p>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Setting Changed</span>
                        </td>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{setting_changed}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Changed At</span>
                        </td>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{changed_at}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">IP Address</span>
                        </td>
                        <td style="padding: 10px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{ip_address}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Security Warning -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: rgba(251, 191, 36, 0.1); border: 1px solid rgba(251, 191, 36, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="color: #fbbf24; font-size: 14px; font-weight: 600; margin: 0 0 8px;">Didn''t make this change?</p>
                    <p style="color: #9ca3af; font-size: 13px; margin: 0;">If you did not authorize this change, please secure your account immediately by changing your password and enabling 2FA.</p>
                  </td>
                </tr>
              </table>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{security_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Review Security Settings</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">This is an automated security notification.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'account', '["username", "setting_changed", "changed_at", "ip_address", "security_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- VIP Upgrade
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('VIP Upgrade', 'Congratulations! You''ve Been Upgraded to {{new_tier}}', '<!DOCTYPE html>
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
            <td style="background: linear-gradient(135deg, #f0b90b 0%, #fcd34d 50%, #f0b90b 100%); padding: 40px; text-align: center;">
              <p style="color: #000; font-size: 14px; text-transform: uppercase; letter-spacing: 2px; margin: 0 0 10px;">Congratulations!</p>
              <h1 style="margin: 0; color: #000; font-size: 32px; font-weight: 700;">VIP Upgrade</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Great news! Your trading activity has earned you a VIP tier upgrade.</p>
              
              <!-- Tier Upgrade Visual -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 25px;">
                <tr>
                  <td align="center">
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="text-align: center; padding: 20px;">
                          <p style="color: #6b7280; font-size: 12px; margin: 0 0 5px;">Previous Tier</p>
                          <p style="color: #9ca3af; font-size: 20px; font-weight: 600; margin: 0;">{{old_tier}}</p>
                        </td>
                        <td style="padding: 0 30px;">
                          <span style="color: #f0b90b; font-size: 24px;">&#8594;</span>
                        </td>
                        <td style="text-align: center; padding: 20px; background: linear-gradient(135deg, rgba(240, 185, 11, 0.2) 0%, rgba(240, 185, 11, 0.1) 100%); border-radius: 12px;">
                          <p style="color: #f0b90b; font-size: 12px; margin: 0 0 5px;">New Tier</p>
                          <p style="color: #f0b90b; font-size: 24px; font-weight: 700; margin: 0;">{{new_tier}}</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Benefits Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #f0b90b; font-size: 16px; font-weight: 600; margin: 0 0 15px;">Your New Benefits:</p>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Trading Fee Discount</span>
                        </td>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #10b981; font-size: 14px; font-weight: 600;">{{fee_discount}}% OFF</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Maximum Leverage</span>
                        </td>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{max_leverage}}x</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Daily Withdrawal Limit</span>
                        </td>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{withdrawal_limit}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Priority Support</span>
                        </td>
                        <td style="padding: 10px 0; text-align: right;">
                          <span style="color: #10b981; font-size: 14px;">&#10003; Enabled</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Keep trading to unlock even more exclusive benefits!</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{vip_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View VIP Benefits</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">Thank you for being a valued member!</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'account', '["username", "old_tier", "new_tier", "fee_discount", "max_leverage", "withdrawal_limit", "vip_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- VIP Downgrade
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('VIP Downgrade', 'VIP Tier Update - Action May Be Required', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">VIP Tier Update</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your VIP tier has been adjusted based on recent trading activity.</p>
              
              <!-- Tier Change Visual -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 25px;">
                <tr>
                  <td align="center">
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="text-align: center; padding: 20px;">
                          <p style="color: #6b7280; font-size: 12px; margin: 0 0 5px;">Previous Tier</p>
                          <p style="color: #9ca3af; font-size: 20px; font-weight: 600; margin: 0;">{{old_tier}}</p>
                        </td>
                        <td style="padding: 0 30px;">
                          <span style="color: #6b7280; font-size: 24px;">&#8594;</span>
                        </td>
                        <td style="text-align: center; padding: 20px; background-color: #262a2f; border-radius: 12px;">
                          <p style="color: #6b7280; font-size: 12px; margin: 0 0 5px;">Current Tier</p>
                          <p style="color: #ffffff; font-size: 24px; font-weight: 700; margin: 0;">{{new_tier}}</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Info Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #ffffff; font-size: 15px; line-height: 1.7; margin: 0 0 15px;">Your current benefits have been updated to reflect your new tier level. VIP tiers are calculated based on your 30-day trading volume.</p>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Current 30-Day Volume</span>
                        </td>
                        <td style="padding: 10px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{current_volume}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 10px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Volume Needed for {{old_tier}}</span>
                        </td>
                        <td style="padding: 10px 0; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">${{volume_needed}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Increase your trading activity to regain your previous tier and unlock better benefits!</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{trading_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Start Trading</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">Questions? Contact our VIP support team.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'account', '["username", "old_tier", "new_tier", "current_volume", "volume_needed", "trading_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();
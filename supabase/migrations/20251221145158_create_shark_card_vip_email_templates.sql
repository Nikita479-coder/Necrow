/*
  # Shark Card & VIP Email Templates

  ## Templates Created
  - Shark Card Application: Application submitted notification
  - Shark Card Approved: Card approved notification
  - Shark Card Declined: Card declined notification
  - Shark Card Issued: Card activated notification
  - VIP Weekly Refill: Weekly card refill notification
*/

-- Shark Card Application
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Shark Card Application', 'Shark Card Application Received', '<!DOCTYPE html>
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
            <td style="background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Application Received</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Thank you for applying for a Shark Card! Your application has been received and is being reviewed.</p>
              
              <!-- Status Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(59, 130, 246, 0.2) 0%, rgba(29, 78, 216, 0.1) 100%); border: 1px solid rgba(59, 130, 246, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #93c5fd; font-size: 14px; margin: 0 0 8px;">Application Status</p>
                    <p style="color: #3b82f6; font-size: 24px; font-weight: 700; margin: 0;">Under Review</p>
                    <p style="color: #9ca3af; font-size: 14px; margin: 10px 0 0;">Submitted: {{submitted_at}}</p>
                  </td>
                </tr>
              </table>

              <!-- Application Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #f0b90b; font-size: 14px; font-weight: 600; margin: 0 0 15px;">Application Details:</p>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Card Tier</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-weight: 600;">{{card_tier}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Your VIP Level</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">{{vip_level}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Estimated Review Time</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">1-3 Business Days</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">We''ll notify you once your application has been reviewed. You can check your application status anytime in your account settings.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{status_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Check Status</a>
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
</html>', 'shark_card', '["username", "card_tier", "vip_level", "submitted_at", "status_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Shark Card Approved
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Shark Card Approved', 'Congratulations! Your Shark Card Has Been Approved', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Card Approved!</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Great news! Your Shark Card application has been approved!</p>
              
              <!-- Success Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <div style="width: 60px; height: 60px; background: rgba(16, 185, 129, 0.2); border-radius: 50%; margin: 0 auto 15px; line-height: 60px;">
                      <span style="color: #10b981; font-size: 28px;">&#10003;</span>
                    </div>
                    <p style="color: #10b981; font-size: 20px; font-weight: 700; margin: 0;">Application Approved</p>
                  </td>
                </tr>
              </table>

              <!-- Card Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #f0b90b; font-size: 14px; font-weight: 600; margin: 0 0 15px;">Your Card Details:</p>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Card Tier</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px; font-weight: 600;">{{card_tier}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Credit Limit</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{credit_limit}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Cashback Rate</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #10b981; font-size: 14px;">{{cashback_rate}}%</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Your card is being prepared and will be issued shortly. You''ll receive another email with your card details once it''s ready to use.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{card_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Card Details</a>
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
</html>', 'shark_card', '["username", "card_tier", "credit_limit", "cashback_rate", "card_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Shark Card Declined
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Shark Card Declined', 'Shark Card Application Update', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Application Update</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">We''ve reviewed your Shark Card application and unfortunately we''re unable to approve it at this time.</p>
              
              <!-- Status Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(107, 114, 128, 0.2) 0%, rgba(75, 85, 99, 0.1) 100%); border: 1px solid rgba(107, 114, 128, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Application Status</p>
                    <p style="color: #ffffff; font-size: 24px; font-weight: 700; margin: 0;">Not Approved</p>
                  </td>
                </tr>
              </table>

              <!-- Reason Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #f0b90b; font-size: 14px; font-weight: 600; margin: 0 0 10px;">Reason:</p>
                    <p style="color: #ffffff; font-size: 15px; line-height: 1.6; margin: 0;">{{decline_reason}}</p>
                  </td>
                </tr>
              </table>

              <!-- What to do next -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #1e3a5f; border: 1px solid #3b82f6; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="color: #60a5fa; font-size: 14px; font-weight: 600; margin: 0 0 10px;">What You Can Do:</p>
                    <ul style="color: #9ca3af; font-size: 13px; margin: 0; padding-left: 20px; line-height: 1.8;">
                      <li>Ensure your KYC verification is complete</li>
                      <li>Maintain consistent trading activity</li>
                      <li>Reach the required VIP tier for your desired card</li>
                      <li>You can reapply after {{waiting_period}}</li>
                    </ul>
                  </td>
                </tr>
              </table>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{support_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Contact Support</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">Questions? Our support team is here to help.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'shark_card', '["username", "decline_reason", "waiting_period", "support_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Shark Card Issued
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Shark Card Issued', 'Your Shark Card is Ready to Use!', '<!DOCTYPE html>
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
              <p style="color: #000; font-size: 14px; text-transform: uppercase; letter-spacing: 2px; margin: 0 0 10px;">Your Card is Ready</p>
              <h1 style="margin: 0; color: #000; font-size: 32px; font-weight: 700;">Shark Card Activated!</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your Shark Card has been issued and is ready to use! Start spending your crypto anywhere cards are accepted.</p>
              
              <!-- Card Visual -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 16px; margin-bottom: 25px; overflow: hidden;">
                <tr>
                  <td style="padding: 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td>
                          <p style="color: #f0b90b; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 5px;">{{card_tier}} Card</p>
                          <p style="color: #ffffff; font-size: 20px; font-weight: 700; letter-spacing: 4px; margin: 0;">**** **** **** {{last_four}}</p>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding-top: 30px;">
                          <table width="100%" cellpadding="0" cellspacing="0">
                            <tr>
                              <td>
                                <p style="color: #6b7280; font-size: 10px; margin: 0;">VALID THRU</p>
                                <p style="color: #ffffff; font-size: 14px; margin: 0;">{{expiry_date}}</p>
                              </td>
                              <td style="text-align: right;">
                                <p style="color: #6b7280; font-size: 10px; margin: 0;">CREDIT LIMIT</p>
                                <p style="color: #f0b90b; font-size: 14px; font-weight: 600; margin: 0;">${{credit_limit}}</p>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Benefits -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #f0b90b; font-size: 14px; font-weight: 600; margin: 0 0 15px;">Card Benefits:</p>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Cashback</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #10b981; font-size: 14px; font-weight: 600;">{{cashback_rate}}% on all purchases</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">ATM Withdrawals</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{atm_limit}} free/month</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Global Acceptance</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #10b981; font-size: 14px;">&#10003; Worldwide</span>
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
                    <a href="{{card_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Manage Your Card</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">Keep your card details secure. Never share your CVV or PIN.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'shark_card', '["username", "card_tier", "last_four", "expiry_date", "credit_limit", "cashback_rate", "atm_limit", "card_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- VIP Weekly Refill
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('VIP Weekly Refill', 'Weekly Shark Card Refill - ${{refill_amount}} Added', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #000; font-size: 24px; font-weight: 700;">Weekly VIP Refill</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">As a valued {{vip_tier}} member, your weekly Shark Card refill has been processed!</p>
              
              <!-- Refill Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(240, 185, 11, 0.2) 0%, rgba(240, 185, 11, 0.1) 100%); border: 1px solid rgba(240, 185, 11, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Weekly Refill Amount</p>
                    <p style="color: #f0b90b; font-size: 36px; font-weight: 700; margin: 0;">+${{refill_amount}}</p>
                    <p style="color: #9ca3af; font-size: 14px; margin: 10px 0 0;">{{vip_tier}} Benefit</p>
                  </td>
                </tr>
              </table>

              <!-- Card Balance -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">New Card Balance</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #10b981; font-size: 16px; font-weight: 600;">${{new_balance}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Credit Limit</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">${{credit_limit}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Next Refill</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">{{next_refill_date}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Enjoy your VIP benefits! Your card is ready to use for purchases worldwide.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{card_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Card Balance</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">Thank you for being a valued VIP member!</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'vip', '["username", "vip_tier", "refill_amount", "new_balance", "credit_limit", "next_refill_date", "card_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();
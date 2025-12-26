/*
  # Financial Email Templates

  ## Templates Created
  - Withdrawal Approved: Withdrawal request approved
  - Withdrawal Rejected: Withdrawal request rejected
  - Withdrawal Completed: Withdrawal successfully processed
  - Withdrawal Blocked: Account withdrawal blocked
  - Withdrawal Unblocked: Withdrawal restrictions lifted
  - Deposit Completed: Deposit confirmed
  - Referral Payout: Commission earned from referrals
*/

-- Withdrawal Approved
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Withdrawal Approved', 'Withdrawal Approved - ${{amount}} {{currency}}', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Withdrawal Approved</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Great news! Your withdrawal request has been approved and is being processed.</p>
              
              <!-- Amount Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Withdrawal Amount</p>
                    <p style="color: #10b981; font-size: 36px; font-weight: 700; margin: 0;">{{amount}} {{currency}}</p>
                  </td>
                </tr>
              </table>

              <!-- Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Transaction ID</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-family: monospace;">{{transaction_id}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Destination</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-family: monospace;">{{destination_short}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Network</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{network}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Estimated Arrival</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">{{eta}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">You will receive another email once the withdrawal has been completed and sent to your wallet.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{transactions_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Transaction</a>
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
</html>', 'financial', '["username", "amount", "currency", "transaction_id", "destination_short", "network", "eta", "transactions_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Withdrawal Rejected
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Withdrawal Rejected', 'Withdrawal Request Declined - Action Required', '<!DOCTYPE html>
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
            <td style="background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Withdrawal Declined</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Unfortunately, your withdrawal request could not be processed.</p>
              
              <!-- Amount Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(239, 68, 68, 0.2) 0%, rgba(220, 38, 38, 0.1) 100%); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Requested Amount</p>
                    <p style="color: #ef4444; font-size: 36px; font-weight: 700; margin: 0;">{{amount}} {{currency}}</p>
                    <p style="color: #ef4444; font-size: 14px; margin: 10px 0 0;">DECLINED</p>
                  </td>
                </tr>
              </table>

              <!-- Reason Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #ef4444; font-size: 14px; font-weight: 600; margin: 0 0 10px;">Reason for Rejection:</p>
                    <p style="color: #ffffff; font-size: 15px; line-height: 1.6; margin: 0;">{{rejection_reason}}</p>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Your funds remain safely in your account. Please address the issue above and submit a new withdrawal request.</p>
              
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
              <p style="color: #6b7280; font-size: 12px; margin: 0;">Need help? Our support team is available 24/7.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'financial', '["username", "amount", "currency", "rejection_reason", "support_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Withdrawal Completed
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Withdrawal Completed', 'Withdrawal Complete - {{amount}} {{currency}} Sent', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Withdrawal Complete</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your withdrawal has been successfully processed and sent to your wallet.</p>
              
              <!-- Success Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <div style="width: 60px; height: 60px; background: rgba(16, 185, 129, 0.2); border-radius: 50%; margin: 0 auto 15px; line-height: 60px;">
                      <span style="color: #10b981; font-size: 28px;">&#10003;</span>
                    </div>
                    <p style="color: #10b981; font-size: 32px; font-weight: 700; margin: 0;">{{amount}} {{currency}}</p>
                    <p style="color: #9ca3af; font-size: 14px; margin: 10px 0 0;">Successfully Sent</p>
                  </td>
                </tr>
              </table>

              <!-- Transaction Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Transaction Hash</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <a href="{{explorer_url}}" style="color: #f0b90b; font-size: 12px; font-family: monospace; text-decoration: none;">{{tx_hash_short}}</a>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Destination</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 12px; font-family: monospace;">{{destination_short}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Network</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{network}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Completed At</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{completed_at}}</span>
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
                    <a href="{{explorer_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View on Explorer</a>
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
</html>', 'financial', '["username", "amount", "currency", "tx_hash_short", "destination_short", "network", "completed_at", "explorer_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Withdrawal Blocked
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Withdrawal Blocked', 'Important: Withdrawals Temporarily Restricted', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Withdrawals Restricted</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Withdrawals from your account have been temporarily restricted for security purposes.</p>
              
              <!-- Alert Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(220, 38, 38, 0.2) 0%, rgba(185, 28, 28, 0.1) 100%); border: 1px solid rgba(220, 38, 38, 0.4); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px; text-align: center;">
                    <p style="color: #fca5a5; font-size: 14px; margin: 0 0 8px;">Account Status</p>
                    <p style="color: #ef4444; font-size: 24px; font-weight: 700; margin: 0;">WITHDRAWALS BLOCKED</p>
                  </td>
                </tr>
              </table>

              <!-- Reason Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <p style="color: #f0b90b; font-size: 14px; font-weight: 600; margin: 0 0 10px;">Reason:</p>
                    <p style="color: #ffffff; font-size: 15px; line-height: 1.6; margin: 0 0 15px;">{{block_reason}}</p>
                    <p style="color: #9ca3af; font-size: 13px; margin: 0;">Blocked on: {{blocked_at}}</p>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Your funds are safe. Other account functions including trading and deposits remain active. Please contact support to resolve this matter.</p>
              
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
              <p style="color: #6b7280; font-size: 12px; margin: 0;">This action was taken to protect your account.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'financial', '["username", "block_reason", "blocked_at", "support_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Withdrawal Unblocked
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Withdrawal Unblocked', 'Good News: Withdrawals Re-enabled', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Withdrawals Re-enabled</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Great news! The withdrawal restriction on your account has been lifted. You can now withdraw your funds normally.</p>
              
              <!-- Success Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <div style="width: 60px; height: 60px; background: rgba(16, 185, 129, 0.2); border-radius: 50%; margin: 0 auto 15px; line-height: 60px;">
                      <span style="color: #10b981; font-size: 28px;">&#10003;</span>
                    </div>
                    <p style="color: #10b981; font-size: 20px; font-weight: 700; margin: 0;">Withdrawals Active</p>
                    <p style="color: #9ca3af; font-size: 14px; margin: 10px 0 0;">All restrictions removed</p>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Thank you for your patience while we ensured the security of your account. You now have full access to all withdrawal features.</p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{withdraw_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">Withdraw Funds</a>
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
</html>', 'financial', '["username", "withdraw_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Deposit Completed
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Deposit Completed', 'Deposit Confirmed - {{amount}} {{currency}}', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">Deposit Confirmed</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">Your deposit has been confirmed and credited to your account!</p>
              
              <!-- Amount Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.2) 0%, rgba(5, 150, 105, 0.1) 100%); border: 1px solid rgba(16, 185, 129, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Amount Deposited</p>
                    <p style="color: #10b981; font-size: 36px; font-weight: 700; margin: 0;">+{{amount}} {{currency}}</p>
                  </td>
                </tr>
              </table>

              <!-- Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Transaction ID</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 12px; font-family: monospace;">{{transaction_id}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Network</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{network}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Credited To</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">{{wallet_type}} Wallet</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">New Balance</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px; font-weight: 600;">{{new_balance}} {{currency}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0 0 25px;">Your funds are ready to use. Start trading now!</p>
              
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
              <p style="color: #6b7280; font-size: 12px; margin: 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'financial', '["username", "amount", "currency", "transaction_id", "network", "wallet_type", "new_balance", "trading_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();

-- Referral Payout
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('Referral Payout', 'You Earned ${{commission_amount}} in Referral Commission!', '<!DOCTYPE html>
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
            <td style="background: linear-gradient(135deg, #f0b90b 0%, #fcd34d 50%, #f0b90b 100%); padding: 30px; text-align: center;">
              <h1 style="margin: 0; color: #000; font-size: 24px; font-weight: 700;">Commission Earned!</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              <p style="color: #9ca3af; font-size: 15px; line-height: 1.6; margin: 0 0 25px;">You''ve earned a referral commission from your network''s trading activity!</p>
              
              <!-- Commission Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: linear-gradient(135deg, rgba(240, 185, 11, 0.2) 0%, rgba(240, 185, 11, 0.1) 100%); border: 1px solid rgba(240, 185, 11, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 30px; text-align: center;">
                    <p style="color: #9ca3af; font-size: 14px; margin: 0 0 8px;">Commission Earned</p>
                    <p style="color: #f0b90b; font-size: 36px; font-weight: 700; margin: 0;">+${{commission_amount}}</p>
                  </td>
                </tr>
              </table>

              <!-- Details -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">From Referral</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{referral_username}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Trade Type</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{trade_type}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151;">
                          <span style="color: #9ca3af; font-size: 14px;">Commission Rate</span>
                        </td>
                        <td style="padding: 8px 0; border-bottom: 1px solid #374151; text-align: right;">
                          <span style="color: #f0b90b; font-size: 14px;">{{commission_rate}}%</span>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 8px 0;">
                          <span style="color: #9ca3af; font-size: 14px;">Total Referrals</span>
                        </td>
                        <td style="padding: 8px 0; text-align: right;">
                          <span style="color: #ffffff; font-size: 14px;">{{total_referrals}}</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Stats -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #1e3a5f; border: 1px solid #3b82f6; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="color: #60a5fa; font-size: 14px; font-weight: 600; margin: 0 0 10px;">Your Referral Stats This Month:</p>
                    <p style="color: #ffffff; font-size: 24px; font-weight: 700; margin: 0;">${{monthly_earnings}} earned</p>
                    <p style="color: #9ca3af; font-size: 13px; margin: 5px 0 0;">from {{monthly_trades}} trades by your referrals</p>
                  </td>
                </tr>
              </table>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{referral_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">View Referral Dashboard</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">Keep sharing your referral link to earn more!</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'financial', '["username", "commission_amount", "referral_username", "trade_type", "commission_rate", "total_referrals", "monthly_earnings", "monthly_trades", "referral_url", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();
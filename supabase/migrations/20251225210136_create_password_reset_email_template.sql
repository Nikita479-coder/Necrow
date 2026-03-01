/*
  # Password Reset Email Template

  1. New Email Template
    - Creates a branded password reset email template
    - Category: account
    - Active by default

  2. Purpose
    - Provides a professional password reset email for users
    - Includes security messaging
    - Matches platform branding
*/

INSERT INTO email_templates (name, subject, body, category, is_active)
VALUES (
  'Password Reset Request',
  'Reset Your Shark Trades Password',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Password</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, Helvetica, Arial, sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0b0e11;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #1a1d29; border-radius: 16px; overflow: hidden; border: 1px solid #2a2d39;">
          <!-- Header -->
          <tr>
            <td style="padding: 32px 40px; background: linear-gradient(135deg, #1a1d29 0%, #252837 100%); border-bottom: 1px solid #2a2d39;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <h1 style="margin: 0; font-size: 28px; font-weight: 700; color: #f0b90b; letter-spacing: -0.5px;">
                      Shark Trades
                    </h1>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 40px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center" style="padding-bottom: 24px;">
                    <div style="width: 80px; height: 80px; background-color: rgba(240, 185, 11, 0.15); border-radius: 50%; display: inline-flex; align-items: center; justify-content: center;">
                      <span style="font-size: 40px;">🔐</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td>
                    <h2 style="margin: 0 0 16px; font-size: 24px; font-weight: 600; color: #ffffff; text-align: center;">
                      Password Reset Request
                    </h2>
                    <p style="margin: 0 0 24px; font-size: 16px; line-height: 1.6; color: #9ca3af; text-align: center;">
                      Hello {{first_name}},
                    </p>
                    <p style="margin: 0 0 24px; font-size: 16px; line-height: 1.6; color: #9ca3af; text-align: center;">
                      We received a request to reset the password for your Shark Trades account associated with this email address.
                    </p>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding: 24px 0;">
                    <a href="{{reset_link}}" style="display: inline-block; padding: 16px 48px; background-color: #f0b90b; color: #000000; font-size: 16px; font-weight: 600; text-decoration: none; border-radius: 8px; transition: background-color 0.2s;">
                      Reset Password
                    </a>
                  </td>
                </tr>
                <tr>
                  <td>
                    <p style="margin: 24px 0 0; font-size: 14px; line-height: 1.6; color: #6b7280; text-align: center;">
                      This link will expire in <strong style="color: #9ca3af;">1 hour</strong> for security reasons.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Security Notice -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.2); border-radius: 12px;">
                <tr>
                  <td style="padding: 20px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="40" valign="top">
                          <span style="font-size: 20px;">⚠️</span>
                        </td>
                        <td>
                          <p style="margin: 0; font-size: 14px; font-weight: 600; color: #f87171;">
                            Security Notice
                          </p>
                          <p style="margin: 8px 0 0; font-size: 13px; line-height: 1.5; color: #9ca3af;">
                            If you did not request this password reset, please ignore this email or contact our support team immediately. Never share this link with anyone.
                          </p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Troubleshooting -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #252837; border-radius: 12px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="margin: 0 0 12px; font-size: 13px; font-weight: 600; color: #ffffff;">
                      Button not working?
                    </p>
                    <p style="margin: 0; font-size: 12px; line-height: 1.5; color: #6b7280;">
                      Copy and paste this link into your browser:
                    </p>
                    <p style="margin: 8px 0 0; font-size: 11px; line-height: 1.5; color: #f0b90b; word-break: break-all;">
                      {{reset_link}}
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 40px; background-color: #0b0e11; border-top: 1px solid #2a2d39;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 8px; font-size: 13px; color: #6b7280;">
                      Need help? Contact us at
                      <a href="mailto:support@shark-trades.com" style="color: #f0b90b; text-decoration: none;">support@shark-trades.com</a>
                    </p>
                    <p style="margin: 0; font-size: 12px; color: #4b5563;">
                      © 2024 Shark Trades. All rights reserved.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>',
  'account',
  true
) ON CONFLICT DO NOTHING;

/*
  # System Email Template

  ## Templates Created
  - System Notification: General platform notifications and announcements
*/

-- System Notification
INSERT INTO email_templates (name, subject, body, category, variables, is_active) VALUES
('System Notification', '{{notification_title}}', '<!DOCTYPE html>
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
              <h1 style="margin: 0; color: #fff; font-size: 24px; font-weight: 700;">{{notification_title}}</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <p style="color: #ffffff; font-size: 16px; margin: 0 0 20px;">Hi {{username}},</p>
              
              <!-- Main Content -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #262a2f; border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 25px;">
                    <div style="color: #ffffff; font-size: 15px; line-height: 1.7;">
                      {{notification_content}}
                    </div>
                  </td>
                </tr>
              </table>

              {{#if additional_info}}
              <!-- Additional Info Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: rgba(59, 130, 246, 0.1); border: 1px solid rgba(59, 130, 246, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="color: #60a5fa; font-size: 14px; font-weight: 600; margin: 0 0 10px;">Additional Information:</p>
                    <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0;">{{additional_info}}</p>
                  </td>
                </tr>
              </table>
              {{/if}}

              {{#if action_required}}
              <!-- Action Required Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: rgba(251, 191, 36, 0.1); border: 1px solid rgba(251, 191, 36, 0.3); border-radius: 12px; margin-bottom: 25px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="color: #fbbf24; font-size: 14px; font-weight: 600; margin: 0 0 10px;">Action Required:</p>
                    <p style="color: #9ca3af; font-size: 14px; line-height: 1.6; margin: 0;">{{action_required}}</p>
                  </td>
                </tr>
              </table>
              {{/if}}
              
              {{#if cta_url}}
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="{{cta_url}}" style="display: inline-block; background: linear-gradient(135deg, #f0b90b 0%, #d4a50a 100%); color: #000; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: 700; font-size: 15px;">{{cta_text}}</a>
                  </td>
                </tr>
              </table>
              {{/if}}
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #262a2f; padding: 25px 30px; text-align: center;">
              <p style="color: #6b7280; font-size: 12px; margin: 0;">This is an automated system notification.</p>
              <p style="color: #6b7280; font-size: 12px; margin: 10px 0 0;">{{platform_name}}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>', 'system', '["username", "notification_title", "notification_content", "additional_info", "action_required", "header_color_start", "header_color_end", "cta_url", "cta_text", "platform_name"]', true)
ON CONFLICT (name) DO UPDATE SET body = EXCLUDED.body, subject = EXCLUDED.subject, variables = EXCLUDED.variables, updated_at = now();
/*
  # Signup and Bonus Email Templates
  
  1. New Email Templates
    - "Signup OTP Verification" - For email verification during signup
    - "KYC Bonus Awarded" - Notification when $20 KYC bonus is credited
    - "First Deposit Bonus Awarded" - Notification when deposit match bonus is credited
    
  2. Purpose
    - Provide professional email communications for the bonus system
    - Support admin CRM functionality for these email types
*/

-- Insert Signup OTP Verification template
INSERT INTO public.email_templates (name, subject, body, category, variables, is_active)
SELECT 
  'Signup OTP Verification',
  'Your Shark Trades Verification Code',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Verify Your Email</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0f; font-family: Arial, sans-serif;">
  <table width="100%" cellspacing="0" cellpadding="0" style="background-color: #0a0a0f;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table width="500" cellspacing="0" cellpadding="0" style="background: #12121a; border-radius: 16px; border: 1px solid rgba(212, 175, 55, 0.2);">
          <tr>
            <td style="padding: 40px; text-align: center;">
              <div style="width: 60px; height: 60px; background: linear-gradient(135deg, #d4af37, #f4d03f); border-radius: 12px; margin: 0 auto 20px; line-height: 60px; font-size: 28px; font-weight: bold; color: #0a0a0f;">S</div>
              <h1 style="margin: 0; font-size: 24px; color: #ffffff;">Verify Your Email</h1>
              <p style="margin: 12px 0 0; font-size: 15px; color: #9ca3af;">Enter this code to complete your registration</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 20px 40px 30px;">
              <div style="background: rgba(212, 175, 55, 0.1); border: 2px solid rgba(212, 175, 55, 0.3); border-radius: 12px; padding: 24px; text-align: center;">
                <div style="font-size: 36px; font-weight: 800; letter-spacing: 12px; color: #d4af37;">{{code}}</div>
              </div>
              <p style="margin: 16px 0 0; font-size: 13px; color: #6b7280; text-align: center;">This code expires in <strong style="color: #d4af37;">{{expiry_minutes}} minutes</strong></p>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px;">
              <div style="background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.2); border-radius: 8px; padding: 16px;">
                <p style="margin: 0; font-size: 13px; color: #f87171;">
                  <strong>Security Notice:</strong> Never share this code with anyone.
                </p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding: 30px 40px; text-align: center; border-top: 1px solid rgba(212, 175, 55, 0.1);">
              <p style="margin: 0; font-size: 12px; color: #4b5563;">&copy; 2024 Shark Trades. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>',
  'general',
  '["{{code}}", "{{expiry_minutes}}", "{{email}}"]'::jsonb,
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.email_templates WHERE name = 'Signup OTP Verification'
);

-- Insert KYC Bonus Awarded template
INSERT INTO public.email_templates (name, subject, body, category, variables, is_active)
SELECT 
  'KYC Bonus Awarded',
  'Congratulations! Your $20 KYC Bonus is Ready',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>KYC Bonus Awarded</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0f; font-family: Arial, sans-serif;">
  <table width="100%" cellspacing="0" cellpadding="0" style="background-color: #0a0a0f;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table width="600" cellspacing="0" cellpadding="0" style="background: #12121a; border-radius: 16px; border: 1px solid rgba(212, 175, 55, 0.2);">
          <tr>
            <td style="padding: 40px; text-align: center;">
              <div style="width: 80px; height: 80px; background: linear-gradient(135deg, #22c55e, #16a34a); border-radius: 50%; margin: 0 auto 20px; line-height: 80px; font-size: 36px;">&#10003;</div>
              <h1 style="margin: 0; font-size: 28px; color: #ffffff;">KYC Verification Complete!</h1>
              <p style="margin: 12px 0 0; font-size: 16px; color: #9ca3af;">Hi {{first_name}}, your identity has been verified.</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px;">
              <div style="background: linear-gradient(135deg, rgba(34, 197, 94, 0.15) 0%, rgba(34, 197, 94, 0.05) 100%); border: 1px solid rgba(34, 197, 94, 0.3); border-radius: 12px; padding: 24px; text-align: center;">
                <p style="margin: 0 0 10px; font-size: 14px; color: #9ca3af;">Your Bonus Credit</p>
                <div style="font-size: 48px; font-weight: 800; color: #22c55e;">${{bonus_amount}}</div>
                <p style="margin: 10px 0 0; font-size: 14px; color: #9ca3af;">Locked Trading Bonus</p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px;">
              <div style="background: rgba(212, 175, 55, 0.1); border-radius: 8px; padding: 16px;">
                <p style="margin: 0 0 8px; font-size: 14px; color: #d4af37; font-weight: bold;">Important Information:</p>
                <ul style="margin: 0; padding-left: 20px; font-size: 13px; color: #9ca3af;">
                  <li>This bonus is valid for 7 days until {{expiry_date}}</li>
                  <li>Use it as margin for futures trading</li>
                  <li>Only profits can be withdrawn</li>
                  <li>The bonus amount itself cannot be withdrawn</li>
                </ul>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px; text-align: center;">
              <a href="https://shark-trades.com" style="display: inline-block; padding: 16px 48px; background: linear-gradient(135deg, #d4af37, #f4d03f); color: #0a0a0f; font-size: 16px; font-weight: 700; text-decoration: none; border-radius: 10px;">Start Trading</a>
            </td>
          </tr>
          <tr>
            <td style="padding: 30px 40px; text-align: center; border-top: 1px solid rgba(212, 175, 55, 0.1);">
              <p style="margin: 0; font-size: 12px; color: #4b5563;">&copy; 2024 Shark Trades. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>',
  'bonus',
  '["{{first_name}}", "{{bonus_amount}}", "{{expiry_date}}"]'::jsonb,
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.email_templates WHERE name = 'KYC Bonus Awarded'
);

-- Insert First Deposit Bonus Awarded template
INSERT INTO public.email_templates (name, subject, body, category, variables, is_active)
SELECT 
  'First Deposit Bonus Awarded',
  'Your 100% Deposit Match Bonus is Ready!',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>First Deposit Bonus</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0f; font-family: Arial, sans-serif;">
  <table width="100%" cellspacing="0" cellpadding="0" style="background-color: #0a0a0f;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table width="600" cellspacing="0" cellpadding="0" style="background: #12121a; border-radius: 16px; border: 1px solid rgba(212, 175, 55, 0.2);">
          <tr>
            <td style="padding: 40px; text-align: center;">
              <div style="width: 80px; height: 80px; background: linear-gradient(135deg, #d4af37, #f4d03f); border-radius: 50%; margin: 0 auto 20px; line-height: 80px; font-size: 36px; color: #0a0a0f; font-weight: bold;">%</div>
              <h1 style="margin: 0; font-size: 28px; color: #ffffff;">100% Deposit Match!</h1>
              <p style="margin: 12px 0 0; font-size: 16px; color: #9ca3af;">Hi {{first_name}}, we have matched your deposit!</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 20px;">
              <table width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="width: 48%; background: rgba(107, 114, 128, 0.2); border-radius: 12px; padding: 20px; text-align: center;">
                    <p style="margin: 0 0 8px; font-size: 12px; color: #9ca3af;">Your Deposit</p>
                    <div style="font-size: 28px; font-weight: 700; color: #ffffff;">${{deposit_amount}}</div>
                  </td>
                  <td style="width: 4%;"></td>
                  <td style="width: 48%; background: linear-gradient(135deg, rgba(212, 175, 55, 0.2) 0%, rgba(212, 175, 55, 0.1) 100%); border: 1px solid rgba(212, 175, 55, 0.3); border-radius: 12px; padding: 20px; text-align: center;">
                    <p style="margin: 0 0 8px; font-size: 12px; color: #d4af37;">Bonus Credit</p>
                    <div style="font-size: 28px; font-weight: 700; color: #d4af37;">+${{bonus_amount}}</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px;">
              <div style="background: rgba(212, 175, 55, 0.1); border-radius: 8px; padding: 16px;">
                <p style="margin: 0 0 8px; font-size: 14px; color: #d4af37; font-weight: bold;">Important Information:</p>
                <ul style="margin: 0; padding-left: 20px; font-size: 13px; color: #9ca3af;">
                  <li>This bonus is valid for 7 days until {{expiry_date}}</li>
                  <li>Use it as margin for futures trading</li>
                  <li>Only profits can be withdrawn</li>
                  <li>The bonus amount itself cannot be withdrawn</li>
                </ul>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px; text-align: center;">
              <a href="https://shark-trades.com" style="display: inline-block; padding: 16px 48px; background: linear-gradient(135deg, #d4af37, #f4d03f); color: #0a0a0f; font-size: 16px; font-weight: 700; text-decoration: none; border-radius: 10px;">Start Trading</a>
            </td>
          </tr>
          <tr>
            <td style="padding: 30px 40px; text-align: center; border-top: 1px solid rgba(212, 175, 55, 0.1);">
              <p style="margin: 0; font-size: 12px; color: #4b5563;">&copy; 2024 Shark Trades. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>',
  'bonus',
  '["{{first_name}}", "{{deposit_amount}}", "{{bonus_amount}}", "{{expiry_date}}"]'::jsonb,
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.email_templates WHERE name = 'First Deposit Bonus Awarded'
);

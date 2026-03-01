/*
  # Deposit Confirmation Email Template

  1. New Template
    - Creates email template for deposit confirmation with trading incentives
    - Includes call-to-action to start trading

  2. Purpose
    - Sent automatically when a deposit is confirmed
    - Encourage users to start trading immediately
*/

INSERT INTO email_templates (
  name,
  subject,
  body,
  category,
  is_active
) VALUES (
  'Deposit Confirmed',
  'Your Deposit is Confirmed - Start Trading Now!',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Deposit Confirmed</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0f1c; font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
    
    <div style="text-align: center; margin-bottom: 40px;">
      <h1 style="color: #00d4aa; font-size: 32px; margin: 0; font-weight: 700;">Shark Trades</h1>
      <p style="color: #64748b; font-size: 14px; margin-top: 8px;">Professional Crypto Trading Platform</p>
    </div>
    
    <div style="background: linear-gradient(135deg, #1a2332 0%, #0f1724 100%); border-radius: 16px; padding: 40px; border: 1px solid #1e293b;">
      
      <div style="text-align: center; margin-bottom: 30px;">
        <div style="width: 80px; height: 80px; background: linear-gradient(135deg, #00d4aa 0%, #00a884 100%); border-radius: 50%; margin: 0 auto 20px; line-height: 80px;">
          <span style="font-size: 40px; color: white;">&#10003;</span>
        </div>
        <h2 style="color: #ffffff; font-size: 28px; margin: 0 0 10px;">Deposit Confirmed!</h2>
        <p style="color: #94a3b8; font-size: 16px; margin: 0;">Your funds are ready to trade</p>
      </div>
      
      <div style="background: #0f1724; border-radius: 12px; padding: 24px; margin-bottom: 30px; border: 1px solid #1e293b;">
        <table style="width: 100%; border-collapse: collapse;">
          <tr style="border-bottom: 1px solid #1e293b;">
            <td style="color: #64748b; padding: 12px 0;">Amount Credited</td>
            <td style="color: #00d4aa; font-weight: 700; font-size: 20px; text-align: right; padding: 12px 0;">{{deposit_amount}} USDT</td>
          </tr>
          <tr style="border-bottom: 1px solid #1e293b;">
            <td style="color: #64748b; padding: 12px 0;">Currency Received</td>
            <td style="color: #ffffff; text-align: right; padding: 12px 0;">{{pay_currency}}</td>
          </tr>
          <tr>
            <td style="color: #64748b; padding: 12px 0;">New Balance</td>
            <td style="color: #ffffff; font-weight: 600; text-align: right; padding: 12px 0;">{{new_balance}} USDT</td>
          </tr>
        </table>
      </div>
      
      <div style="background: linear-gradient(135deg, #1e3a5f 0%, #0f2744 100%); border-radius: 12px; padding: 24px; margin-bottom: 30px; border: 1px solid #2563eb;">
        <h3 style="color: #60a5fa; font-size: 18px; margin: 0 0 16px;">Start Trading Now!</h3>
        <ul style="color: #94a3b8; font-size: 14px; margin: 0; padding-left: 20px; line-height: 1.8;">
          <li><strong style="color: #ffffff;">Futures Trading</strong> - Up to 150x leverage on BTC, ETH, and 50+ pairs</li>
          <li><strong style="color: #ffffff;">Copy Trading</strong> - Follow expert traders and earn automatically</li>
          <li><strong style="color: #ffffff;">Earn Rewards</strong> - Stake your crypto for passive income</li>
        </ul>
      </div>
      
      <div style="text-align: center; margin-bottom: 30px;">
        <a href="https://shark-trades.com/futures" style="display: inline-block; background: linear-gradient(135deg, #00d4aa 0%, #00a884 100%); color: #000000; text-decoration: none; padding: 16px 40px; border-radius: 8px; font-weight: 700; font-size: 16px; margin: 5px;">Start Trading</a>
        <a href="https://shark-trades.com/copy-trading" style="display: inline-block; background: transparent; color: #00d4aa; text-decoration: none; padding: 16px 40px; border-radius: 8px; font-weight: 600; font-size: 16px; border: 2px solid #00d4aa; margin: 5px;">Copy Traders</a>
      </div>
      
      <div style="background: #0f1724; border-radius: 12px; padding: 20px; margin-bottom: 20px; border: 1px solid #1e293b;">
        <h4 style="color: #ffffff; font-size: 14px; margin: 0 0 12px;">Pro Tips for New Traders:</h4>
        <ol style="color: #94a3b8; font-size: 13px; margin: 0; padding-left: 20px; line-height: 1.8;">
          <li>Start with lower leverage (5-10x) until you are comfortable</li>
          <li>Always set Take Profit and Stop Loss for risk management</li>
          <li>Try Copy Trading to learn from experienced traders</li>
          <li>Complete your KYC verification for 7 days of 0% trading fees</li>
        </ol>
      </div>
      
    </div>
    
    <div style="text-align: center; margin-top: 30px;">
      <p style="color: #64748b; font-size: 13px; margin: 0 0 15px;">Need help? Our support team is available 24/7</p>
      <a href="mailto:support@shark-trades.com" style="color: #00d4aa; text-decoration: none; font-size: 13px;">support@shark-trades.com</a>
    </div>
    
    <div style="text-align: center; margin-top: 30px; padding-top: 30px; border-top: 1px solid #1e293b;">
      <p style="color: #475569; font-size: 12px; margin: 0;">
        This is an automated message from Shark Trades.<br>
        Please do not reply directly to this email.
      </p>
    </div>
    
  </div>
</body>
</html>',
  'financial',
  true
) ON CONFLICT (name) DO UPDATE SET
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  is_active = true,
  updated_at = now();

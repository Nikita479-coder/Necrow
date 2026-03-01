/*
  # Update Withdrawal Completed Email Template
  
  1. Updates
    - Replace existing withdrawal completed email template with new premium design
    - Add placeholders for all withdrawal details: amount, currency, network, wallet_address, tx_hash, fee, net_amount
  
  2. Template Variables
    - {{amount}} - Total withdrawal amount
    - {{net_amount}} - Amount after fee deduction
    - {{fee}} - Withdrawal fee
    - {{currency}} - Currency code (USDT, BTC, etc.)
    - {{network}} - Network name (TRC20, ERC20, etc.)
    - {{wallet_address}} - Destination wallet address
    - {{tx_hash}} - Transaction hash/ID
    - {{explorer_url}} - Link to view transaction on blockchain explorer
*/

UPDATE email_templates
SET 
  subject = 'Withdrawal Successful - {{net_amount}} {{currency}}',
  body = '<!doctype html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <meta name="x-apple-disable-message-reformatting" />
    <title>Withdrawal Successful</title>
    <style>
      :root {
        color-scheme: dark;
        supported-color-schemes: dark;
      }
      body {
        margin: 0 !important;
        padding: 0 !important;
        background: #0b0f14 !important;
      }
      a {
        color: #f0b90b;
        text-decoration: none;
      }
      .preheader {
        display: none !important;
        visibility: hidden;
        opacity: 0;
        color: transparent;
        height: 0;
        width: 0;
        overflow: hidden;
        mso-hide: all;
      }
      @media (max-width: 600px) {
        .container {
          width: 100% !important;
        }
        .px {
          padding-left: 16px !important;
          padding-right: 16px !important;
        }
        .stack {
          display: block !important;
          width: 100% !important;
        }
        .btn {
          display: block !important;
          width: 100% !important;
        }
        .mono-wrap {
          word-break: break-all !important;
        }
      }
    </style>
  </head>

  <body style="margin:0; padding:0; background:#0b0f14;">
    <div class="preheader">
      Your withdrawal was successful on Shark Trades.
    </div>

    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#0b0f14;">
      <tr>
        <td align="center" style="padding:28px 12px;">
          <table
            role="presentation"
            width="640"
            cellspacing="0"
            cellpadding="0"
            border="0"
            class="container"
            style="width:640px; max-width:640px;"
          >
            <!-- Top bar / brand -->
            <tr>
              <td
                class="px"
                style="
                  padding: 14px 22px;
                  background: #0a0e13;
                  border: 1px solid #1b2430;
                  border-radius: 14px 14px 0 0;
                "
              >
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <tr>
                    <td align="left" style="vertical-align:middle;">
                      <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="display:inline-table; vertical-align:middle;">
                        <tr>
                          <td
                            width="28"
                            height="28"
                            style="
                              width:28px; height:28px;
                              background:#f0b90b;
                              border-radius:8px;
                              box-shadow: 0 10px 25px rgba(240,185,11,.18);
                              text-align:center;
                              vertical-align:middle;
                            "
                          >
                            <span style="font-family: Arial, Helvetica, sans-serif; font-size:14px; font-weight:800; color:#101319;">S</span>
                          </td>
                        </tr>
                      </table>

                      <span
                        style="
                          margin-left:10px;
                          font-family: Arial, Helvetica, sans-serif;
                          font-size: 16px;
                          font-weight: 700;
                          color: #e7eef7;
                          vertical-align: middle;
                        "
                        >&nbsp;Shark Trades</span
                      >
                    </td>

                    <td align="right" style="vertical-align:middle;">
                      <span
                        style="
                          font-family: Arial, Helvetica, sans-serif;
                          font-size: 12px;
                          color: #94a3b8;
                        "
                        >Security Notice</span
                      >
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Hero / success header -->
            <tr>
              <td
                class="px"
                style="
                  padding: 22px 22px 0;
                  background: #0f141c;
                  border-left: 1px solid #1b2430;
                  border-right: 1px solid #1b2430;
                "
              >
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <tr>
                    <td style="padding: 14px 16px; background:#0b1017; border:1px solid #1b2430; border-radius:14px;">
                      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                        <tr>
                          <td width="52" style="width:52px; vertical-align:top;">
                            <table role="presentation" width="40" cellspacing="0" cellpadding="0" border="0">
                              <tr>
                                <td
                                  width="40"
                                  height="40"
                                  style="
                                    width:40px;height:40px;
                                    border-radius:12px;
                                    background: rgba(16,185,129,.12);
                                    border: 1px solid rgba(16,185,129,.25);
                                    text-align:center;
                                    vertical-align:middle;
                                  "
                                >
                                  <span style="font-family: Arial, Helvetica, sans-serif; font-size:18px; color:#10b981; font-weight:800;">&#10003;</span>
                                </td>
                              </tr>
                            </table>
                          </td>

                          <td style="vertical-align:top;">
                            <div
                              style="
                                font-family: Arial, Helvetica, sans-serif;
                                font-size: 18px;
                                line-height: 24px;
                                font-weight: 800;
                                color: #e7eef7;
                              "
                            >
                              Withdrawal Successful
                            </div>
                            <div
                              style="
                                margin-top: 6px;
                                font-family: Arial, Helvetica, sans-serif;
                                font-size: 13px;
                                line-height: 18px;
                                color: #94a3b8;
                              "
                            >
                              Your funds have been sent on-chain. Keep this email for your records.
                            </div>
                          </td>

                          <td align="right" style="vertical-align:top;">
                            <div
                              style="
                                display:inline-block;
                                padding: 6px 10px;
                                border-radius: 999px;
                                background: rgba(240,185,11,.10);
                                border: 1px solid rgba(240,185,11,.25);
                                font-family: Arial, Helvetica, sans-serif;
                                font-size: 12px;
                                color: #f0b90b;
                                font-weight: 700;
                              "
                            >
                              Completed
                            </div>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Body -->
            <tr>
              <td
                class="px"
                style="
                  padding: 18px 22px 8px;
                  background: #0f141c;
                  border-left: 1px solid #1b2430;
                  border-right: 1px solid #1b2430;
                "
              >
                <div
                  style="
                    font-family: Arial, Helvetica, sans-serif;
                    font-size: 14px;
                    line-height: 22px;
                    color: #cbd5e1;
                  "
                >
                  Dear Valued Shark Trader,<br /><br />
                  You have successfully withdrawn <strong style="color:#e7eef7;">{{net_amount}} {{currency}}</strong> from your Shark Trades account.
                </div>

                <!-- Details card -->
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-top:14px;">
                  <tr>
                    <td style="padding:16px; background:#0b1017; border:1px solid #1b2430; border-radius:14px;">
                      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                        <tr>
                          <td class="stack" style="padding: 0 0 12px 0;">
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8;">Asset</div>
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:14px; color:#e7eef7; font-weight:700;">{{currency}}</div>
                          </td>
                          <td class="stack" style="padding: 0 0 12px 0;">
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8;">Amount</div>
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:14px; color:#e7eef7; font-weight:700;">{{amount}}</div>
                          </td>
                          <td class="stack" style="padding: 0 0 12px 0;">
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8;">Fee</div>
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:14px; color:#e7eef7; font-weight:700;">{{fee}}</div>
                          </td>
                          <td class="stack" style="padding: 0 0 12px 0;">
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8;">Chain</div>
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:14px; color:#e7eef7; font-weight:700;">{{network}}</div>
                          </td>
                        </tr>

                        <tr>
                          <td colspan="4" style="padding-top:10px; border-top:1px solid #1b2430;">
                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8; margin-top:12px;">
                              Your withdrawal address
                            </div>
                            <div
                              class="mono-wrap"
                              style="
                                margin-top:6px;
                                font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace;
                                font-size: 13px;
                                line-height: 18px;
                                color: #e7eef7;
                                background: #0a0e13;
                                border: 1px solid #1b2430;
                                border-radius: 10px;
                                padding: 10px 12px;
                                word-break: break-word;
                              "
                            >
                              {{wallet_address}}
                            </div>

                            <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8; margin-top:12px;">
                              TXID
                            </div>
                            <div
                              class="mono-wrap"
                              style="
                                margin-top:6px;
                                font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace;
                                font-size: 13px;
                                line-height: 18px;
                                color: #e7eef7;
                                background: #0a0e13;
                                border: 1px solid #1b2430;
                                border-radius: 10px;
                                padding: 10px 12px;
                                word-break: break-word;
                              "
                            >
                              {{tx_hash}}
                            </div>

                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin-top:14px;">
                              <tr>
                                <td
                                  class="btn"
                                  align="center"
                                  style="
                                    background:#f0b90b;
                                    border-radius:12px;
                                    box-shadow: 0 14px 30px rgba(240,185,11,.18);
                                  "
                                >
                                  <a
                                    href="{{explorer_url}}"
                                    style="
                                      display:inline-block;
                                      padding: 12px 18px;
                                      font-family: Arial, Helvetica, sans-serif;
                                      font-size: 14px;
                                      font-weight: 800;
                                      color: #101319;
                                      text-decoration:none;
                                    "
                                    target="_blank"
                                    >View transaction</a
                                  >
                                </td>
                              </tr>
                            </table>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                </table>

                <!-- Security warning -->
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-top:14px;">
                  <tr>
                    <td
                      style="
                        padding: 14px 16px;
                        background: rgba(239,68,68,.08);
                        border: 1px solid rgba(239,68,68,.22);
                        border-radius: 14px;
                      "
                    >
                      <div
                        style="
                          font-family: Arial, Helvetica, sans-serif;
                          font-size: 13px;
                          line-height: 18px;
                          color: #fecaca;
                          font-weight: 800;
                        "
                      >
                        If this was not you
                      </div>
                      <div
                        style="
                          margin-top:6px;
                          font-family: Arial, Helvetica, sans-serif;
                          font-size: 13px;
                          line-height: 20px;
                          color: #fca5a5;
                        "
                      >
                        If you believe your account has been compromised, please contact us immediately via live chat or submit a ticket.
                      </div>
                    </td>
                  </tr>
                </table>

                <div
                  style="
                    margin-top: 16px;
                    font-family: Arial, Helvetica, sans-serif;
                    font-size: 14px;
                    line-height: 22px;
                    color: #cbd5e1;
                  "
                >
                  Regards,<br />
                  <strong style="color:#e7eef7;">The Shark Trades Team</strong>
                </div>
              </td>
            </tr>

            <!-- Footer -->
            <tr>
              <td
                class="px"
                style="
                  padding: 14px 22px 20px;
                  background: #0f141c;
                  border-left: 1px solid #1b2430;
                  border-right: 1px solid #1b2430;
                  border-bottom: 1px solid #1b2430;
                  border-radius: 0 0 14px 14px;
                "
              >
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <tr>
                    <td style="padding-top:10px; border-top:1px solid #1b2430;">
                      <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; line-height:18px; color:#94a3b8;">
                        &copy; Shark Trades. All rights reserved.<br />
                        This is an automated message - please do not reply.
                      </div>
                    </td>
                    <td align="right" style="padding-top:10px; border-top:1px solid #1b2430;">
                      <div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8;">
                        <a href="https://shark-trades.com/support" style="color:#f0b90b;">Support</a>
                        <span style="color:#334155;">&nbsp;&bull;&nbsp;</span>
                        <a href="https://shark-trades.com/security" style="color:#f0b90b;">Security</a>
                      </div>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Spacer -->
            <tr>
              <td style="height:18px; line-height:18px; font-size:0;">&nbsp;</td>
            </tr>

            <!-- Tiny disclaimer -->
            <tr>
              <td align="center" style="padding:0 18px;">
                <div style="font-family: Arial, Helvetica, sans-serif; font-size:11px; line-height:16px; color:#64748b;">
                  Never share your password, 2FA codes, or private keys. Shark Trades will never ask you for them.
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>',
  variables = '["username", "amount", "net_amount", "fee", "currency", "network", "wallet_address", "tx_hash", "explorer_url"]'::jsonb,
  updated_at = now()
WHERE name = 'Withdrawal Completed';

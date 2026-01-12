import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const SMTP_CONFIG = {
  host: Deno.env.get('SMTP_HOST') || 'smtp.hostinger.com',
  port: parseInt(Deno.env.get('SMTP_PORT') || '465'),
  username: Deno.env.get('SMTP_USERNAME') || 'support@shark-trades.com',
  password: Deno.env.get('SMTP_PASSWORD') || '9$4.h3b5}Zz.',
  from: Deno.env.get('SMTP_FROM') || 'Shark Trades <support@shark-trades.com>',
  useSsl: (Deno.env.get('SMTP_PORT') || '465') === '465',
};

interface PasswordResetRequest {
  email: string;
  redirectTo?: string;
}

class SmtpClient {
  private conn: Deno.TcpConn | null = null;
  private tlsConn: Deno.TlsConn | null = null;
  private encoder = new TextEncoder();
  private decoder = new TextDecoder();

  async connect(): Promise<void> {
    if (SMTP_CONFIG.useSsl) {
      this.tlsConn = await Deno.connectTls({
        hostname: SMTP_CONFIG.host,
        port: SMTP_CONFIG.port,
      });
      await this.readResponse();
    } else {
      this.conn = await Deno.connect({
        hostname: SMTP_CONFIG.host,
        port: SMTP_CONFIG.port,
      });
      await this.readResponse();
    }
  }

  private async readResponse(): Promise<string> {
    const conn = this.tlsConn || this.conn;
    if (!conn) throw new Error('Not connected');
    
    let response = '';
    const buffer = new Uint8Array(4096);
    
    while (true) {
      const n = await conn.read(buffer);
      if (!n) break;
      response += this.decoder.decode(buffer.subarray(0, n));
      
      const lines = response.split('\r\n');
      const lastCompleteLine = lines.length > 1 ? lines[lines.length - 2] : '';
      
      if (lastCompleteLine && lastCompleteLine.length >= 4) {
        const fourthChar = lastCompleteLine.charAt(3);
        if (fourthChar === ' ' || fourthChar === '\r' || lastCompleteLine.length === 3) {
          break;
        }
      }
      
      if (response.endsWith('\r\n') && !response.includes('\r\n-')) {
        const allLines = response.trim().split('\r\n');
        const last = allLines[allLines.length - 1];
        if (last.length >= 3 && last.charAt(3) !== '-') {
          break;
        }
      }
      
      await new Promise(resolve => setTimeout(resolve, 50));
      if (response.length > 10000) break;
    }
    
    return response.trim();
  }

  private async sendCommand(command: string): Promise<string> {
    const conn = this.tlsConn || this.conn;
    if (!conn) throw new Error('Not connected');
    
    await conn.write(this.encoder.encode(command + '\r\n'));
    await new Promise(resolve => setTimeout(resolve, 100));
    return await this.readResponse();
  }

  async startTls(): Promise<void> {
    if (!this.conn) throw new Error('Not connected');
    
    await this.sendCommand('EHLO shark-trades.com');
    
    const conn = this.conn;
    await conn.write(this.encoder.encode('STARTTLS\r\n'));
    await new Promise(resolve => setTimeout(resolve, 100));
    
    const buffer = new Uint8Array(1024);
    const n = await conn.read(buffer);
    const starttlsResp = this.decoder.decode(buffer.subarray(0, n || 0)).trim();
    
    if (!starttlsResp.startsWith('220')) {
      throw new Error('STARTTLS failed: ' + starttlsResp);
    }
    
    this.tlsConn = await Deno.startTls(this.conn, { hostname: SMTP_CONFIG.host });
    this.conn = null;
    
    await this.sendCommand('EHLO shark-trades.com');
  }

  async initializeSsl(): Promise<void> {
    await this.sendCommand('EHLO shark-trades.com');
  }

  async authenticate(): Promise<void> {
    if (!SMTP_CONFIG.username || !SMTP_CONFIG.password) {
      throw new Error('SMTP credentials not configured');
    }

    const authResp = await this.sendCommand('AUTH LOGIN');
    if (!authResp.startsWith('334')) {
      throw new Error('AUTH LOGIN failed: ' + authResp);
    }

    const userResp = await this.sendCommand(btoa(SMTP_CONFIG.username));
    if (!userResp.startsWith('334')) {
      throw new Error('Username rejected: ' + userResp);
    }

    const passResp = await this.sendCommand(btoa(SMTP_CONFIG.password));
    if (!passResp.startsWith('235')) {
      throw new Error('Authentication failed');
    }
  }

  async sendEmail(to: string, subject: string, htmlBody: string): Promise<void> {
    const mailFromResp = await this.sendCommand(`MAIL FROM:<${SMTP_CONFIG.username}>`);
    if (!mailFromResp.startsWith('250')) {
      throw new Error('MAIL FROM failed: ' + mailFromResp);
    }
    
    const rcptToResp = await this.sendCommand(`RCPT TO:<${to}>`);
    if (!rcptToResp.startsWith('250')) {
      throw new Error('RCPT TO failed: ' + rcptToResp);
    }
    
    const dataResp = await this.sendCommand('DATA');
    if (!dataResp.startsWith('354')) {
      throw new Error('DATA failed: ' + dataResp);
    }
    
    const boundary = '----=_Part_' + Date.now();
    const plainText = htmlBody.replace(/<[^>]*>/g, '');
    
    const emailContent = [
      `From: ${SMTP_CONFIG.from}`,
      `To: ${to}`,
      `Subject: ${subject}`,
      'MIME-Version: 1.0',
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
      '',
      `--${boundary}`,
      'Content-Type: text/plain; charset="UTF-8"',
      'Content-Transfer-Encoding: 7bit',
      '',
      plainText,
      '',
      `--${boundary}`,
      'Content-Type: text/html; charset="UTF-8"',
      'Content-Transfer-Encoding: 7bit',
      '',
      htmlBody,
      '',
      `--${boundary}--`,
    ].join('\r\n');
    
    const endResp = await this.sendCommand(emailContent + '\r\n.');
    if (!endResp.startsWith('250')) {
      throw new Error('Email send failed: ' + endResp);
    }
  }

  async close(): Promise<void> {
    try {
      await this.sendCommand('QUIT');
    } catch (_e) {
      // Ignore
    }
    try {
      this.tlsConn?.close();
    } catch (_e) {
      // Ignore
    }
  }
}

async function sendSmtpEmail(to: string, subject: string, htmlBody: string): Promise<void> {
  const client = new SmtpClient();

  try {
    await client.connect();

    if (SMTP_CONFIG.useSsl) {
      await client.initializeSsl();
    } else {
      await client.startTls();
    }

    await client.authenticate();
    await client.sendEmail(to, subject, htmlBody);
  } finally {
    await client.close();
  }
}

function generatePasswordResetEmail(firstName: string, resetLink: string): string {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Password</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0b0e11;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #1a1d29; border-radius: 16px; overflow: hidden; border: 1px solid #2a2d39;">
          <tr>
            <td style="padding: 32px 40px; background: linear-gradient(135deg, #1a1d29 0%, #252837 100%); border-bottom: 1px solid #2a2d39;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <h1 style="margin: 0; font-size: 28px; font-weight: 700; color: #f0b90b; letter-spacing: -0.5px;">Shark Trades</h1>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 40px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center" style="padding-bottom: 24px;">
                    <div style="width: 80px; height: 80px; background-color: rgba(240, 185, 11, 0.15); border-radius: 50%; display: inline-block; line-height: 80px; text-align: center;">
                      <span style="font-size: 40px;">&#x1F510;</span>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td>
                    <h2 style="margin: 0 0 16px; font-size: 24px; font-weight: 600; color: #ffffff; text-align: center;">Password Reset Request</h2>
                    <p style="margin: 0 0 24px; font-size: 16px; line-height: 1.6; color: #9ca3af; text-align: center;">Hello ${firstName},</p>
                    <p style="margin: 0 0 24px; font-size: 16px; line-height: 1.6; color: #9ca3af; text-align: center;">We received a request to reset the password for your Shark Trades account associated with this email address.</p>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding: 24px 0;">
                    <a href="${resetLink}" style="display: inline-block; padding: 16px 48px; background-color: #f0b90b; color: #000000; font-size: 16px; font-weight: 600; text-decoration: none; border-radius: 8px;">Reset Password</a>
                  </td>
                </tr>
                <tr>
                  <td>
                    <p style="margin: 24px 0 0; font-size: 14px; line-height: 1.6; color: #6b7280; text-align: center;">This link will expire in <strong style="color: #9ca3af;">1 hour</strong> for security reasons.</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 40px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.2); border-radius: 12px;">
                <tr>
                  <td style="padding: 20px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="40" valign="top"><span style="font-size: 20px;">&#x26A0;&#xFE0F;</span></td>
                        <td>
                          <p style="margin: 0; font-size: 14px; font-weight: 600; color: #f87171;">Security Notice</p>
                          <p style="margin: 8px 0 0; font-size: 13px; line-height: 1.5; color: #9ca3af;">If you did not request this password reset, please ignore this email or contact our support team immediately. Never share this link with anyone.</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 40px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #252837; border-radius: 12px;">
                <tr>
                  <td style="padding: 20px;">
                    <p style="margin: 0 0 12px; font-size: 13px; font-weight: 600; color: #ffffff;">Button not working?</p>
                    <p style="margin: 0; font-size: 12px; line-height: 1.5; color: #6b7280;">Copy and paste this link into your browser:</p>
                    <p style="margin: 8px 0 0; font-size: 11px; line-height: 1.5; color: #f0b90b; word-break: break-all;">${resetLink}</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 24px 40px; background-color: #0b0e11; border-top: 1px solid #2a2d39;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 8px; font-size: 13px; color: #6b7280;">Need help? Contact us at <a href="mailto:support@shark-trades.com" style="color: #f0b90b; text-decoration: none;">support@shark-trades.com</a></p>
                    <p style="margin: 0; font-size: 12px; color: #4b5563;">2024 Shark Trades. All rights reserved.</p>
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
</html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const requestData: PasswordResetRequest = await req.json();
    const { email, redirectTo } = requestData;

    if (!email || !email.includes('@')) {
      throw new Error('Valid email address is required');
    }

    const normalizedEmail = email.toLowerCase().trim();

    const { data: users, error: userError } = await supabase.auth.admin.listUsers();
    
    if (userError) {
      console.error('Error listing users:', userError);
    }

    const user = users?.users?.find(u => u.email?.toLowerCase() === normalizedEmail);

    if (!user) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'If an account exists with this email, a reset link will be sent.',
        }),
        {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    const { data: profile } = await supabase
      .from('user_profiles')
      .select('full_name')
      .eq('id', user.id)
      .maybeSingle();

    const firstName = profile?.full_name ? profile.full_name.split(' ')[0] : 'User';

    const siteUrl = redirectTo || 'https://shark-trades.com';
    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: 'recovery',
      email: normalizedEmail,
      options: {
        redirectTo: siteUrl,
      },
    });

    if (linkError) {
      console.error('Error generating recovery link:', linkError);
      throw new Error('Failed to generate reset link');
    }

    const resetLink = linkData.properties?.action_link || '';

    if (!resetLink) {
      throw new Error('Failed to generate reset link');
    }

    const emailHtml = generatePasswordResetEmail(firstName, resetLink);

    await sendSmtpEmail(
      normalizedEmail,
      'Reset Your Shark Trades Password',
      emailHtml
    );

    await supabase
      .from('email_logs')
      .insert({
        user_id: user.id,
        template_name: 'Password Reset',
        subject: 'Reset Your Shark Trades Password',
        body: emailHtml,
        status: 'sent',
        sent_at: new Date().toISOString(),
      });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'If an account exists with this email, a reset link will be sent.',
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    console.error('Error sending password reset email:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});
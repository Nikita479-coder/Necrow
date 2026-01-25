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

interface WelcomeEmailRequest {
  email: string;
  full_name?: string;
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
    }
    try {
      this.tlsConn?.close();
    } catch (_e) {
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

function generateWelcomeEmailHtml(firstName: string): string {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0f; font-family: Arial, sans-serif;">
  <table width="100%" cellspacing="0" cellpadding="0" style="background-color: #0a0a0f;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #12121a; border-radius: 16px; border: 1px solid #2a2a3a;">
          <tr>
            <td style="padding: 40px; text-align: center;">
              <div style="width: 70px; height: 70px; background: #d4af37; border-radius: 14px; margin: 0 auto 24px; line-height: 70px;">
                <span style="font-size: 36px; font-weight: bold; color: #0a0a0f;">S</span>
              </div>
              <h1 style="margin: 0 0 16px; font-size: 28px; font-weight: 700; color: #ffffff;">Welcome to Shark Trades!</h1>
              <p style="margin: 0 0 30px; font-size: 16px; color: #9ca3af; line-height: 1.5;">Hi ${firstName}, your account is ready. Start trading today!</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px;">
              <table width="100%" cellspacing="0" cellpadding="0" style="background: #1a1a2e; border-radius: 12px; border: 1px solid #d4af3740;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 16px; font-size: 18px; font-weight: 600; color: #d4af37;">Your Welcome Bonuses</h2>
                    <table width="100%" cellspacing="0" cellpadding="0">
                      <tr>
                        <td style="padding: 12px 0; border-bottom: 1px solid #2a2a3a;">
                          <span style="color: #d4af37; font-weight: 600;">100% First Deposit Bonus</span>
                          <p style="margin: 4px 0 0; font-size: 13px; color: #9ca3af;">Get up to $500 matched on your first deposit</p>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 12px 0;">
                          <span style="color: #22c55e; font-weight: 600;">Zero Trading Fees for 7 Days</span>
                          <p style="margin: 4px 0 0; font-size: 13px; color: #9ca3af;">Trade with 0% fees after KYC verification</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 30px;">
              <h2 style="margin: 0 0 16px; font-size: 18px; font-weight: 600; color: #ffffff;">Get Started</h2>
              <table width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="padding: 10px 0;">
                    <table cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="30"><span style="display: inline-block; width: 24px; height: 24px; background: #d4af37; border-radius: 50%; text-align: center; line-height: 24px; font-size: 12px; font-weight: 700; color: #0a0a0f;">1</span></td>
                        <td style="padding-left: 12px; color: #ffffff; font-size: 14px;">Make your first deposit</td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0;">
                    <table cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="30"><span style="display: inline-block; width: 24px; height: 24px; background: #d4af37; border-radius: 50%; text-align: center; line-height: 24px; font-size: 12px; font-weight: 700; color: #0a0a0f;">2</span></td>
                        <td style="padding-left: 12px; color: #ffffff; font-size: 14px;">Complete KYC verification</td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0;">
                    <table cellspacing="0" cellpadding="0">
                      <tr>
                        <td width="30"><span style="display: inline-block; width: 24px; height: 24px; background: #d4af37; border-radius: 50%; text-align: center; line-height: 24px; font-size: 12px; font-weight: 700; color: #0a0a0f;">3</span></td>
                        <td style="padding-left: 12px; color: #ffffff; font-size: 14px;">Start trading or copy expert traders</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 0 40px 40px; text-align: center;">
              <a href="https://shark-trades.com/?page=deposit" style="display: inline-block; padding: 16px 40px; background: #d4af37; color: #0a0a0f; font-size: 16px; font-weight: 700; text-decoration: none; border-radius: 8px;">Make Your First Deposit</a>
            </td>
          </tr>
          <tr>
            <td style="padding: 20px 40px; text-align: center; border-top: 1px solid #2a2a3a;">
              <p style="margin: 0 0 8px; font-size: 13px; color: #6b7280;">Need help? Contact us at</p>
              <a href="mailto:support@shark-trades.com" style="color: #d4af37; text-decoration: none; font-size: 13px;">support@shark-trades.com</a>
            </td>
          </tr>
          <tr>
            <td style="padding: 20px 40px; text-align: center; background: #0a0a0f; border-radius: 0 0 16px 16px;">
              <p style="margin: 0; font-size: 11px; color: #4b5563;">2025 Shark Trades. All rights reserved.</p>
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

    const requestData: WelcomeEmailRequest = await req.json();
    const { email, full_name } = requestData;

    if (!email || !email.includes('@')) {
      throw new Error('Valid email address is required');
    }

    const normalizedEmail = email.toLowerCase().trim();
    const firstName = full_name ? full_name.split(' ')[0] : 'Trader';

    const emailHtml = generateWelcomeEmailHtml(firstName);

    await sendSmtpEmail(
      normalizedEmail,
      'Welcome to Shark Trades - Your Trading Journey Begins!',
      emailHtml
    );

    await supabase
      .from('email_logs')
      .insert({
        template_name: 'Welcome Email',
        subject: 'Welcome to Shark Trades - Your Trading Journey Begins!',
        body: emailHtml,
        status: 'sent',
        sent_at: new Date().toISOString(),
      });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Welcome email sent successfully',
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    console.error('Error sending welcome email:', error);

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
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const SMTP_CONFIG = {
  host: Deno.env.get('SMTP_HOST') || 'smtppro.zoho.eu',
  port: parseInt(Deno.env.get('SMTP_PORT') || '465'),
  username: Deno.env.get('SMTP_USERNAME') || '',
  password: Deno.env.get('SMTP_PASSWORD') || '',
  from: Deno.env.get('SMTP_FROM') || 'Shark Trades <support@shark-trades.com>',
  useSsl: (Deno.env.get('SMTP_PORT') || '465') === '465',
};

interface VerificationRequest {
  email: string;
  userId: string;
  ipAddress: string;
  deviceInfo?: string;
  location?: {
    city?: string;
    country?: string;
    region?: string;
  };
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
      throw new Error('Authentication failed: ' + passResp);
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
      // Ignore quit errors
    }
    try {
      this.tlsConn?.close();
    } catch (_e) {
      // Ignore close errors
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const requestData: VerificationRequest = await req.json();
    const { email, userId, ipAddress, deviceInfo, location } = requestData;

    if (!email || !userId || !ipAddress) {
      throw new Error('Missing required fields: email, userId, ipAddress');
    }

    const { data: code, error: codeError } = await supabase.rpc('create_ip_verification_code', {
      p_user_id: userId,
      p_email: email,
      p_ip_address: ipAddress,
      p_device_info: deviceInfo || null,
      p_location: location || {},
    });

    if (codeError) {
      console.error('Error creating verification code:', codeError);
      throw new Error('Failed to create verification code');
    }

    const locationText = location?.city && location?.country
      ? `${location.city}, ${location.country}`
      : location?.country || 'Unknown location';

    const emailSubject = 'Verify Your New Device - Security Alert';
    const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0b0e11; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: #0b0e11;">
    <tr>
      <td style="padding: 40px 20px;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width: 600px; margin: 0 auto; background-color: #181a20; border-radius: 12px; border: 1px solid #2b3139;">
          <tr>
            <td style="padding: 32px 32px 24px; text-align: center; border-bottom: 1px solid #2b3139;">
              <h1 style="margin: 0; font-size: 24px; font-weight: 600; color: #f0b90b;">Security Alert</h1>
            </td>
          </tr>
          <tr>
            <td style="padding: 32px;">
              <p style="margin: 0 0 20px; font-size: 16px; line-height: 1.6; color: #eaecef;">
                We detected a login attempt from a new device or location. To continue, please verify this is you.
              </p>
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: #0b0e11; border-radius: 8px; margin-bottom: 24px;">
                <tr>
                  <td style="padding: 16px;">
                    <p style="margin: 0 0 8px; font-size: 13px; color: #848e9c;">IP Address</p>
                    <p style="margin: 0 0 16px; font-size: 15px; color: #eaecef;">${ipAddress}</p>
                    <p style="margin: 0 0 8px; font-size: 13px; color: #848e9c;">Location</p>
                    <p style="margin: 0 0 16px; font-size: 15px; color: #eaecef;">${locationText}</p>
                    ${deviceInfo ? `<p style="margin: 0 0 8px; font-size: 13px; color: #848e9c;">Device</p>
                    <p style="margin: 0; font-size: 15px; color: #eaecef;">${deviceInfo}</p>` : ''}
                  </td>
                </tr>
              </table>
              <div style="text-align: center; margin-bottom: 24px;">
                <p style="margin: 0 0 12px; font-size: 14px; color: #848e9c;">Your verification code:</p>
                <div style="display: inline-block; background-color: #f0b90b; padding: 16px 48px; border-radius: 8px;">
                  <span style="font-size: 32px; font-weight: 700; letter-spacing: 8px; color: #0b0e11;">${code}</span>
                </div>
              </div>
              <p style="margin: 0 0 8px; font-size: 14px; line-height: 1.6; color: #848e9c; text-align: center;">
                This code will expire in <strong style="color: #eaecef;">15 minutes</strong>.
              </p>
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: #1e2329; border-radius: 8px; margin-top: 24px; border-left: 4px solid #f6465d;">
                <tr>
                  <td style="padding: 16px;">
                    <p style="margin: 0; font-size: 14px; line-height: 1.6; color: #eaecef;">
                      <strong>If this wasn't you:</strong> Someone may be trying to access your account. We recommend changing your password immediately.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 24px 32px; border-top: 1px solid #2b3139; text-align: center;">
              <p style="margin: 0; font-size: 13px; color: #848e9c;">
                This is an automated security email. Please do not reply.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

    if (!SMTP_CONFIG.username || !SMTP_CONFIG.password) {
      console.error('SMTP credentials not configured');
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Verification code created. Email delivery may be delayed.',
          codeCreated: true,
        }),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    await sendSmtpEmail(email, emailSubject, emailHtml);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Verification code sent to your email',
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error: any) {
    console.error('Error in send-ip-verification:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to send verification code',
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
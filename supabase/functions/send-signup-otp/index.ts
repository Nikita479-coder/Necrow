import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const SMTP_CONFIG = {
  host: Deno.env.get('SMTP_HOST') || 'smtppro.zoho.eu',
  port: parseInt(Deno.env.get('SMTP_PORT') || '465'),
  username: Deno.env.get('SMTP_USERNAME') || 'support@shark-trades.com',
  password: Deno.env.get('SMTP_PASSWORD') || '9$4.h3b5}Zz.',
  from: Deno.env.get('SMTP_FROM') || 'Shark Trades <support@shark-trades.com>',
  useSsl: (Deno.env.get('SMTP_PORT') || '465') === '465',
};

interface OtpRequest {
  email: string;
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

function generateOtpEmailHtml(code: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verify Your Email - Shark Trades</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0f; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0a0a0f;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width: 500px; background: linear-gradient(135deg, #12121a 0%, #1a1a2e 100%); border-radius: 16px; border: 1px solid rgba(212, 175, 55, 0.2);">
          <!-- Header -->
          <tr>
            <td style="padding: 40px 40px 20px; text-align: center;">
              <div style="display: inline-flex; align-items: center; justify-content: center; width: 60px; height: 60px; background: linear-gradient(135deg, #d4af37, #f4d03f); border-radius: 12px; margin-bottom: 20px;">
                <span style="font-size: 28px; font-weight: bold; color: #0a0a0f;">S</span>
              </div>
              <h1 style="margin: 0; font-size: 24px; font-weight: 700; color: #ffffff; letter-spacing: -0.5px;">Verify Your Email</h1>
              <p style="margin: 12px 0 0; font-size: 15px; color: #9ca3af;">Enter this code to complete your registration</p>
            </td>
          </tr>
          
          <!-- OTP Code -->
          <tr>
            <td style="padding: 20px 40px 30px;">
              <div style="background: linear-gradient(135deg, rgba(212, 175, 55, 0.1) 0%, rgba(212, 175, 55, 0.05) 100%); border: 2px solid rgba(212, 175, 55, 0.3); border-radius: 12px; padding: 24px; text-align: center;">
                <div style="font-size: 36px; font-weight: 800; letter-spacing: 12px; color: #d4af37; font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;">${code}</div>
              </div>
              <p style="margin: 16px 0 0; font-size: 13px; color: #6b7280; text-align: center;">This code expires in <strong style="color: #d4af37;">15 minutes</strong></p>
            </td>
          </tr>
          
          <!-- Security Notice -->
          <tr>
            <td style="padding: 0 40px 30px;">
              <div style="background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.2); border-radius: 8px; padding: 16px;">
                <p style="margin: 0; font-size: 13px; color: #f87171; line-height: 1.5;">
                  <strong>Security Notice:</strong> Never share this code with anyone. Shark Trades staff will never ask for your verification code.
                </p>
              </div>
            </td>
          </tr>
          
          <!-- Divider -->
          <tr>
            <td style="padding: 0 40px;">
              <div style="height: 1px; background: linear-gradient(90deg, transparent, rgba(212, 175, 55, 0.3), transparent);"></div>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 30px 40px; text-align: center;">
              <p style="margin: 0 0 8px; font-size: 12px; color: #6b7280;">If you didn't request this code, you can safely ignore this email.</p>
              <p style="margin: 0; font-size: 12px; color: #4b5563;">&copy; 2024 Shark Trades. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
`;
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

    const requestData: OtpRequest = await req.json();
    const { email } = requestData;

    if (!email || !email.includes('@')) {
      throw new Error('Valid email address is required');
    }

    const normalizedEmail = email.toLowerCase().trim();

    const { data: codeResult, error: codeError } = await supabase.rpc('create_verification_code', {
      p_email: normalizedEmail,
    });

    if (codeError) {
      throw new Error('Failed to generate verification code: ' + codeError.message);
    }

    if (!codeResult.success) {
      throw new Error(codeResult.error || 'Failed to generate verification code');
    }

    const otpCode = codeResult.code;
    const emailHtml = generateOtpEmailHtml(otpCode);

    await sendSmtpEmail(
      normalizedEmail,
      'Your Shark Trades Verification Code',
      emailHtml
    );

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Verification code sent successfully',
        expires_in_minutes: codeResult.expires_in_minutes,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    console.error('Error sending OTP:', error);

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

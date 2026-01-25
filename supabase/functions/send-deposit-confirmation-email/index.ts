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

interface DepositEmailRequest {
  user_id: string;
  deposit_amount: number;
  pay_currency: string;
  new_balance: number;
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
    } catch (_e) {}
    try {
      this.tlsConn?.close();
    } catch (_e) {}
  }
}

async function sendSmtpEmail(to: string, subject: string, htmlBody: string): Promise<void> {
  const client = new SmtpClient();

  try {
    await client.connect();
    await client.initializeSsl();
    await client.authenticate();
    await client.sendEmail(to, subject, htmlBody);
  } finally {
    await client.close();
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const requestData: DepositEmailRequest = await req.json();
    const { user_id, deposit_amount, pay_currency, new_balance } = requestData;

    if (!user_id) {
      throw new Error('user_id is required');
    }

    const { data: userAuthData } = await supabase.auth.admin.getUserById(user_id);
    if (!userAuthData?.user?.email) {
      console.log('User email not found, skipping deposit confirmation email');
      return new Response(
        JSON.stringify({ success: true, message: 'No email found for user' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('full_name, username, kyc_level, zero_fee_expires_at')
      .eq('id', user_id)
      .single();

    const { data: template } = await supabase
      .from('email_templates')
      .select('subject, body')
      .eq('name', 'Deposit Confirmed')
      .eq('is_active', true)
      .single();

    if (!template) {
      throw new Error('Deposit Confirmed email template not found');
    }

    const fullName = userProfile?.full_name || 'Valued Customer';
    const firstName = fullName.split(' ')[0] || 'User';
    const hasZeroFeePromo = userProfile?.zero_fee_expires_at &&
      new Date(userProfile.zero_fee_expires_at) > new Date();

    const variables: Record<string, string> = {
      '{{deposit_amount}}': deposit_amount.toFixed(2),
      '{{pay_currency}}': pay_currency,
      '{{new_balance}}': new_balance.toFixed(2),
      '{{username}}': userProfile?.username || 'User',
      '{{full_name}}': fullName,
      '{{first_name}}': firstName,
      '{{email}}': userAuthData.user.email,
    };

    let emailSubject = template.subject;
    let emailBody = template.body;

    Object.entries(variables).forEach(([key, value]) => {
      const regex = new RegExp(key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
      emailSubject = emailSubject.replace(regex, value);
      emailBody = emailBody.replace(regex, value);
    });

    if (hasZeroFeePromo) {
      const zeroFeeSection = `
      <div style="background: linear-gradient(135deg, #065f46 0%, #064e3b 100%); border-radius: 12px; padding: 20px; margin-bottom: 30px; border: 1px solid #10b981; text-align: center;">
        <p style="color: #10b981; font-weight: 700; font-size: 16px; margin: 0 0 5px;">0% TRADING FEES ACTIVE!</p>
        <p style="color: #a7f3d0; font-size: 14px; margin: 0;">Your KYC verification bonus is still active. Trade with zero fees for maximum profits!</p>
      </div>`;

      emailBody = emailBody.replace(
        '<div style="text-align: center; margin-bottom: 30px;">',
        zeroFeeSection + '<div style="text-align: center; margin-bottom: 30px;">'
      );
    }

    await sendSmtpEmail(userAuthData.user.email, emailSubject, emailBody);

    await supabase.from('email_logs').insert({
      user_id: user_id,
      template_name: 'Deposit Confirmed',
      subject: emailSubject,
      status: 'sent',
      sent_at: new Date().toISOString(),
    });

    console.log(`Deposit confirmation email sent to ${userAuthData.user.email}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Deposit confirmation email sent',
        email: userAuthData.user.email,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error sending deposit confirmation email:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

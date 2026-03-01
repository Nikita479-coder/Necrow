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

interface EmailRequest {
  user_id: string;
  template_id?: string;
  subject?: string;
  body?: string;
  custom_variables?: Record<string, string>;
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
      throw new Error('SMTP credentials not configured. Please set SMTP_USERNAME and SMTP_PASSWORD environment variables.');
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
      throw new Error('Authentication failed. If using Zoho with 2FA, generate an App Password from Zoho Mail settings.');
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

    const requestData: EmailRequest = await req.json();
    const { user_id, template_id, subject: customSubject, body: customBody, custom_variables } = requestData;

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Authorization header required');
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user: adminUser }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !adminUser) {
      throw new Error('Unauthorized');
    }

    const { data: adminProfile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', adminUser.id)
      .single();

    if (!adminProfile?.is_admin) {
      throw new Error('Admin access required');
    }

    const { data: userAuthData } = await supabase.auth.admin.getUserById(user_id);
    if (!userAuthData?.user?.email) {
      throw new Error('User email not found');
    }

    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', user_id)
      .single();

    const { data: wallets } = await supabase
      .from('wallets')
      .select('balance, currency')
      .eq('user_id', user_id)
      .eq('currency', 'USDT')
      .eq('wallet_type', 'main');

    const balance = wallets?.[0]?.balance || '0';

    let emailSubject = customSubject || '';
    let emailBody = customBody || '';
    let templateName = 'Custom Email';

    if (template_id) {
      const { data: template } = await supabase
        .from('email_templates')
        .select('*')
        .eq('id', template_id)
        .eq('is_active', true)
        .single();

      if (!template) {
        throw new Error('Template not found or inactive');
      }

      emailSubject = template.subject;
      emailBody = template.body;
      templateName = template.name;
    }

    const fullName = userProfile?.full_name || 'Valued Customer';
    const firstName = fullName.split(' ')[0] || 'User';

    const variables: Record<string, string> = {
      '{{username}}': userProfile?.username || 'User',
      '{{Username}}': userProfile?.username || 'User',
      '{{email}}': userAuthData.user.email,
      '{{Email}}': userAuthData.user.email,
      '{{full_name}}': fullName,
      '{{Full Name}}': fullName,
      '{{first_name}}': firstName,
      '{{First Name}}': firstName,
      '{{kyc_level}}': userProfile?.kyc_level?.toString() || '0',
      '{{KYC Level}}': userProfile?.kyc_level?.toString() || '0',
      '{{kyc_status}}': userProfile?.kyc_status || 'unverified',
      '{{KYC Status}}': userProfile?.kyc_status || 'unverified',
      '{{balance}}': balance,
      '{{Balance}}': balance,
      '{{platform_name}}': 'Shark Trades',
      '{{Platform Name}}': 'Shark Trades',
      '{{support_email}}': 'support@shark-trades.com',
      '{{Support Email}}': 'support@shark-trades.com',
      '{{website_url}}': 'https://shark-trades.com',
      '{{Website URL}}': 'https://shark-trades.com',
      ...custom_variables,
    };

    Object.entries(variables).forEach(([key, value]) => {
      const regex = new RegExp(key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
      emailSubject = emailSubject.replace(regex, value);
      emailBody = emailBody.replace(regex, value);
    });

    await sendSmtpEmail(userAuthData.user.email, emailSubject, emailBody);

    const { data: logData } = await supabase
      .from('email_logs')
      .insert({
        user_id: user_id,
        template_id: template_id || null,
        template_name: templateName,
        subject: emailSubject,
        body: emailBody,
        status: 'sent',
        sent_by: adminUser.id,
        sent_at: new Date().toISOString(),
      })
      .select()
      .single();

    await supabase.rpc('send_notification', {
      p_user_id: user_id,
      p_type: 'system',
      p_title: 'Email Sent',
      p_message: `You have received an email: ${emailSubject}`,
      p_data: { email_log_id: logData?.id },
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email sent successfully',
        log_id: logData?.id,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    console.error('Error sending email:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});

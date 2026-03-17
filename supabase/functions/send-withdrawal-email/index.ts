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

interface WithdrawalEmailRequest {
  user_id: string;
  amount: string;
  fee: string;
  net_amount: string;
  currency: string;
  network: string;
  wallet_address: string;
  tx_hash: string;
  email_override?: string;
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

function getExplorerUrl(network: string, txHash: string): string {
  const networkLower = network.toLowerCase();
  
  if (networkLower.includes('trc20') || networkLower.includes('tron')) {
    return `https://tronscan.org/#/transaction/${txHash}`;
  } else if (networkLower.includes('erc20') || networkLower.includes('ethereum') || networkLower.includes('eth')) {
    return `https://etherscan.io/tx/${txHash}`;
  } else if (networkLower.includes('bep20') || networkLower.includes('bsc') || networkLower.includes('binance')) {
    return `https://bscscan.com/tx/${txHash}`;
  } else if (networkLower.includes('polygon') || networkLower.includes('matic')) {
    return `https://polygonscan.com/tx/${txHash}`;
  } else if (networkLower.includes('solana') || networkLower.includes('sol')) {
    return `https://solscan.io/tx/${txHash}`;
  } else if (networkLower.includes('bitcoin') || networkLower.includes('btc')) {
    return `https://blockchair.com/bitcoin/transaction/${txHash}`;
  } else if (networkLower.includes('litecoin') || networkLower.includes('ltc')) {
    return `https://blockchair.com/litecoin/transaction/${txHash}`;
  }
  
  return `https://tronscan.org/#/transaction/${txHash}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const requestData: WithdrawalEmailRequest = await req.json();
    const { user_id, amount, fee, net_amount, currency, network, wallet_address, tx_hash, email_override } = requestData;

    if (!user_id || !amount || !currency || !wallet_address || !tx_hash) {
      throw new Error('Missing required fields: user_id, amount, currency, wallet_address, tx_hash');
    }

    const { data: userAuthData } = await supabase.auth.admin.getUserById(user_id);
    if (!userAuthData?.user?.email) {
      throw new Error('User email not found');
    }

    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('username, full_name')
      .eq('id', user_id)
      .single();

    const { data: template } = await supabase
      .from('email_templates')
      .select('*')
      .eq('name', 'Withdrawal Completed')
      .eq('is_active', true)
      .single();

    if (!template) {
      throw new Error('Withdrawal email template not found');
    }

    const explorerUrl = getExplorerUrl(network || 'TRC20', tx_hash);
    
    const variables: Record<string, string> = {
      '{{username}}': userProfile?.username || 'Trader',
      '{{full_name}}': userProfile?.full_name || 'Valued Customer',
      '{{amount}}': amount,
      '{{fee}}': fee || '0',
      '{{net_amount}}': net_amount || amount,
      '{{currency}}': currency,
      '{{network}}': network || 'TRC20',
      '{{wallet_address}}': wallet_address,
      '{{tx_hash}}': tx_hash,
      '{{explorer_url}}': explorerUrl,
    };

    let emailSubject = template.subject;
    let emailBody = template.body;

    Object.entries(variables).forEach(([key, value]) => {
      const regex = new RegExp(key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
      emailSubject = emailSubject.replace(regex, value);
      emailBody = emailBody.replace(regex, value);
    });

    const recipientEmail = email_override || userAuthData.user.email;

    const client = new SmtpClient();
    try {
      await client.connect();
      await client.initializeSsl();
      await client.authenticate();
      await client.sendEmail(recipientEmail, emailSubject, emailBody);
    } finally {
      await client.close();
    }

    await supabase.from('email_logs').insert({
      user_id: user_id,
      template_id: template.id,
      template_name: template.name,
      subject: emailSubject,
      body: emailBody,
      status: 'sent',
      sent_at: new Date().toISOString(),
    });

    console.log(`Withdrawal email sent to ${recipientEmail} for ${net_amount} ${currency}`);

    return new Response(
      JSON.stringify({ success: true, message: 'Withdrawal email sent successfully' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('Error sending withdrawal email:', error);

    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

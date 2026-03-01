const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const welcomeEmail = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0a0f1c; font-family: Arial, sans-serif;">
  <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
    <div style="text-align: center; margin-bottom: 40px;">
      <h1 style="color: #00d4aa; font-size: 32px; margin: 0;">Shark Trades</h1>
    </div>
    <div style="background: #1a2332; border-radius: 16px; padding: 40px; border: 1px solid #1e293b;">
      <h2 style="color: #ffffff; font-size: 24px; margin: 0 0 20px;">Welcome to Shark Trades!</h2>
      <p style="color: #cbd5e1; font-size: 15px; line-height: 1.6;">Hello TestUser, your account has been created successfully!</p>
      <div style="text-align: center; margin: 30px 0;">
        <a href="https://shark-trades.com" style="display: inline-block; background: #00d4aa; color: #000; padding: 14px 32px; border-radius: 8px; font-weight: bold; text-decoration: none;">Start Trading</a>
      </div>
    </div>
  </div>
</body>
</html>`;

async function sendViaResend(to: string, subject: string, html: string): Promise<{ success: boolean; error?: string; data?: any }> {
  const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') || 're_YourKeyHere';

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Shark Trades <onboarding@resend.dev>',
        to: [to],
        subject: subject,
        html: html,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return { success: false, error: JSON.stringify(data), data };
    }

    return { success: true, data };
  } catch (e: any) {
    return { success: false, error: e.message };
  }
}

async function sendViaHostingerSMTP(to: string, subject: string, html: string): Promise<{ success: boolean; error?: string; details?: string }> {
  const SMTP_HOST = 'smtp.hostinger.com';
  const SMTP_PORT = 465;
  const SMTP_USER = 'support@shark-trades.com';
  const SMTP_PASS = '9$4.h3b5}Zz.';

  const logs: string[] = [];

  try {
    logs.push('Connecting to ' + SMTP_HOST + ':' + SMTP_PORT);

    const conn = await Deno.connectTls({
      hostname: SMTP_HOST,
      port: SMTP_PORT,
    });

    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    const read = async (): Promise<string> => {
      const buf = new Uint8Array(4096);
      let result = '';
      const timeout = Date.now() + 5000;
      while (Date.now() < timeout) {
        const n = await conn.read(buf);
        if (!n) break;
        result += decoder.decode(buf.subarray(0, n));
        if (result.includes('\r\n')) {
          const lines = result.trim().split('\r\n');
          const last = lines[lines.length - 1];
          if (last.length >= 3 && last.charAt(3) !== '-') break;
        }
        await new Promise(r => setTimeout(r, 50));
      }
      return result.trim();
    };

    const send = async (cmd: string): Promise<string> => {
      const safeCmd = cmd.includes('AUTH') || cmd.length > 100 ? cmd.substring(0, 30) + '...' : cmd;
      logs.push('> ' + safeCmd);
      await conn.write(encoder.encode(cmd + '\r\n'));
      await new Promise(r => setTimeout(r, 150));
      const resp = await read();
      logs.push('< ' + resp.substring(0, 100));
      return resp;
    };

    const greeting = await read();
    logs.push('Greeting: ' + greeting.substring(0, 50));

    const ehlo = await send('EHLO shark-trades.com');

    const auth = await send('AUTH LOGIN');
    if (!auth.startsWith('334')) {
      return { success: false, error: 'AUTH rejected', details: logs.join('\n') };
    }

    const user = await send(btoa(SMTP_USER));
    if (!user.startsWith('334')) {
      return { success: false, error: 'Username rejected', details: logs.join('\n') };
    }

    const pass = await send(btoa(SMTP_PASS));
    if (!pass.startsWith('235')) {
      return { success: false, error: 'Password rejected: ' + pass, details: logs.join('\n') };
    }

    logs.push('Authenticated successfully');

    const mailFrom = await send(`MAIL FROM:<${SMTP_USER}>`);
    if (!mailFrom.startsWith('250')) {
      return { success: false, error: 'MAIL FROM rejected', details: logs.join('\n') };
    }

    const rcptTo = await send(`RCPT TO:<${to}>`);
    if (!rcptTo.startsWith('250')) {
      return { success: false, error: 'RCPT TO rejected: ' + rcptTo, details: logs.join('\n') };
    }

    const data = await send('DATA');
    if (!data.startsWith('354')) {
      return { success: false, error: 'DATA rejected', details: logs.join('\n') };
    }

    const boundary = '----=_Part_' + Date.now();
    const plain = html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();

    const message = [
      `From: Shark Trades <${SMTP_USER}>`,
      `To: ${to}`,
      `Subject: ${subject}`,
      `Date: ${new Date().toUTCString()}`,
      `Message-ID: <${Date.now()}.${Math.random().toString(36)}@shark-trades.com>`,
      'MIME-Version: 1.0',
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
      '',
      `--${boundary}`,
      'Content-Type: text/plain; charset="UTF-8"',
      'Content-Transfer-Encoding: quoted-printable',
      '',
      plain,
      '',
      `--${boundary}`,
      'Content-Type: text/html; charset="UTF-8"',
      'Content-Transfer-Encoding: quoted-printable',
      '',
      html,
      '',
      `--${boundary}--`,
    ].join('\r\n');

    logs.push('Sending message body...');
    await conn.write(encoder.encode(message + '\r\n.\r\n'));
    await new Promise(r => setTimeout(r, 500));
    const endRes = await read();
    logs.push('End response: ' + endRes);

    if (!endRes.startsWith('250')) {
      return { success: false, error: 'Message rejected: ' + endRes, details: logs.join('\n') };
    }

    await send('QUIT');
    conn.close();

    logs.push('Email sent successfully!');
    return { success: true, details: logs.join('\n') };
  } catch (e: any) {
    logs.push('Error: ' + e.message);
    return { success: false, error: e.message, details: logs.join('\n') };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { email } = await req.json();
    if (!email) throw new Error('Email required');

    console.log('Attempting to send email to:', email);

    const result = await sendViaHostingerSMTP(
      email,
      'Welcome to Shark Trades - Your Account is Ready!',
      welcomeEmail
    );

    console.log('Result:', JSON.stringify(result, null, 2));

    return new Response(
      JSON.stringify(result),
      {
        status: result.success ? 200 : 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  } catch (error: any) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

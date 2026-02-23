import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface TransferRequest {
  recipient_identifier: string;
  amount: number;
  currency: string;
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

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { recipient_identifier, amount, currency }: TransferRequest = await req.json();

    if (!recipient_identifier || !amount || amount <= 0 || !currency) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid request parameters' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const identifier = recipient_identifier.trim().toLowerCase();

    let recipientId: string | null = null;
    let recipientName: string | null = null;
    let recipientEmail: string | null = null;

    // First try to find by email in auth.users
    const { data: { users }, error: usersError } = await supabase.auth.admin.listUsers();

    if (!usersError && users) {
      const userByEmail = users.find(u => u.email?.toLowerCase() === identifier);
      if (userByEmail) {
        recipientId = userByEmail.id;
        recipientEmail = userByEmail.email || '';

        // Get username from profile
        const { data: profile } = await supabase
          .from('user_profiles')
          .select('username, full_name')
          .eq('id', recipientId)
          .maybeSingle();

        recipientName = profile?.username || profile?.full_name || recipientEmail;
      }
    }

    // If not found by email, try by username
    if (!recipientId) {
      const { data: profileByUsername } = await supabase
        .from('user_profiles')
        .select('id, username, full_name')
        .eq('username', identifier)
        .maybeSingle();

      if (profileByUsername) {
        recipientId = profileByUsername.id;
        recipientName = profileByUsername.username || profileByUsername.full_name;
      }
    }

    if (!recipientId) {
      return new Response(
        JSON.stringify({ success: false, error: 'Recipient not found. Please check the email or username.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (recipientId === user.id) {
      return new Response(
        JSON.stringify({ success: false, error: 'You cannot transfer to yourself' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { data: senderWallet, error: senderWalletError } = await supabase
      .from('wallets')
      .select('balance')
      .eq('user_id', user.id)
      .eq('currency', currency)
      .eq('wallet_type', 'main')
      .maybeSingle();

    if (senderWalletError || !senderWallet) {
      return new Response(
        JSON.stringify({ success: false, error: 'Sender wallet not found' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const senderBalance = parseFloat(senderWallet.balance);
    if (senderBalance < amount) {
      return new Response(
        JSON.stringify({ success: false, error: 'Insufficient balance' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { error: deductError } = await supabase
      .from('wallets')
      .update({ balance: (senderBalance - amount).toString() })
      .eq('user_id', user.id)
      .eq('currency', currency)
      .eq('wallet_type', 'main');

    if (deductError) {
      throw new Error('Failed to deduct from sender wallet');
    }

    const { data: recipientWallet } = await supabase
      .from('wallets')
      .select('balance')
      .eq('user_id', recipientId)
      .eq('currency', currency)
      .eq('wallet_type', 'main')
      .maybeSingle();

    if (recipientWallet) {
      const recipientBalance = parseFloat(recipientWallet.balance);
      await supabase
        .from('wallets')
        .update({ balance: (recipientBalance + amount).toString() })
        .eq('user_id', recipientId)
        .eq('currency', currency)
        .eq('wallet_type', 'main');
    } else {
      await supabase
        .from('wallets')
        .insert({
          user_id: recipientId,
          currency: currency,
          wallet_type: 'main',
          balance: amount.toString(),
          locked_balance: '0'
        });
    }

    await supabase.from('transactions').insert([
      {
        user_id: user.id,
        transaction_type: 'transfer_out',
        currency: currency,
        amount: (-amount).toString(),
        status: 'completed',
        created_at: new Date().toISOString()
      },
      {
        user_id: recipientId,
        transaction_type: 'transfer_in',
        currency: currency,
        amount: amount.toString(),
        status: 'completed',
        created_at: new Date().toISOString()
      }
    ]);

    return new Response(
      JSON.stringify({
        success: true,
        amount: amount,
        currency: currency,
        recipient_name: recipientName
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('Transfer error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
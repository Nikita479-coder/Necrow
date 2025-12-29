import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function findAllPendingWithdrawals() {
  console.log('Searching for ALL pending withdrawals...');
  console.log('');

  try {
    // Get all pending withdrawals
    const { data: withdrawals, error } = await supabase
      .from('transactions')
      .select('*')
      .eq('transaction_type', 'withdrawal')
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error:', error);
      process.exit(1);
    }

    if (!withdrawals || withdrawals.length === 0) {
      console.log('No pending withdrawals found.');
      process.exit(1);
    }

    console.log(`Found ${withdrawals.length} pending withdrawal(s):`);
    console.log('');

    for (const w of withdrawals) {
      // Get user info
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('full_name, username, email')
        .eq('id', w.user_id)
        .single();

      console.log('---');
      console.log('Transaction ID:', w.id);
      console.log('Username:', profile?.username || 'N/A');
      console.log('Email:', profile?.email || 'N/A');
      console.log('Full Name:', profile?.full_name || 'N/A');
      console.log('Amount:', w.amount, w.currency);
      console.log('Fee:', w.fee || 0);
      console.log('Status:', w.status);
      console.log('Network:', w.network || 'N/A');
      console.log('Address:', w.address?.substring(0, 20) + '...' || 'N/A');
      console.log('Created:', new Date(w.created_at).toLocaleString());
      console.log('');

      // Check if this matches the A112SH withdrawal
      if (w.currency === 'USDT' && w.amount === 50 && (w.fee === 1 || w.fee === 0)) {
        console.log('>>> THIS MATCHES THE A112SH WITHDRAWAL <<<');
        console.log('To complete: node complete-by-id.js', w.id);
        console.log('');
      }
    }
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

findAllPendingWithdrawals();

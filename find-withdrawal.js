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

async function findWithdrawal() {
  console.log('Searching for pending withdrawals...');
  console.log('');

  try {
    // Find all pending withdrawals for USDT
    const { data: withdrawals, error } = await supabase
      .from('transactions')
      .select('*')
      .eq('transaction_type', 'withdrawal')
      .eq('currency', 'USDT')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(20);

    if (error) {
      console.error('Error:', error);
      process.exit(1);
    }

    if (!withdrawals || withdrawals.length === 0) {
      console.log('No pending USDT withdrawals found.');

      // Check all recent withdrawals
      console.log('');
      console.log('Checking recent withdrawals (all statuses)...');
      const { data: allWithdrawals } = await supabase
        .from('transactions')
        .select('*')
        .eq('transaction_type', 'withdrawal')
        .eq('currency', 'USDT')
        .order('created_at', { ascending: false })
        .limit(10);

      if (allWithdrawals && allWithdrawals.length > 0) {
        console.log('');
        console.log('Recent USDT withdrawals:');
        for (const w of allWithdrawals) {
          // Get user info
          const { data: profile } = await supabase
            .from('user_profiles')
            .select('full_name, username')
            .eq('id', w.user_id)
            .single();

          console.log('---');
          console.log('ID:', w.id);
          console.log('User:', profile?.full_name || profile?.username || w.user_id);
          console.log('Amount:', w.amount, w.currency);
          console.log('Fee:', w.fee || 0);
          console.log('Status:', w.status);
          console.log('Created:', new Date(w.created_at).toLocaleString());
        }
      }
      process.exit(0);
    }

    console.log(`Found ${withdrawals.length} pending USDT withdrawal(s):`);
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
      console.log('User:', profile?.full_name || profile?.username || 'Unknown');
      console.log('Username:', profile?.username || 'N/A');
      console.log('Email:', profile?.email || 'N/A');
      console.log('Amount:', w.amount, w.currency);
      console.log('Fee:', w.fee || 0);
      console.log('Receive Amount:', w.receive_amount || (w.amount - (w.fee || 0)));
      console.log('Status:', w.status);
      console.log('Address:', w.address || 'N/A');
      console.log('Network:', w.network || 'N/A');
      console.log('Created:', new Date(w.created_at).toLocaleString());
      console.log('');
    }

    // If we found exactly one pending withdrawal around 50 USDT, show completion command
    const matching = withdrawals.find(w => Math.abs(w.amount - 50) < 5);
    if (matching) {
      console.log('');
      console.log('To complete this withdrawal, use:');
      console.log(`node complete-withdrawal-by-id.js ${matching.id}`);
    }
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

findWithdrawal();

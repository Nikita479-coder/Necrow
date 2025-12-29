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

const userEmail = 'a112sh001@gmail.com';
const amount = 50;
const currency = 'USDT';

async function completeWithdrawal() {
  console.log('Finding withdrawal for:', userEmail);
  console.log('Amount:', amount, currency);
  console.log('');

  try {
    // Find the user
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('id, full_name')
      .ilike('email', userEmail)
      .single();

    if (!profile) {
      console.error('User not found:', userEmail);
      process.exit(1);
    }

    console.log('Found user:', profile.full_name);
    console.log('User ID:', profile.id);
    console.log('');

    // Find the pending withdrawal
    const { data: withdrawals, error: withdrawalError } = await supabase
      .from('transactions')
      .select('*')
      .eq('user_id', profile.id)
      .eq('transaction_type', 'withdrawal')
      .eq('currency', currency)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    if (withdrawalError) {
      console.error('Error finding withdrawal:', withdrawalError);
      process.exit(1);
    }

    if (!withdrawals || withdrawals.length === 0) {
      console.error('No pending withdrawal found for this user');
      console.log('');
      console.log('Checking all withdrawals for this user...');

      const { data: allWithdrawals } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', profile.id)
        .eq('transaction_type', 'withdrawal')
        .order('created_at', { ascending: false })
        .limit(5);

      if (allWithdrawals && allWithdrawals.length > 0) {
        console.log('Recent withdrawals:');
        allWithdrawals.forEach((w, i) => {
          console.log(`${i + 1}. ${w.amount} ${w.currency} - Status: ${w.status} - Date: ${w.created_at}`);
        });
      }

      process.exit(1);
    }

    // Find the matching withdrawal
    const withdrawal = withdrawals.find(w => Math.abs(w.amount - amount) < 0.01);

    if (!withdrawal) {
      console.log('Pending withdrawals found:');
      withdrawals.forEach((w, i) => {
        console.log(`${i + 1}. ${w.amount} ${w.currency} - Status: ${w.status} - Fee: ${w.fee || 0} - Date: ${w.created_at}`);
      });
      console.error('');
      console.error('No matching withdrawal found for amount:', amount);
      process.exit(1);
    }

    console.log('Found withdrawal:');
    console.log('  ID:', withdrawal.id);
    console.log('  Amount:', withdrawal.amount, withdrawal.currency);
    console.log('  Fee:', withdrawal.fee || 0);
    console.log('  Status:', withdrawal.status);
    console.log('  Address:', withdrawal.address || 'N/A');
    console.log('  Network:', withdrawal.network || 'N/A');
    console.log('  Created:', withdrawal.created_at);
    console.log('');

    // Mark as completed
    console.log('Marking withdrawal as completed...');

    const { data: result, error: processError } = await supabase.rpc('admin_process_withdrawal', {
      p_transaction_id: withdrawal.id,
      p_action: 'complete',
      p_tx_hash: withdrawal.tx_hash || 'Manual_Completion_' + Date.now(),
      p_admin_notes: 'Withdrawal processed and sent to user wallet'
    });

    if (processError) {
      console.error('Error processing withdrawal:', processError);
      process.exit(1);
    }

    if (result?.success) {
      console.log('✅ Withdrawal completed successfully!');
      console.log('   New status:', result.new_status);
      console.log('   Message:', result.message);
      console.log('');
      console.log('User has been notified of the completed withdrawal.');
    } else {
      console.error('❌ Failed to complete withdrawal:', result?.error);
      process.exit(1);
    }
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

completeWithdrawal();

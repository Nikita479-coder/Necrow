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

async function findDeposits() {
  console.log('Searching for pending crypto deposits...');
  console.log('');

  try {
    // Find pending crypto deposits
    const { data: deposits, error } = await supabase
      .from('crypto_deposits')
      .select('*')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(20);

    if (error) {
      console.error('Error:', error);
      process.exit(1);
    }

    if (!deposits || deposits.length === 0) {
      console.log('No pending crypto deposits found.');

      // Check all recent deposits
      console.log('');
      console.log('Checking recent deposits (all statuses)...');
      const { data: allDeposits } = await supabase
        .from('crypto_deposits')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(10);

      if (allDeposits && allDeposits.length > 0) {
        console.log('');
        console.log('Recent crypto deposits:');
        for (const d of allDeposits) {
          const { data: profile } = await supabase
            .from('user_profiles')
            .select('full_name, username, email')
            .eq('id', d.user_id)
            .single();

          console.log('---');
          console.log('ID:', d.id);
          console.log('User:', profile?.username || profile?.full_name || 'Unknown');
          console.log('Email:', profile?.email || 'N/A');
          console.log('Amount:', d.pay_amount, d.pay_currency);
          console.log('Receive:', d.price_amount, d.price_currency);
          console.log('Status:', d.payment_status);
          console.log('Network:', d.network || 'N/A');
          console.log('Address:', d.pay_address?.substring(0, 15) + '...' || 'N/A');
          console.log('Created:', new Date(d.created_at).toLocaleString());
        }
      }
      process.exit(0);
    }

    console.log(`Found ${deposits.length} pending crypto deposit(s):`);
    console.log('');

    for (const d of deposits) {
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('full_name, username, email')
        .eq('id', d.user_id)
        .single();

      console.log('---');
      console.log('Deposit ID:', d.id);
      console.log('User:', profile?.username || profile?.full_name || 'Unknown');
      console.log('Email:', profile?.email || 'N/A');
      console.log('Pay Amount:', d.pay_amount, d.pay_currency);
      console.log('Receive Amount:', d.price_amount, d.price_currency);
      console.log('Status:', d.payment_status);
      console.log('Network:', d.network || 'N/A');
      console.log('Address:', d.pay_address?.substring(0, 20) + '...' || 'N/A');
      console.log('Created:', new Date(d.created_at).toLocaleString());
      console.log('');
    }
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

findDeposits();

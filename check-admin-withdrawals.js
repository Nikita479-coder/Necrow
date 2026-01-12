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

async function checkAdminWithdrawals() {
  console.log('Calling admin_get_all_withdrawals RPC function...');
  console.log('');

  try {
    // Call the same RPC function that the admin panel uses
    const { data, error } = await supabase.rpc('admin_get_all_withdrawals', {
      p_status: 'pending',
      p_limit: 100,
      p_offset: 0
    });

    if (error) {
      console.error('RPC Error:', error);
      process.exit(1);
    }

    console.log('RPC Response:', JSON.stringify(data, null, 2));
    console.log('');

    if (data?.success && data?.withdrawals) {
      const withdrawals = data.withdrawals;
      console.log(`Found ${withdrawals.length} pending withdrawal(s):`);
      console.log('');

      withdrawals.forEach((w, i) => {
        console.log(`${i + 1}. ${w.username || w.email} - ${w.amount} ${w.currency} - ${w.status}`);
        console.log('   ID:', w.id);
        console.log('   Email:', w.email);
        console.log('   Network:', w.network);
        console.log('   Address:', w.address?.substring(0, 20) + '...');
        console.log('   Created:', w.created_at);
        console.log('');

        // Check if this matches A112SH
        if (w.currency === 'USDT' && w.amount === 50) {
          console.log('>>> MATCHES A112SH WITHDRAWAL <<<');
          console.log('>>> Transaction ID:', w.id);
          console.log('');
        }
      });
    } else {
      console.log('No withdrawals found or unexpected response format');
    }
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkAdminWithdrawals();

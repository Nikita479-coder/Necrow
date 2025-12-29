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

async function findUser() {
  console.log('Searching for user A112SH / a112sh001@gmail.com...');
  console.log('');

  try {
    // Search by username
    const { data: byUsername } = await supabase
      .from('user_profiles')
      .select('*')
      .ilike('username', '%a112sh%')
      .limit(10);

    // Search by full name
    const { data: byName } = await supabase
      .from('user_profiles')
      .select('*')
      .ilike('full_name', '%a112sh%')
      .limit(10);

    // Search by email pattern
    const { data: byEmail } = await supabase
      .from('user_profiles')
      .select('*')
      .ilike('email', '%a112sh%')
      .limit(10);

    const allResults = [...(byUsername || []), ...(byName || []), ...(byEmail || [])];
    const uniqueResults = Array.from(new Map(allResults.map(u => [u.id, u])).values());

    if (uniqueResults.length === 0) {
      console.log('❌ No users found matching "a112sh"');
      console.log('');
      console.log('Checking recent users...');

      const { data: recentUsers } = await supabase
        .from('user_profiles')
        .select('id, username, full_name, email, created_at')
        .order('created_at', { ascending: false })
        .limit(10);

      if (recentUsers) {
        console.log('');
        console.log('Recent users:');
        recentUsers.forEach((u, i) => {
          console.log(`${i + 1}. ${u.username || 'N/A'} - ${u.full_name || 'N/A'} - ${u.email || 'N/A'}`);
        });
      }
      process.exit(1);
    }

    console.log(`Found ${uniqueResults.length} matching user(s):`);
    console.log('');

    for (const user of uniqueResults) {
      console.log('---');
      console.log('User ID:', user.id);
      console.log('Username:', user.username || 'N/A');
      console.log('Full Name:', user.full_name || 'N/A');
      console.log('Email:', user.email || 'N/A');
      console.log('KYC Status:', user.kyc_status);
      console.log('Created:', new Date(user.created_at).toLocaleString());
      console.log('');

      // Check for withdrawals
      const { data: withdrawals } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', user.id)
        .eq('transaction_type', 'withdrawal')
        .order('created_at', { ascending: false })
        .limit(5);

      if (withdrawals && withdrawals.length > 0) {
        console.log('Recent withdrawals:');
        withdrawals.forEach((w, i) => {
          console.log(`  ${i + 1}. ${w.amount} ${w.currency} - ${w.status} - ${new Date(w.created_at).toLocaleString()}`);
        });
        console.log('');
      }
    }
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

findUser();

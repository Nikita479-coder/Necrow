const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseServiceKey) {
  console.log('No service role key found in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

(async () => {
  try {
    console.log('Checking with service role key (bypassing RLS)...\n');

    // Check exclusive_affiliates
    const { data: affiliates, error: affError } = await supabase
      .from('exclusive_affiliates')
      .select('*');

    if (affError) {
      console.log('Error fetching affiliates:', affError.message);
    } else {
      console.log('Exclusive affiliates:', affiliates?.length || 0);
      if (affiliates && affiliates.length > 0) {
        affiliates.forEach(a => {
          console.log('  -', a.user_id, 'created:', a.created_at);
        });
      }
    }

    // Check network stats
    const { data: stats, error: statsError } = await supabase
      .from('exclusive_affiliate_network_stats')
      .select('*');

    if (statsError) {
      console.log('\nError fetching stats:', statsError.message);
    } else {
      console.log('\nNetwork stats:', stats?.length || 0);
      if (stats && stats.length > 0) {
        stats.forEach(s => {
          const total = (s.level_1_count || 0) + (s.level_2_count || 0) +
                       (s.level_3_count || 0) + (s.level_4_count || 0) +
                       (s.level_5_count || 0) + (s.level_6_count || 0) +
                       (s.level_7_count || 0) + (s.level_8_count || 0) +
                       (s.level_9_count || 0) + (s.level_10_count || 0);
          console.log('  - Affiliate:', s.affiliate_id);
          console.log('    Total network:', total);
        });
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
})();

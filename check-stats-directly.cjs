const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

(async () => {
  try {
    console.log('Checking network stats table directly...\n');

    // Check network stats
    const { data: stats, error: statsError } = await supabase
      .from('exclusive_affiliate_network_stats')
      .select('*');

    if (statsError) {
      console.log('Error:', statsError.message);
      return;
    }

    console.log('Network stats records:', stats?.length || 0);

    if (stats && stats.length > 0) {
      stats.forEach(s => {
        const total = (s.level_1_count || 0) + (s.level_2_count || 0) +
                     (s.level_3_count || 0) + (s.level_4_count || 0) +
                     (s.level_5_count || 0) + (s.level_6_count || 0) +
                     (s.level_7_count || 0) + (s.level_8_count || 0) +
                     (s.level_9_count || 0) + (s.level_10_count || 0);
        console.log('\nAffiliate ID:', s.affiliate_id);
        console.log('  Total network:', total);
        console.log('  By level:', {
          L1: s.level_1_count,
          L2: s.level_2_count,
          L3: s.level_3_count,
          L4: s.level_4_count,
          L5: s.level_5_count
        });
      });
    }

    // Now check the actual exclusive_affiliates table
    console.log('\n\nChecking exclusive_affiliates table...\n');
    const { data: affiliates, error: affError } = await supabase
      .from('exclusive_affiliates')
      .select('*');

    if (affError) {
      console.log('Error:', affError.message);
    } else {
      console.log('Exclusive affiliates records:', affiliates?.length || 0);
      if (affiliates && affiliates.length > 0) {
        affiliates.forEach(a => {
          console.log('  User ID:', a.user_id);
          console.log('  Created:', a.created_at);
        });
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
})();

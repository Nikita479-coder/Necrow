const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

(async () => {
  try {
    console.log('Testing a112sh referral network...\n');

    // Get a112sh's user_id from exclusive_affiliates
    const { data: affiliates, error: affError } = await supabase
      .from('exclusive_affiliates')
      .select('user_id, created_at');

    if (affError) {
      console.log('Error:', affError.message);
      return;
    }

    console.log('Found', affiliates?.length || 0, 'exclusive affiliates');

    for (const aff of affiliates || []) {
      console.log('\n=== Testing affiliate:', aff.user_id, '===');

      // Get network stats
      const { data: stats, error: statsError } = await supabase
        .from('exclusive_affiliate_network_stats')
        .select('*')
        .eq('affiliate_id', aff.user_id)
        .maybeSingle();

      if (stats) {
        const total = (stats.level_1_count || 0) + (stats.level_2_count || 0) +
                     (stats.level_3_count || 0) + (stats.level_4_count || 0) +
                     (stats.level_5_count || 0) + (stats.level_6_count || 0) +
                     (stats.level_7_count || 0) + (stats.level_8_count || 0) +
                     (stats.level_9_count || 0) + (stats.level_10_count || 0);
        console.log('Network size from stats:', total);
      }

      // Call the function
      const { data: referrals, error: rpcError } = await supabase
        .rpc('get_exclusive_affiliate_referrals', {
          p_affiliate_id: aff.user_id
        });

      if (rpcError) {
        console.log('Error calling function:', rpcError.message);
      } else {
        console.log('Referrals returned from function:', referrals?.length || 0);

        if (referrals && referrals.length > 0) {
          // Count by level
          const byLevel = {};
          referrals.forEach(r => {
            byLevel[r.level] = (byLevel[r.level] || 0) + 1;
          });

          console.log('Breakdown by level:');
          Object.keys(byLevel).sort().forEach(level => {
            console.log(`  Level ${level}: ${byLevel[level]} referrals`);
          });

          console.log('\nSample referrals:');
          referrals.slice(0, 5).forEach(r => {
            console.log(`  - ${r.full_name || r.username} (Level ${r.level}, Eligible: ${r.eligible})`);
          });
        } else {
          console.log('No referrals found!');
        }
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
})();

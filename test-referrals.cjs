const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

(async () => {
  try {
    console.log('Testing referral lookup...\n');

    // Get all exclusive affiliates through the stats table (which doesn't require auth)
    const { data: allStats, error: statsError } = await supabase
      .from('exclusive_affiliate_network_stats')
      .select('affiliate_id, level_1_count, level_2_count, level_3_count, level_4_count, level_5_count');

    if (statsError) {
      console.log('Error:', statsError.message);
      return;
    }

    console.log('Found', allStats?.length || 0, 'affiliates with network stats\n');

    for (const stat of allStats || []) {
      const total = (stat.level_1_count || 0) + (stat.level_2_count || 0) +
                   (stat.level_3_count || 0) + (stat.level_4_count || 0) +
                   (stat.level_5_count || 0);

      if (total > 0) {
        console.log('=== Affiliate:', stat.affiliate_id, '===');
        console.log('Network size from stats:', total);

        // Test the RPC function
        const { data: referrals, error: rpcError } = await supabase
          .rpc('get_exclusive_affiliate_referrals', {
            p_affiliate_id: stat.affiliate_id
          });

        if (rpcError) {
          console.log('RPC Error:', rpcError.message);
        } else {
          console.log('Referrals from function:', referrals?.length || 0);

          if (referrals && referrals.length > 0) {
            console.log('Sample referrals:');
            referrals.slice(0, 3).forEach(r => {
              console.log(`  - ${r.full_name || r.username} (Level ${r.level}, Eligible: ${r.eligible})`);
            });
          }
        }

        // Test debug function
        const { data: debug, error: debugError } = await supabase
          .rpc('debug_exclusive_affiliate_network', {
            p_affiliate_id: stat.affiliate_id
          });

        if (debugError) {
          console.log('Debug Error:', debugError.message);
        } else {
          console.log('Debug info:', JSON.stringify(debug, null, 2));
        }

        console.log('');
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
})();

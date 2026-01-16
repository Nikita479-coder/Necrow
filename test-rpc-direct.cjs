const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

(async () => {
  try {
    console.log('Testing RPC function directly with anon key...\n');

    // A112SH's user_id
    const a112sh_id = '51b65324-8f66-4c6c-97e5-6ab41812d062';

    // Call the function
    const { data, error } = await supabase
      .rpc('get_exclusive_affiliate_referrals', {
        p_affiliate_id: a112sh_id
      });

    if (error) {
      console.log('Error:', error.message);
      console.log('Details:', JSON.stringify(error, null, 2));
    } else {
      console.log('Success! Referrals returned:', data?.length || 0);

      if (data && data.length > 0) {
        console.log('\nFirst 5 referrals:');
        data.slice(0, 5).forEach(r => {
          console.log(`  - ${r.full_name || r.username} (Level ${r.level}, Eligible: ${r.eligible})`);
        });

        // Count by level
        const byLevel = {};
        data.forEach(r => {
          byLevel[r.level] = (byLevel[r.level] || 0) + 1;
        });

        console.log('\nBreakdown by level:');
        Object.keys(byLevel).sort((a, b) => parseInt(a) - parseInt(b)).forEach(level => {
          console.log(`  Level ${level}: ${byLevel[level]} referrals`);
        });
      }
    }

  } catch (error) {
    console.error('Exception:', error.message);
  }
})();

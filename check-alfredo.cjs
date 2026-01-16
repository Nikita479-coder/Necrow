const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

(async () => {
  try {
    console.log('Checking database users...\n');

    // Get total user count
    const { data: users, count } = await supabase
      .from('user_profiles')
      .select('id, full_name, username', { count: 'exact' })
      .limit(10);

    console.log('Total users in database:', count);
    console.log('\nFirst 10 users:');
    users?.forEach(u => {
      console.log(`  - ${u.full_name || u.username || 'No name'} (username: ${u.username || 'none'})`);
    });

    // Check exclusive affiliates
    const { data: affiliates } = await supabase
      .from('exclusive_affiliates')
      .select('user_id');

    console.log('\nTotal exclusive affiliates:', affiliates?.length || 0);

    if (!affiliates || affiliates.length === 0) {
      console.log('\nNo exclusive affiliates enrolled in this database!');
      console.log('You need to enroll users as exclusive affiliates first.');
      return;
    }

    // Check first affiliate
    const firstAff = affiliates[0];
    const { data: affProfile } = await supabase
      .from('user_profiles')
      .select('full_name, username')
      .eq('id', firstAff.user_id)
      .single();

    console.log('\nFirst exclusive affiliate:', affProfile?.full_name || affProfile?.username);

    const { data: a112sh } = await supabase
      .from('user_profiles')
      .select('id, full_name, username')
      .eq('username', 'a112sh')
      .single();

    if (!a112sh) {
      console.log('\na112sh user not found in this database');
      return;
    }

    console.log('Found:', a112sh.full_name || a112sh.username);
    console.log('User ID:', a112sh.id);

    // Check if enrolled as exclusive affiliate
    const { data: affRecord } = await supabase
      .from('exclusive_affiliates')
      .select('created_at')
      .eq('user_id', a112sh.id)
      .single();

    console.log('Enrolled as exclusive affiliate:', affRecord ? 'Yes' : 'No');
    if (affRecord) {
      console.log('Enrollment date:', new Date(affRecord.created_at).toLocaleDateString());
    }

    // Check network stats table
    const { data: stats } = await supabase
      .from('exclusive_affiliate_network_stats')
      .select('*')
      .eq('affiliate_id', a112sh.id)
      .single();

    console.log('\nNetwork Stats Table:');
    if (stats) {
      console.log('  Total Network Size:', stats.total_network_size);
      console.log('  Level 1:', stats.level_1_count);
      console.log('  Level 2:', stats.level_2_count);
      console.log('  Level 3:', stats.level_3_count);
      console.log('  Level 4:', stats.level_4_count);
      console.log('  Level 5:', stats.level_5_count);
    } else {
      console.log('  No stats found');
    }

    // Call the function to get actual referrals
    const { data: referrals, error: refError } = await supabase
      .rpc('get_exclusive_affiliate_referrals', {
        p_affiliate_id: a112sh.id
      });

    console.log('\nFunction Results:');
    if (refError) {
      console.log('  Error:', refError.message);
    } else {
      console.log('  Total returned:', referrals?.length || 0);

      // Count by level
      const byLevel = {};
      referrals?.forEach(r => {
        byLevel[r.level] = (byLevel[r.level] || 0) + 1;
      });

      console.log('\n  Breakdown by level:');
      for (let i = 1; i <= 10; i++) {
        if (byLevel[i]) {
          console.log(`    Level ${i}: ${byLevel[i]}`);
        }
      }

      // Count eligible vs not eligible
      const eligible = referrals?.filter(r => r.eligible).length || 0;
      const notEligible = referrals?.filter(r => !r.eligible).length || 0;
      console.log('\n  Eligible (after enrollment):', eligible);
      console.log('  Before enrollment:', notEligible);
    }

    return;

    console.log('Alfredo:', alfredo.full_name, '(' + alfredo.id + ')');

    // Check his direct referrals (Level 1)
    const { data: level1 } = await supabase
      .from('user_profiles')
      .select('id, full_name')
      .eq('referred_by', alfredo.id);

    console.log('\nLevel 1 (Direct):', level1?.length || 0);
    if (level1 && level1.length > 0) {
      level1.forEach(u => console.log('  -', u.full_name));

      // Check if any Level 1 referred others (Level 2)
      for (const l1User of level1) {
        const { data: level2 } = await supabase
          .from('user_profiles')
          .select('id, full_name')
          .eq('referred_by', l1User.id);

        if (level2 && level2.length > 0) {
          console.log('\n  Level 2 from', l1User.full_name + ':', level2.length);
          level2.forEach(u => console.log('    -', u.full_name));
        }
      }
    }

    console.log('\n---\n');

    // Find Ioana
    const { data: ioana } = await supabase
      .from('user_profiles')
      .select('id, full_name')
      .ilike('full_name', '%ioana%')
      .single();

    if (!ioana) {
      console.log('Ioana not found');
      return;
    }

    console.log('Ioana:', ioana.full_name, '(' + ioana.id + ')');

    // Check her direct referrals (Level 1)
    const { data: ioanaLevel1 } = await supabase
      .from('user_profiles')
      .select('id, full_name')
      .eq('referred_by', ioana.id);

    console.log('\nLevel 1 (Direct):', ioanaLevel1?.length || 0);
    if (ioanaLevel1 && ioanaLevel1.length > 0) {
      ioanaLevel1.forEach(u => console.log('  -', u.full_name));

      // Check if any Level 1 referred others (Level 2)
      for (const l1User of ioanaLevel1) {
        const { data: level2 } = await supabase
          .from('user_profiles')
          .select('id, full_name')
          .eq('referred_by', l1User.id);

        if (level2 && level2.length > 0) {
          console.log('\n  Level 2 from', l1User.full_name + ':', level2.length);
          level2.forEach(u => console.log('    -', u.full_name));
        }
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
})();

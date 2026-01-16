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
    console.log('Checking referral chain depth...\n');

    // Find Alfredo
    const { data: alfredo } = await supabase
      .from('user_profiles')
      .select('id, full_name')
      .ilike('full_name', '%alfredo%')
      .single();

    if (!alfredo) {
      console.log('Alfredo not found');
      return;
    }

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
    console.error('Error:', error);
  }
})();

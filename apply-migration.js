import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

const migrationSQL = readFileSync('./supabase/migrations/20251210161645_fix_admin_issue_shark_card_notification_column.sql', 'utf8');

async function applyMigration() {
  try {
    // Split the SQL into statements and execute them
    const statements = migrationSQL
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('/*'));

    console.log('Applying migration...');

    for (const statement of statements) {
      if (statement.trim()) {
        const { data, error } = await supabase.rpc('exec_sql', {
          query: statement + ';'
        });

        if (error) {
          console.error('Error executing statement:', error);
          console.error('Statement:', statement);
        } else {
          console.log('Statement executed successfully');
        }
      }
    }

    console.log('Migration applied successfully!');
  } catch (error) {
    console.error('Error applying migration:', error);
  }
}

applyMigration();

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

const TEST_PAIRS = ['BTCUSDT', 'FLOWUSDT', 'GMTUSDT', 'ARUSDT'];

async function verifyLiquidations() {
  console.log('='.repeat(80));
  console.log('LIQUIDATION VERIFICATION REPORT');
  console.log('='.repeat(80));
  console.log('');
  console.log(`Checking liquidations for pairs: ${TEST_PAIRS.join(', ')}`);
  console.log('');

  const allUserIds = new Set();

  try {
    // 1. Check Liquidation Events
    console.log('━'.repeat(80));
    console.log('1. LIQUIDATION EVENTS');
    console.log('━'.repeat(80));
    console.log('');

    const { data: liquidations, error: liqError } = await supabase
      .from('liquidation_events')
      .select('*')
      .in('pair', TEST_PAIRS)
      .order('created_at', { ascending: false });

    if (liqError) {
      console.error('❌ Error fetching liquidation events:', liqError.message);
    } else if (!liquidations || liquidations.length === 0) {
      console.log('⚠️  No liquidation events found for these pairs');
    } else {
      console.log(`✅ Found ${liquidations.length} liquidation event(s)`);
      console.log('');

      for (const liq of liquidations) {
        allUserIds.add(liq.user_id);
        console.log('─'.repeat(80));
        console.log(`Position ID: ${liq.position_id}`);
        console.log(`User ID: ${liq.user_id}`);
        console.log(`Pair: ${liq.pair}`);
        console.log(`Side: ${liq.side}`);
        console.log(`Quantity: ${liq.quantity}`);
        console.log(`Entry Price: $${parseFloat(liq.entry_price).toFixed(2)}`);
        console.log(`Liquidation Price: $${parseFloat(liq.liquidation_price).toFixed(2)}`);
        console.log(`Equity Before: $${parseFloat(liq.equity_before).toFixed(2)}`);
        console.log(`Loss Amount: $${parseFloat(liq.loss_amount).toFixed(2)}`);
        console.log(`Liquidation Fee: $${parseFloat(liq.liquidation_fee).toFixed(2)}`);
        console.log(`Insurance Fund Used: $${parseFloat(liq.insurance_fund_used || 0).toFixed(2)}`);
        console.log(`Timestamp: ${new Date(liq.created_at).toLocaleString()}`);
        console.log('');
      }
    }

    // 2. Check Futures Positions Status
    console.log('━'.repeat(80));
    console.log('2. POSITION STATUS');
    console.log('━'.repeat(80));
    console.log('');

    const { data: positions, error: posError } = await supabase
      .from('futures_positions')
      .select('*')
      .in('pair', TEST_PAIRS)
      .eq('status', 'liquidated')
      .order('closed_at', { ascending: false });

    if (posError) {
      console.error('❌ Error fetching positions:', posError.message);
    } else if (!positions || positions.length === 0) {
      console.log('⚠️  No liquidated positions found for these pairs');
    } else {
      console.log(`✅ Found ${positions.length} liquidated position(s)`);
      console.log('');

      for (const pos of positions) {
        allUserIds.add(pos.user_id);
        console.log(`Position ID: ${pos.position_id}`);
        console.log(`User ID: ${pos.user_id}`);
        console.log(`Pair: ${pos.pair} (${pos.side})`);
        console.log(`Margin Allocated: $${parseFloat(pos.margin_allocated).toFixed(2)}`);
        console.log(`Unrealized PNL: $${parseFloat(pos.unrealized_pnl).toFixed(2)}`);
        console.log(`Cumulative Fees: $${parseFloat(pos.cumulative_fees).toFixed(2)}`);
        console.log(`Opened: ${new Date(pos.opened_at).toLocaleString()}`);
        console.log(`Closed: ${new Date(pos.closed_at).toLocaleString()}`);
        console.log('');
      }
    }

    // 3. Check User Wallet Balances
    console.log('━'.repeat(80));
    console.log('3. USER WALLET BALANCES');
    console.log('━'.repeat(80));
    console.log('');

    if (allUserIds.size === 0) {
      console.log('⚠️  No user IDs found from liquidations');
    } else {
      const userIdArray = Array.from(allUserIds);

      for (const userId of userIdArray) {
        console.log('─'.repeat(80));
        console.log(`User ID: ${userId}`);
        console.log('');

        // Get user profile
        const { data: profile } = await supabase
          .from('user_profiles')
          .select('username, email, full_name')
          .eq('id', userId)
          .single();

        if (profile) {
          console.log(`Username: ${profile.username || 'N/A'}`);
          console.log(`Email: ${profile.email || 'N/A'}`);
          console.log(`Full Name: ${profile.full_name || 'N/A'}`);
          console.log('');
        }

        // Check futures margin wallet
        const { data: futuresWallet } = await supabase
          .from('futures_margin_wallets')
          .select('*')
          .eq('user_id', userId)
          .single();

        if (futuresWallet) {
          const available = parseFloat(futuresWallet.available_balance);
          const locked = parseFloat(futuresWallet.locked_balance);
          const total = available + locked;

          console.log('Futures Margin Wallet:');
          console.log(`  Available Balance: $${available.toFixed(2)}`);
          console.log(`  Locked Balance: $${locked.toFixed(2)}`);
          console.log(`  Total Balance: $${total.toFixed(2)}`);

          if (total < 0.01) {
            console.log('  ✅ Balance is zero (liquidated completely)');
          } else {
            console.log(`  ⚠️  Balance remaining: $${total.toFixed(2)}`);
          }
          console.log('');
        } else {
          console.log('❌ No futures margin wallet found');
          console.log('');
        }

        // Check main wallet
        const { data: mainWallet } = await supabase
          .from('wallets')
          .select('*')
          .eq('user_id', userId)
          .eq('wallet_type', 'main')
          .eq('currency', 'USD')
          .single();

        if (mainWallet) {
          console.log('Main Wallet (USD):');
          console.log(`  Balance: $${parseFloat(mainWallet.balance).toFixed(2)}`);
          console.log('');
        }
      }
    }

    // 4. Check Locked Bonuses
    console.log('━'.repeat(80));
    console.log('4. LOCKED BONUSES STATUS');
    console.log('━'.repeat(80));
    console.log('');

    if (allUserIds.size === 0) {
      console.log('⚠️  No user IDs to check');
    } else {
      const userIdArray = Array.from(allUserIds);

      const { data: bonuses } = await supabase
        .from('locked_bonuses')
        .select('*')
        .in('user_id', userIdArray)
        .order('created_at', { ascending: false });

      if (!bonuses || bonuses.length === 0) {
        console.log('ℹ️  No locked bonuses found for these users');
      } else {
        console.log(`Found ${bonuses.length} locked bonus record(s)`);
        console.log('');

        for (const bonus of bonuses) {
          console.log('─'.repeat(80));
          console.log(`User ID: ${bonus.user_id}`);
          console.log(`Bonus Type: ${bonus.bonus_type_id}`);
          console.log(`Original Amount: $${parseFloat(bonus.original_amount).toFixed(2)}`);
          console.log(`Current Amount: $${parseFloat(bonus.current_amount).toFixed(2)}`);
          console.log(`Margin From Locked Bonus: $${parseFloat(bonus.margin_from_locked_bonus || 0).toFixed(2)}`);
          console.log(`Status: ${bonus.status}`);
          console.log(`Created: ${new Date(bonus.created_at).toLocaleString()}`);

          if (parseFloat(bonus.current_amount) === 0) {
            console.log('✅ Bonus fully depleted');
          } else {
            console.log(`⚠️  Bonus remaining: $${parseFloat(bonus.current_amount).toFixed(2)}`);
          }
          console.log('');
        }
      }
    }

    // 5. Check Liquidation Transactions
    console.log('━'.repeat(80));
    console.log('5. LIQUIDATION TRANSACTIONS');
    console.log('━'.repeat(80));
    console.log('');

    if (allUserIds.size === 0) {
      console.log('⚠️  No user IDs to check');
    } else {
      const userIdArray = Array.from(allUserIds);

      const { data: transactions } = await supabase
        .from('transactions')
        .select('*')
        .in('user_id', userIdArray)
        .eq('transaction_type', 'futures_close')
        .order('created_at', { ascending: false })
        .limit(20);

      if (!transactions || transactions.length === 0) {
        console.log('⚠️  No futures_close transactions found');
      } else {
        console.log(`✅ Found ${transactions.length} transaction record(s)`);
        console.log('');

        for (const tx of transactions) {
          const details = tx.details ? JSON.parse(tx.details) : {};
          console.log(`Transaction ID: ${tx.id}`);
          console.log(`User ID: ${tx.user_id}`);
          console.log(`Amount: $${parseFloat(tx.amount).toFixed(2)}`);
          console.log(`Currency: ${tx.currency}`);
          console.log(`Status: ${tx.status}`);
          console.log(`Details: ${JSON.stringify(details, null, 2)}`);
          console.log(`Timestamp: ${new Date(tx.created_at).toLocaleString()}`);
          console.log('');
        }
      }
    }

    // 6. Check Notifications
    console.log('━'.repeat(80));
    console.log('6. LIQUIDATION NOTIFICATIONS');
    console.log('━'.repeat(80));
    console.log('');

    if (allUserIds.size === 0) {
      console.log('⚠️  No user IDs to check');
    } else {
      const userIdArray = Array.from(allUserIds);

      const { data: notifications } = await supabase
        .from('notifications')
        .select('*')
        .in('user_id', userIdArray)
        .eq('notification_type', 'liquidation')
        .order('created_at', { ascending: false });

      if (!notifications || notifications.length === 0) {
        console.log('⚠️  No liquidation notifications found');
      } else {
        console.log(`✅ Found ${notifications.length} notification(s)`);
        console.log('');

        for (const notif of notifications) {
          console.log(`Notification ID: ${notif.id}`);
          console.log(`User ID: ${notif.user_id}`);
          console.log(`Message: ${notif.message}`);
          console.log(`Read: ${notif.read ? 'Yes' : 'No'}`);
          console.log(`Timestamp: ${new Date(notif.created_at).toLocaleString()}`);
          console.log('');
        }
      }
    }

    // 7. Summary
    console.log('━'.repeat(80));
    console.log('7. SUMMARY');
    console.log('━'.repeat(80));
    console.log('');
    console.log(`Total Users Affected: ${allUserIds.size}`);
    console.log(`Total Liquidation Events: ${liquidations?.length || 0}`);
    console.log(`Total Liquidated Positions: ${positions?.length || 0}`);
    console.log('');
    console.log('✅ Verification complete!');
    console.log('');

  } catch (error) {
    console.error('❌ Error during verification:', error);
    process.exit(1);
  }
}

verifyLiquidations();

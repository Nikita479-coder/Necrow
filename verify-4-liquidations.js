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

// The 4 specific liquidation IDs from today
const LIQUIDATION_IDS = [
  '98ae21f7-f304-470e-b1c5-c4cdf46c0b3c', // ARUSDT
  '0ac6f036-c770-4c77-b596-b563c744cfd9', // GMTUSDT
  '8c537eae-3123-451c-871a-76e6f02e67a6', // FLOWUSDT
  '644ed7b9-5e08-4e36-bfd4-950f86275aaa'  // BTCUSDT
];

async function verifyLiquidations() {
  console.log('═'.repeat(80));
  console.log('   DETAILED LIQUIDATION VERIFICATION - 4 TEST POSITIONS');
  console.log('═'.repeat(80));
  console.log('');

  try {
    // Get the 4 most recent liquidation events from today for our test pairs
    const { data: liquidations, error: liqError } = await supabase
      .from('liquidation_events')
      .select('*')
      .in('pair', ['BTCUSDT', 'FLOWUSDT', 'GMTUSDT', 'ARUSDT'])
      .gte('created_at', '2025-12-30T10:29:00')
      .order('created_at', { ascending: true });

    if (liqError) {
      console.error('❌ Error:', liqError.message);
      process.exit(1);
    }

    if (!liquidations || liquidations.length === 0) {
      console.log('❌ No liquidations found with those IDs');
      process.exit(1);
    }

    console.log(`✅ Found ${liquidations.length} liquidation events`);
    console.log('');

    const allUserIds = [...new Set(liquidations.map(l => l.user_id))];

    // Process each liquidation
    for (let i = 0; i < liquidations.length; i++) {
      const liq = liquidations[i];

      console.log('═'.repeat(80));
      console.log(`   LIQUIDATION ${i + 1} of ${liquidations.length}: ${liq.pair}`);
      console.log('═'.repeat(80));
      console.log('');

      // Basic liquidation info
      console.log('┌─ LIQUIDATION DETAILS');
      console.log('│');
      console.log(`│  Position ID: ${liq.position_id}`);
      console.log(`│  Liquidation ID: ${liq.id}`);
      console.log(`│  User ID: ${liq.user_id}`);
      console.log(`│  Pair: ${liq.pair}`);
      console.log(`│  Side: ${liq.side.toUpperCase()}`);
      console.log(`│  Quantity: ${liq.quantity}`);
      console.log(`│`);
      console.log(`│  Entry Price: $${parseFloat(liq.entry_price).toFixed(4)}`);
      console.log(`│  Liquidation Price: $${parseFloat(liq.liquidation_price).toFixed(4)}`);
      console.log(`│`);
      console.log(`│  Equity Before: $${parseFloat(liq.equity_before).toFixed(2)}`);
      console.log(`│  Loss Amount: $${parseFloat(liq.loss_amount).toFixed(2)}`);
      console.log(`│  Liquidation Fee: $${parseFloat(liq.liquidation_fee).toFixed(2)}`);
      console.log(`│  Insurance Fund Used: $${parseFloat(liq.insurance_fund_used || 0).toFixed(2)}`);
      console.log(`│`);
      console.log(`│  Timestamp: ${new Date(liq.created_at).toLocaleString()}`);
      console.log('└─');
      console.log('');

      // Get user profile
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('username, email, full_name')
        .eq('id', liq.user_id)
        .single();

      console.log('┌─ USER PROFILE');
      console.log('│');
      if (profile) {
        console.log(`│  Username: ${profile.username || 'N/A'}`);
        console.log(`│  Email: ${profile.email || 'N/A'}`);
        console.log(`│  Full Name: ${profile.full_name || 'N/A'}`);
      } else {
        console.log('│  ❌ User profile not found');
      }
      console.log('└─');
      console.log('');

      // Check position status
      const { data: position } = await supabase
        .from('futures_positions')
        .select('*')
        .eq('position_id', liq.position_id)
        .single();

      console.log('┌─ POSITION STATUS');
      console.log('│');
      if (position) {
        console.log(`│  Status: ${position.status.toUpperCase()}`);
        console.log(`│  Margin Allocated: $${parseFloat(position.margin_allocated).toFixed(2)}`);
        console.log(`│  Unrealized PNL: $${parseFloat(position.unrealized_pnl).toFixed(2)}`);
        console.log(`│  Cumulative Fees: $${parseFloat(position.cumulative_fees).toFixed(2)}`);
        console.log(`│  Leverage: ${position.leverage}x`);
        console.log(`│  Margin Mode: ${position.margin_mode}`);

        if (position.status === 'liquidated') {
          console.log('│  ✅ Position correctly marked as liquidated');
        } else {
          console.log(`│  ⚠️  Position status is "${position.status}" (expected "liquidated")`);
        }
      } else {
        console.log('│  ❌ Position not found');
      }
      console.log('└─');
      console.log('');

      // Check futures wallet balance
      const { data: futuresWallet } = await supabase
        .from('futures_margin_wallets')
        .select('*')
        .eq('user_id', liq.user_id)
        .single();

      console.log('┌─ FUTURES WALLET BALANCE');
      console.log('│');
      if (futuresWallet) {
        const available = parseFloat(futuresWallet.available_balance);
        const locked = parseFloat(futuresWallet.locked_balance);
        const total = available + locked;

        console.log(`│  Available Balance: $${available.toFixed(2)}`);
        console.log(`│  Locked Balance: $${locked.toFixed(2)}`);
        console.log(`│  Total Balance: $${total.toFixed(2)}`);

        if (total < 0.01) {
          console.log('│  ✅ Wallet is zeroed out (fully liquidated)');
        } else {
          console.log(`│  ⚠️  Wallet still has balance: $${total.toFixed(2)}`);
        }
      } else {
        console.log('│  ❌ Futures wallet not found');
      }
      console.log('└─');
      console.log('');

      // Check locked bonuses
      const { data: lockedBonuses } = await supabase
        .from('locked_bonuses')
        .select('*')
        .eq('user_id', liq.user_id)
        .order('created_at', { ascending: false });

      console.log('┌─ LOCKED BONUSES');
      console.log('│');
      if (!lockedBonuses || lockedBonuses.length === 0) {
        console.log('│  ℹ️  No locked bonuses found for this user');
      } else {
        for (const bonus of lockedBonuses) {
          console.log(`│  Bonus Type: ${bonus.bonus_type_id}`);
          console.log(`│  Original Amount: $${parseFloat(bonus.original_amount).toFixed(2)}`);
          console.log(`│  Current Amount: $${parseFloat(bonus.current_amount).toFixed(2)}`);
          console.log(`│  Margin from Locked Bonus: $${parseFloat(bonus.margin_from_locked_bonus || 0).toFixed(2)}`);
          console.log(`│  Status: ${bonus.status}`);

          if (parseFloat(bonus.current_amount) === 0) {
            console.log('│  ✅ Bonus fully depleted');
          } else if (parseFloat(bonus.current_amount) < parseFloat(bonus.original_amount)) {
            console.log('│  ⚠️  Bonus partially used');
          }
          console.log('│');
        }
      }
      console.log('└─');
      console.log('');

      // Check for liquidation transaction
      const { data: transactions } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', liq.user_id)
        .eq('transaction_type', 'futures_close')
        .order('created_at', { ascending: false })
        .limit(5);

      console.log('┌─ RELATED TRANSACTIONS');
      console.log('│');
      if (!transactions || transactions.length === 0) {
        console.log('│  ⚠️  No futures_close transactions found');
      } else {
        const relevantTx = transactions.find(tx => {
          const created = new Date(tx.created_at);
          const liqCreated = new Date(liq.created_at);
          const diff = Math.abs(created - liqCreated);
          return diff < 10000; // Within 10 seconds
        });

        if (relevantTx) {
          console.log('│  ✅ Found matching transaction:');
          console.log(`│  Transaction ID: ${relevantTx.id}`);
          console.log(`│  Amount: $${parseFloat(relevantTx.amount).toFixed(2)}`);
          console.log(`│  Status: ${relevantTx.status}`);
          console.log(`│  Timestamp: ${new Date(relevantTx.created_at).toLocaleString()}`);
        } else {
          console.log('│  ⚠️  No transaction found within 10 seconds of liquidation');
          console.log('│  Recent transactions:');
          transactions.slice(0, 2).forEach(tx => {
            console.log(`│    - ${tx.transaction_type}: $${parseFloat(tx.amount).toFixed(2)} at ${new Date(tx.created_at).toLocaleString()}`);
          });
        }
      }
      console.log('└─');
      console.log('');

      // Check for notification
      const { data: notifications } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', liq.user_id)
        .eq('notification_type', 'liquidation')
        .order('created_at', { ascending: false })
        .limit(5);

      console.log('┌─ LIQUIDATION NOTIFICATION');
      console.log('│');
      if (!notifications || notifications.length === 0) {
        console.log('│  ❌ No liquidation notification found');
      } else {
        const relevantNotif = notifications.find(n => {
          const created = new Date(n.created_at);
          const liqCreated = new Date(liq.created_at);
          const diff = Math.abs(created - liqCreated);
          return diff < 10000; // Within 10 seconds
        });

        if (relevantNotif) {
          console.log('│  ✅ Notification sent:');
          console.log(`│  Message: ${relevantNotif.message}`);
          console.log(`│  Read: ${relevantNotif.read ? 'Yes' : 'No'}`);
          console.log(`│  Timestamp: ${new Date(relevantNotif.created_at).toLocaleString()}`);
        } else {
          console.log('│  ⚠️  No notification found within 10 seconds of liquidation');
        }
      }
      console.log('└─');
      console.log('');
      console.log('');
    }

    // Final Summary
    console.log('═'.repeat(80));
    console.log('   SUMMARY');
    console.log('═'.repeat(80));
    console.log('');
    console.log(`Total Liquidations Verified: ${liquidations.length}`);
    console.log(`Unique Users Affected: ${allUserIds.length}`);
    console.log('');

    // Calculate totals
    const totalLosses = liquidations.reduce((sum, l) => sum + parseFloat(l.loss_amount), 0);
    const totalFees = liquidations.reduce((sum, l) => sum + parseFloat(l.liquidation_fee), 0);
    const totalInsurance = liquidations.reduce((sum, l) => sum + parseFloat(l.insurance_fund_used || 0), 0);

    console.log(`Total Loss Amount: $${totalLosses.toFixed(2)}`);
    console.log(`Total Liquidation Fees: $${totalFees.toFixed(2)}`);
    console.log(`Total Insurance Fund Used: $${totalInsurance.toFixed(2)}`);
    console.log('');

    // Check all users' final balances
    console.log('┌─ FINAL USER BALANCES');
    console.log('│');
    for (const userId of allUserIds) {
      const { data: wallet } = await supabase
        .from('futures_margin_wallets')
        .select('available_balance, locked_balance')
        .eq('user_id', userId)
        .single();

      if (wallet) {
        const total = parseFloat(wallet.available_balance) + parseFloat(wallet.locked_balance);
        const status = total < 0.01 ? '✅ ZERO' : `⚠️  $${total.toFixed(2)}`;
        console.log(`│  ${userId}: ${status}`);
      }
    }
    console.log('└─');
    console.log('');
    console.log('✅ Verification Complete!');
    console.log('');

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyLiquidations();

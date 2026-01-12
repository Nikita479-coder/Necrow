import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

const userId = 'df2ab388-0646-4abf-975c-22b11c926f1a';

async function liquidateAllPositions() {
  console.log('=== LIQUIDATING ALL POSITIONS ===');
  console.log('User ID:', userId);

  // Direct SQL to liquidate all positions
  const liquidateSql = `
    WITH positions_to_liquidate AS (
      SELECT
        position_id,
        pair,
        side,
        quantity,
        entry_price,
        liquidation_price,
        margin_allocated,
        margin_from_locked_bonus,
        unrealized_pnl,
        cumulative_fees,
        overnight_fees_accrued
      FROM futures_positions
      WHERE user_id = '${userId}'
        AND status = 'open'
    ),
    updated_positions AS (
      UPDATE futures_positions
      SET
        status = 'liquidated',
        closed_at = now(),
        realized_pnl = unrealized_pnl - cumulative_fees - overnight_fees_accrued
      WHERE position_id IN (SELECT position_id FROM positions_to_liquidate)
      RETURNING position_id, pair, side, quantity, margin_allocated, margin_from_locked_bonus, realized_pnl
    ),
    create_transactions AS (
      INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
      SELECT
        '${userId}',
        'liquidation',
        'USDT',
        0,
        'completed',
        jsonb_build_object(
          'position_id', p.position_id,
          'pair', p.pair,
          'side', p.side,
          'quantity', p.quantity,
          'margin_lost', p.margin_allocated,
          'realized_pnl', p.realized_pnl
        )
      FROM updated_positions p
      RETURNING transaction_id, details
    ),
    create_notifications AS (
      INSERT INTO notifications (user_id, type, title, message, read, data)
      SELECT
        '${userId}',
        'position_liquidated',
        'Position Liquidated',
        'Your ' || p.pair || ' ' || UPPER(p.side) || ' position was liquidated due to insufficient margin.',
        false,
        jsonb_build_object(
          'position_id', p.position_id,
          'pair', p.pair,
          'side', p.side,
          'margin_lost', p.margin_allocated::text,
          'redirect_url', '/futures-trading'
        )
      FROM updated_positions p
      RETURNING notification_id
    )
    SELECT
      (SELECT COUNT(*) FROM updated_positions) as liquidated_count,
      (SELECT COUNT(*) FROM create_transactions) as transaction_count,
      (SELECT COUNT(*) FROM create_notifications) as notification_count,
      (SELECT json_agg(row_to_json(p)) FROM updated_positions p) as positions
    ;
  `;

  const { data, error } = await supabase.rpc('exec_sql', {
    sql_query: liquidateSql
  });

  if (error) {
    console.error('Error with RPC:', error);

    // Try direct execute_sql instead
    const { data: result, error: sqlError } = await supabase.rpc('execute_sql', {
      query: liquidateSql
    });

    if (sqlError) {
      console.error('SQL Error:', sqlError);
      return;
    }

    console.log('Result:', JSON.stringify(result, null, 2));
  } else {
    console.log('Result:', JSON.stringify(data, null, 2));
  }

  console.log('\n=== LIQUIDATION COMPLETE ===');

  // Check final wallet status
  const { data: wallets, error: walletError } = await supabase
    .from('wallets')
    .select('currency, balance, wallet_type')
    .eq('user_id', userId);

  if (!walletError && wallets) {
    console.log('\n=== FINAL WALLET BALANCES ===');
    wallets.forEach(w => {
      console.log(`${w.wallet_type} ${w.currency}: ${w.balance}`);
    });
  }
}

liquidateAllPositions().catch(console.error);

/*
  # Integrate Fee Vouchers with Trading System

  1. New Functions
    - `calculate_effective_fee()` - Calculates fee after voucher application
    - `apply_voucher_to_recent_trade()` - Applies voucher to a completed trade's fee
    - `get_trading_fee_summary()` - Gets user's fee stats with voucher savings

  2. Logic
    - Fee vouchers are applied post-trade to refund fee amounts
    - Creates a credit transaction to offset the fee charged
    - Tracks all voucher applications in fee_voucher_usage

  3. Note
    - This approach doesn't modify core trading functions
    - Vouchers effectively rebate fees after collection
    - Frontend can show "effective fee" before trade execution
*/

-- Function to calculate what the effective fee would be with vouchers
CREATE OR REPLACE FUNCTION calculate_effective_fee(
  p_user_id uuid,
  p_gross_fee numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_voucher_balance numeric;
  v_voucher_to_use numeric;
  v_net_fee numeric;
BEGIN
  v_voucher_balance := get_user_fee_voucher_balance(p_user_id);
  v_voucher_to_use := LEAST(v_voucher_balance, p_gross_fee);
  v_net_fee := GREATEST(0, p_gross_fee - v_voucher_to_use);

  RETURN jsonb_build_object(
    'gross_fee', p_gross_fee,
    'voucher_balance', v_voucher_balance,
    'voucher_applicable', v_voucher_to_use,
    'net_fee', v_net_fee,
    'savings_percent', CASE WHEN p_gross_fee > 0 THEN ROUND((v_voucher_to_use / p_gross_fee) * 100, 2) ELSE 0 END
  );
END;
$$;

-- Function to apply voucher rebate after a trade
CREATE OR REPLACE FUNCTION apply_voucher_rebate_to_trade(
  p_user_id uuid,
  p_fee_amount numeric,
  p_fee_type text,
  p_transaction_id uuid DEFAULT NULL,
  p_position_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_voucher_result jsonb;
  v_wallet_id uuid;
  v_rebate_txn_id uuid;
BEGIN
  IF p_fee_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'rebate_amount', 0,
      'message', 'No fee to rebate'
    );
  END IF;

  v_voucher_result := apply_fee_voucher(
    p_user_id,
    p_fee_amount,
    p_fee_type,
    p_transaction_id,
    p_position_id
  );

  IF (v_voucher_result->>'voucher_used')::numeric > 0 THEN
    SELECT id INTO v_wallet_id
    FROM wallets
    WHERE user_id = p_user_id AND wallet_type = 'main' AND currency = 'USDT';

    IF v_wallet_id IS NOT NULL THEN
      UPDATE wallets
      SET balance = balance + (v_voucher_result->>'voucher_used')::numeric,
          updated_at = now()
      WHERE id = v_wallet_id;

      INSERT INTO transactions (
        user_id,
        wallet_id,
        transaction_type,
        amount,
        currency,
        status,
        details
      ) VALUES (
        p_user_id,
        v_wallet_id,
        'fee_rebate',
        (v_voucher_result->>'voucher_used')::numeric,
        'USDT',
        'completed',
        jsonb_build_object(
          'source', 'fee_voucher',
          'fee_type', p_fee_type,
          'original_fee', p_fee_amount,
          'voucher_used', v_voucher_result->>'voucher_used',
          'original_transaction_id', p_transaction_id,
          'position_id', p_position_id
        )
      )
      RETURNING id INTO v_rebate_txn_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'original_fee', p_fee_amount,
    'rebate_amount', (v_voucher_result->>'voucher_used')::numeric,
    'final_fee', (v_voucher_result->>'final_fee')::numeric,
    'rebate_transaction_id', v_rebate_txn_id
  );
END;
$$;

-- Function to get user's trading fee summary with voucher info
CREATE OR REPLACE FUNCTION get_trading_fee_summary(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_summary jsonb;
BEGIN
  SELECT jsonb_build_object(
    'voucher_balance', get_user_fee_voucher_balance(p_user_id),
    'active_vouchers', (
      SELECT COUNT(*) FROM fee_vouchers
      WHERE user_id = p_user_id AND is_active = true AND remaining_amount > 0 AND expires_at > now()
    ),
    'total_voucher_savings', (
      SELECT COALESCE(SUM(voucher_amount_used), 0) FROM fee_voucher_usage
      WHERE user_id = p_user_id
    ),
    'vouchers_expiring_soon', (
      SELECT COUNT(*) FROM fee_vouchers
      WHERE user_id = p_user_id AND is_active = true AND remaining_amount > 0
        AND expires_at > now() AND expires_at < now() + interval '7 days'
    ),
    'next_voucher_expiry', (
      SELECT MIN(expires_at) FROM fee_vouchers
      WHERE user_id = p_user_id AND is_active = true AND remaining_amount > 0 AND expires_at > now()
    )
  ) INTO v_summary;

  RETURN v_summary;
END;
$$;

-- Add fee_rebate transaction type if not exists
DO $$
BEGIN
  ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
  
  ALTER TABLE transactions
  ADD CONSTRAINT transactions_transaction_type_check
  CHECK (transaction_type IN (
    'deposit', 'withdrawal', 'transfer', 'trade', 'fee', 'reward', 'referral',
    'staking', 'unstaking', 'staking_reward', 'swap', 'futures_pnl', 'funding_fee',
    'liquidation', 'bonus', 'admin_credit', 'admin_debit', 'fee_rebate',
    'affiliate_commission', 'locked_trading_bonus', 'copy_trade_pnl'
  ));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION calculate_effective_fee(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION apply_voucher_rebate_to_trade(uuid, numeric, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_trading_fee_summary(uuid) TO authenticated;

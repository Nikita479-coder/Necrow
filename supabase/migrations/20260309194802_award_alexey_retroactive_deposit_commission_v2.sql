/*
  # Award retroactive deposit commission for pre-enrollment referral

  Alexey (alx56rty@gmail.com, ID: 016e12a6-f4e1-4a3f-9453-909956660d16)
  referred Urgen (urgen963@gmail.com) before being enrolled as an exclusive
  affiliate. Urgen completed a $110 USDT deposit before Alexey's enrollment,
  so the automatic commission was never triggered.

  This migration:
  1. Updates exclusive_affiliate_network_stats to count Urgen at level 1
  2. Calls distribute_exclusive_deposit_commission to retroactively award
     the 5% commission ($5.50) to Alexey and propagate up the chain
*/

DO $$
DECLARE
  v_result jsonb;
BEGIN
  -- Step 1: Ensure Alexey has a network stats entry with Urgen counted at level 1
  INSERT INTO exclusive_affiliate_network_stats (affiliate_id, level_1_count)
  VALUES ('016e12a6-f4e1-4a3f-9453-909956660d16', 1)
  ON CONFLICT (affiliate_id) DO UPDATE SET
    level_1_count = exclusive_affiliate_network_stats.level_1_count + 1,
    updated_at = now();

  -- Step 2: Distribute the deposit commission retroactively
  -- Urgen's finished deposit: payment_id = 4c1692bc-076f-474d-a392-685548957483
  -- actually_paid = 110 USDTBSC (= $110 USD value)
  SELECT distribute_exclusive_deposit_commission(
    '7619d3eb-6408-4ad7-95c4-bc43eb4273ae'::uuid,  -- Urgen (depositor)
    110.00,                                           -- deposit amount in USD
    '4c1692bc-076f-474d-a392-685548957483'::uuid      -- deposit payment_id
  ) INTO v_result;

  RAISE NOTICE 'Commission distribution result: %', v_result;
END $$;

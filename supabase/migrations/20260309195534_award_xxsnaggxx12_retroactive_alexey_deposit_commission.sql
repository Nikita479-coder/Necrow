/*
  # Award retroactive deposit commission for Alexey's deposit to Xxsnaggxx12

  Alexey (alx56rty@gmail.com) completed a 150 USDT deposit on 2026-03-09 10:24,
  but Xxsnaggxx12 was enrolled as an exclusive affiliate later at 19:33 the same day.
  So the automatic level 1 deposit commission was never triggered.

  This migration retroactively awards:
  - Level 1 commission: 5% of $150 = $7.50 to Xxsnaggxx12

  Also updates level_1_earnings in the network stats accordingly.
*/

DO $$
DECLARE
  v_result jsonb;
BEGIN
  -- Distribute the deposit commission retroactively
  -- Alexey's finished deposit: payment_id = 2cd25557-5e33-4a5e-a084-f13052f231f5
  -- actually_paid = 150 USDTBSC (= $150 USD value)
  SELECT distribute_exclusive_deposit_commission(
    '016e12a6-f4e1-4a3f-9453-909956660d16'::uuid,  -- Alexey (depositor)
    150.00,                                           -- deposit amount in USD
    '2cd25557-5e33-4a5e-a084-f13052f231f5'::uuid     -- deposit payment_id
  ) INTO v_result;

  RAISE NOTICE 'Commission distribution result: %', v_result;
END $$;

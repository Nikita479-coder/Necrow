/*
  # Add crypto_deposits record for manual $110 deposit (reshadmollik604@gmail.com)

  1. Context
    - reshadmollik604@gmail.com received a manual $110 deposit (admin balance adjustment)
    - No crypto_deposits record exists, so they don't count as a qualified referral
    - This prevents koliza64@gmail.com's Network Champion Bonus progress from reflecting 8/10

  2. Changes
    - Insert a completed crypto_deposits record for $110 USDT for reshadmollik604@gmail.com
    - This will make the qualified referral count go from 7 to 8
*/

INSERT INTO crypto_deposits (
  payment_id,
  user_id,
  nowpayments_payment_id,
  price_amount,
  price_currency,
  pay_amount,
  pay_currency,
  status,
  actually_paid,
  outcome_amount,
  created_at,
  updated_at,
  completed_at,
  wallet_type
) VALUES (
  gen_random_uuid(),
  '14f44038-2e15-4113-95cf-be0a20ba7e99',
  'manual_deposit_admin',
  110.00,
  'usd',
  110.00,
  'USDTTRC20',
  'finished',
  110.00,
  110.00,
  now(),
  now(),
  now(),
  'main'
);

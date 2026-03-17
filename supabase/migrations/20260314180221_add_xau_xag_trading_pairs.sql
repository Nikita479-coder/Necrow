/*
  # Add Gold (XAU) and Silver (XAG) Trading Pairs

  1. New Trading Pairs
    - `XAUUSDT` - Gold / USDT pair
    - `XAGUSDT` - Silver / USDT pair
  2. Changes
    - Inserts initial market price records for both pairs
    - Inserts trading pairs config entries (pair_type = 'major')
*/

INSERT INTO market_prices (pair, last_price, mark_price, index_price, bid_price, ask_price, volume_24h)
VALUES 
  ('XAUUSDT', 3000, 3000, 3000, 2999, 3001, 0),
  ('XAGUSDT', 33, 33, 33, 32.99, 33.01, 0)
ON CONFLICT (pair) DO NOTHING;

INSERT INTO trading_pairs_config (pair, max_leverage, maker_fee, taker_fee, liquidation_fee, min_order_size, max_position_size, pair_type, is_active)
VALUES 
  ('XAUUSDT', 100, 0.02, 0.06, 0.5, 0.01, 1000000, 'major', true),
  ('XAGUSDT', 100, 0.02, 0.06, 0.5, 0.1, 1000000, 'major', true)
ON CONFLICT (pair) DO NOTHING;

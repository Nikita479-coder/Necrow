/*
  # Delete stale bare-symbol rows from market_prices

  1. Changes
    - Remove all rows from market_prices where the pair column does NOT end with 'USDT'
    - These are stale duplicate rows (e.g. 'MANA' alongside 'MANAUSDT') last updated in Jan 2026
    - They cause false TP/SL triggers by contaminating the in-memory price map on startup

  2. Affected Data
    - ~109 bare-symbol rows (MANA, OP, WIF, AXS, etc.)
    - All have corresponding XYZUSDT rows that are kept up to date
    - No data loss since the USDT-suffixed rows contain the live prices

  3. Security
    - No RLS changes
    - No schema changes
*/

DELETE FROM market_prices WHERE pair NOT LIKE '%USDT';

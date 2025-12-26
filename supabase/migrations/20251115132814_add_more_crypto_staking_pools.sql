/*
  # Add More Cryptocurrency Staking Pools

  ## Summary
  Expands the earn products to include many more popular cryptocurrencies with various staking options.

  ## New Cryptocurrencies Added
  - AVAX (Avalanche)
  - LINK (Chainlink)
  - UNI (Uniswap)
  - ATOM (Cosmos)
  - ALGO (Algorand)
  - FTM (Fantom)
  - NEAR (NEAR Protocol)
  - APT (Aptos)
  - ARB (Arbitrum)
  - OP (Optimism)
  - INJ (Injective)
  - SUI (Sui)
  - TIA (Celestia)
  - SEI (Sei)
  - PEPE (Pepe)
  - SHIB (Shiba Inu)
  - TRX (Tron)
  - TON (Toncoin)
  - ICP (Internet Computer)
  - VET (VeChain)
  - FIL (Filecoin)
  - HBAR (Hedera)
  - STX (Stacks)
  - IMX (Immutable X)
  - RUNE (THORChain)

  ## Pool Types
  Each cryptocurrency includes multiple pool options:
  - Flexible savings (lower APR, withdraw anytime)
  - 30-day fixed term
  - 60-day fixed term (higher APR)
  - 90-day fixed term (highest APR)
*/

-- AVAX Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('AVAX', 6.5, 0, 'flexible', 1, 1000, 50000, 0, true, false, NULL),
('AVAX', 8.2, 30, 'fixed', 1, 1000, 30000, 0, true, false, NULL),
('AVAX', 9.8, 60, 'fixed', 1, 1000, 25000, 0, true, false, NULL),
('AVAX', 11.5, 90, 'fixed', 1, 1000, 20000, 0, true, true, 'High APR');

-- LINK Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('LINK', 5.8, 0, 'flexible', 1, 500, 40000, 0, true, false, NULL),
('LINK', 7.5, 30, 'fixed', 1, 500, 25000, 0, true, false, NULL),
('LINK', 9.0, 60, 'fixed', 1, 500, 20000, 0, true, false, NULL),
('LINK', 10.5, 90, 'fixed', 1, 500, 15000, 0, true, false, NULL);

-- UNI Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('UNI', 7.2, 0, 'flexible', 5, 1000, 35000, 0, true, false, NULL),
('UNI', 9.0, 30, 'fixed', 5, 1000, 20000, 0, true, false, NULL),
('UNI', 10.8, 60, 'fixed', 5, 1000, 18000, 0, true, true, NULL),
('UNI', 12.5, 90, 'fixed', 5, 1000, 15000, 0, true, false, NULL);

-- ATOM Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('ATOM', 9.5, 0, 'flexible', 1, 800, 30000, 0, true, true, 'Popular'),
('ATOM', 11.2, 30, 'fixed', 1, 800, 20000, 0, true, false, NULL),
('ATOM', 13.0, 60, 'fixed', 1, 800, 18000, 0, true, false, NULL),
('ATOM', 15.0, 90, 'fixed', 1, 800, 15000, 0, true, true, 'Best APR');

-- ALGO Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('ALGO', 8.0, 0, 'flexible', 10, 2000, 40000, 0, true, false, NULL),
('ALGO', 9.8, 30, 'fixed', 10, 2000, 25000, 0, true, false, NULL),
('ALGO', 11.5, 60, 'fixed', 10, 2000, 20000, 0, true, false, NULL),
('ALGO', 13.2, 90, 'fixed', 10, 2000, 18000, 0, true, false, NULL);

-- FTM Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('FTM', 10.5, 0, 'flexible', 20, 5000, 50000, 0, true, false, NULL),
('FTM', 12.8, 30, 'fixed', 20, 5000, 30000, 0, true, false, NULL),
('FTM', 14.5, 60, 'fixed', 20, 5000, 25000, 0, true, false, NULL),
('FTM', 16.8, 90, 'fixed', 20, 5000, 20000, 0, true, true, 'High Yield');

-- NEAR Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('NEAR', 8.8, 0, 'flexible', 5, 1000, 35000, 0, true, false, NULL),
('NEAR', 10.5, 30, 'fixed', 5, 1000, 22000, 0, true, false, NULL),
('NEAR', 12.2, 60, 'fixed', 5, 1000, 20000, 0, true, false, NULL),
('NEAR', 14.0, 90, 'fixed', 5, 1000, 18000, 0, true, false, NULL);

-- APT Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('APT', 9.2, 0, 'flexible', 1, 500, 30000, 0, true, true, 'Trending'),
('APT', 11.0, 30, 'fixed', 1, 500, 20000, 0, true, false, NULL),
('APT', 12.8, 60, 'fixed', 1, 500, 18000, 0, true, false, NULL),
('APT', 14.5, 90, 'fixed', 1, 500, 15000, 0, true, false, NULL);

-- ARB Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('ARB', 7.8, 0, 'flexible', 10, 2000, 45000, 0, true, false, NULL),
('ARB', 9.5, 30, 'fixed', 10, 2000, 28000, 0, true, false, NULL),
('ARB', 11.2, 60, 'fixed', 10, 2000, 25000, 0, true, false, NULL),
('ARB', 13.0, 90, 'fixed', 10, 2000, 22000, 0, true, false, NULL);

-- OP Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('OP', 8.5, 0, 'flexible', 5, 1500, 40000, 0, true, false, NULL),
('OP', 10.2, 30, 'fixed', 5, 1500, 25000, 0, true, false, NULL),
('OP', 12.0, 60, 'fixed', 5, 1500, 22000, 0, true, false, NULL),
('OP', 13.8, 90, 'fixed', 5, 1500, 20000, 0, true, false, NULL);

-- INJ Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('INJ', 11.5, 0, 'flexible', 1, 300, 25000, 0, true, true, 'Hot'),
('INJ', 13.5, 30, 'fixed', 1, 300, 18000, 0, true, false, NULL),
('INJ', 15.5, 60, 'fixed', 1, 300, 15000, 0, true, true, 'Premium'),
('INJ', 17.5, 90, 'fixed', 1, 300, 12000, 0, true, false, NULL);

-- SUI Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('SUI', 10.0, 0, 'flexible', 5, 1000, 30000, 0, true, true, 'New'),
('SUI', 12.0, 30, 'fixed', 5, 1000, 20000, 0, true, false, NULL),
('SUI', 14.0, 60, 'fixed', 5, 1000, 18000, 0, true, false, NULL),
('SUI', 16.0, 90, 'fixed', 5, 1000, 15000, 0, true, false, NULL);

-- TIA Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('TIA', 12.5, 0, 'flexible', 1, 500, 20000, 0, true, true, 'Limited'),
('TIA', 14.8, 30, 'fixed', 1, 500, 15000, 0, true, false, NULL),
('TIA', 16.8, 60, 'fixed', 1, 500, 12000, 0, true, false, NULL),
('TIA', 18.5, 90, 'fixed', 1, 500, 10000, 0, true, true, 'Ultra High APR');

-- SEI Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('SEI', 11.0, 0, 'flexible', 10, 2000, 28000, 0, true, false, NULL),
('SEI', 13.2, 30, 'fixed', 10, 2000, 18000, 0, true, false, NULL),
('SEI', 15.5, 60, 'fixed', 10, 2000, 15000, 0, true, false, NULL),
('SEI', 17.8, 90, 'fixed', 10, 2000, 12000, 0, true, false, NULL);

-- PEPE Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('PEPE', 9.5, 0, 'flexible', 1000000, 100000000, 5000000000, 0, true, false, NULL),
('PEPE', 11.8, 30, 'fixed', 1000000, 100000000, 3000000000, 0, true, false, NULL),
('PEPE', 14.2, 60, 'fixed', 1000000, 100000000, 2500000000, 0, true, false, NULL),
('PEPE', 16.5, 90, 'fixed', 1000000, 100000000, 2000000000, 0, true, false, NULL);

-- SHIB Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('SHIB', 8.8, 0, 'flexible', 500000, 50000000, 3000000000, 0, true, false, NULL),
('SHIB', 10.5, 30, 'fixed', 500000, 50000000, 2000000000, 0, true, false, NULL),
('SHIB', 12.5, 60, 'fixed', 500000, 50000000, 1800000000, 0, true, false, NULL),
('SHIB', 14.8, 90, 'fixed', 500000, 50000000, 1500000000, 0, true, false, NULL);

-- TRX Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('TRX', 7.5, 0, 'flexible', 50, 10000, 100000, 0, true, false, NULL),
('TRX', 9.2, 30, 'fixed', 50, 10000, 60000, 0, true, false, NULL),
('TRX', 11.0, 60, 'fixed', 50, 10000, 50000, 0, true, false, NULL),
('TRX', 12.8, 90, 'fixed', 50, 10000, 45000, 0, true, false, NULL);

-- TON Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('TON', 10.5, 0, 'flexible', 5, 1000, 35000, 0, true, true, 'Rising Star'),
('TON', 12.5, 30, 'fixed', 5, 1000, 22000, 0, true, false, NULL),
('TON', 14.8, 60, 'fixed', 5, 1000, 20000, 0, true, false, NULL),
('TON', 17.0, 90, 'fixed', 5, 1000, 18000, 0, true, false, NULL);

-- ICP Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('ICP', 9.0, 0, 'flexible', 1, 500, 30000, 0, true, false, NULL),
('ICP', 11.0, 30, 'fixed', 1, 500, 20000, 0, true, false, NULL),
('ICP', 13.0, 60, 'fixed', 1, 500, 18000, 0, true, false, NULL),
('ICP', 15.0, 90, 'fixed', 1, 500, 15000, 0, true, false, NULL);

-- VET Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('VET', 6.8, 0, 'flexible', 100, 20000, 80000, 0, true, false, NULL),
('VET', 8.5, 30, 'fixed', 100, 20000, 50000, 0, true, false, NULL),
('VET', 10.2, 60, 'fixed', 100, 20000, 45000, 0, true, false, NULL),
('VET', 12.0, 90, 'fixed', 100, 20000, 40000, 0, true, false, NULL);

-- FIL Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('FIL', 8.2, 0, 'flexible', 1, 500, 35000, 0, true, false, NULL),
('FIL', 10.0, 30, 'fixed', 1, 500, 22000, 0, true, false, NULL),
('FIL', 11.8, 60, 'fixed', 1, 500, 20000, 0, true, false, NULL),
('FIL', 13.5, 90, 'fixed', 1, 500, 18000, 0, true, false, NULL);

-- HBAR Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('HBAR', 7.8, 0, 'flexible', 50, 10000, 60000, 0, true, false, NULL),
('HBAR', 9.5, 30, 'fixed', 50, 10000, 40000, 0, true, false, NULL),
('HBAR', 11.2, 60, 'fixed', 50, 10000, 35000, 0, true, false, NULL),
('HBAR', 13.0, 90, 'fixed', 50, 10000, 30000, 0, true, false, NULL);

-- STX Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('STX', 10.2, 0, 'flexible', 5, 1000, 30000, 0, true, false, NULL),
('STX', 12.5, 30, 'fixed', 5, 1000, 20000, 0, true, false, NULL),
('STX', 14.8, 60, 'fixed', 5, 1000, 18000, 0, true, false, NULL),
('STX', 17.0, 90, 'fixed', 5, 1000, 15000, 0, true, false, NULL);

-- IMX Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('IMX', 9.8, 0, 'flexible', 5, 1000, 28000, 0, true, false, NULL),
('IMX', 11.8, 30, 'fixed', 5, 1000, 18000, 0, true, false, NULL),
('IMX', 13.8, 60, 'fixed', 5, 1000, 16000, 0, true, false, NULL),
('IMX', 16.0, 90, 'fixed', 5, 1000, 14000, 0, true, false, NULL);

-- RUNE Pools
INSERT INTO earn_products (coin, apr, duration_days, product_type, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
('RUNE', 11.2, 0, 'flexible', 1, 500, 25000, 0, true, false, NULL),
('RUNE', 13.5, 30, 'fixed', 1, 500, 18000, 0, true, false, NULL),
('RUNE', 15.8, 60, 'fixed', 1, 500, 15000, 0, true, false, NULL),
('RUNE', 18.0, 90, 'fixed', 1, 500, 12000, 0, true, true, 'DeFi Special');

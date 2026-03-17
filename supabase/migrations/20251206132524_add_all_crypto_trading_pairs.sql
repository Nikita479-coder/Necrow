/*
  # Add All Cryptocurrency Trading Pairs

  ## Description
  This migration adds all the additional cryptocurrency trading pairs that are supported
  in the frontend but were missing from the trading_pairs_config table. This ensures
  that price updates via websocket will work for all cryptocurrencies displayed in the UI.

  ## New Trading Pairs Added
  This migration adds 100+ trading pairs including:
  - Major altcoins (BCH, AAVE, MKR, etc.)
  - Meme coins (WIF, BONK, FLOKI, PEPE, etc.)
  - DeFi tokens (SAND, MANA, AXS, GALA, ENJ, etc.)
  - AI tokens (FET, RENDER, AGIX, OCEAN, GRT, etc.)
  - Layer 1/2 tokens (OSMO, JUNO, KSM, WAVES, ONE, IOTA, NEO, QTUM, ICX, etc.)
  - Gaming/Metaverse tokens
  - Payment tokens (XLM, XMR, DASH, ZEC, etc.)
  - Solana ecosystem tokens (JUP, RAY, ORCA, etc.)
  - And many more

  ## Configuration Details
  - All pairs default to 25x max leverage
  - Most are classified as 'altcoin' pair type
  - Lower cap tokens are marked as 'lowcap'
  - Standard fee structure applies (0.02% maker, 0.04% taker)
  - Active by default

  ## Important Notes
  This migration enables websocket price updates for all these pairs and makes
  them available for futures trading on the platform.
*/

-- Add all missing trading pairs
INSERT INTO trading_pairs_config (pair, max_leverage, pair_type, min_order_size, max_position_size, is_active)
VALUES
  -- Major altcoins
  ('BCHUSDT', 50, 'altcoin', 0.01, 1000, true),
  ('AAVEUSDT', 25, 'altcoin', 0.1, 10000, true),
  ('MKRUSDT', 25, 'altcoin', 0.01, 100, true),
  
  -- Meme coins
  ('WIFUSDT', 25, 'altcoin', 1, 100000, true),
  ('BONKUSDT', 25, 'lowcap', 1000, 10000000, true),
  ('FLOKIUSDT', 25, 'lowcap', 1000, 10000000, true),
  ('PEPEUSDT', 25, 'lowcap', 1000, 10000000, true),
  ('SHIBUSDT', 25, 'altcoin', 1000, 10000000, true),
  
  -- Gaming/Metaverse
  ('SANDUSDT', 25, 'altcoin', 1, 100000, true),
  ('MANAUSDT', 25, 'altcoin', 1, 100000, true),
  ('AXSUSDT', 25, 'altcoin', 0.1, 10000, true),
  ('GALAUSDT', 25, 'altcoin', 10, 1000000, true),
  ('ENJUSDT', 25, 'altcoin', 1, 100000, true),
  
  -- AI tokens
  ('FETUSDT', 25, 'altcoin', 1, 100000, true),
  ('RENDERUSDT', 25, 'altcoin', 1, 10000, true),
  ('AGIXUSDT', 25, 'altcoin', 1, 100000, true),
  ('OCEANUSDT', 25, 'altcoin', 1, 100000, true),
  ('GRTUSDT', 25, 'altcoin', 10, 1000000, true),
  
  -- Payment tokens
  ('XLMUSDT', 25, 'altcoin', 10, 1000000, true),
  ('XMRUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('DASHUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('ZECUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('TRXUSDT', 25, 'altcoin', 100, 10000000, true),
  
  -- BSC ecosystem
  ('CAKEUSDT', 25, 'altcoin', 1, 100000, true),
  ('BSVUSDT', 25, 'altcoin', 0.1, 1000, true),
  
  -- Solana ecosystem
  ('JUPUSDT', 25, 'altcoin', 1, 100000, true),
  ('RAYUSDT', 25, 'altcoin', 1, 10000, true),
  ('ORCAUSDT', 25, 'altcoin', 1, 10000, true),
  
  -- Layer 2
  ('ARBUSDT', 50, 'altcoin', 1, 100000, true),
  ('OPUSDT', 25, 'altcoin', 1, 100000, true),
  ('IMXUSDT', 25, 'altcoin', 1, 100000, true),
  ('LRCUSDT', 25, 'altcoin', 1, 100000, true),
  ('METISUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('STRKUSDT', 25, 'altcoin', 1, 100000, true),
  
  -- New layer 1s
  ('INJUSDT', 50, 'altcoin', 0.1, 10000, true),
  ('SEIUSDT', 25, 'altcoin', 1, 100000, true),
  ('SUIUSDT', 50, 'altcoin', 1, 100000, true),
  ('TIAUSDT', 25, 'altcoin', 0.1, 10000, true),
  ('APTUSDT', 50, 'altcoin', 0.1, 10000, true),
  ('NEARUSDT', 50, 'altcoin', 1, 100000, true),
  ('FTMUSDT', 25, 'altcoin', 1, 100000, true),
  ('ALGOUSDT', 25, 'altcoin', 10, 1000000, true),
  
  -- Cosmos ecosystem
  ('RUNEUSDT', 25, 'altcoin', 1, 100000, true),
  ('KAVAUSDT', 25, 'altcoin', 1, 100000, true),
  ('OSMOUSDT', 25, 'altcoin', 1, 100000, true),
  ('JUNOUSDT', 25, 'lowcap', 1, 100000, true),
  
  -- Older altcoins
  ('KSMUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('WAVESUSDT', 25, 'altcoin', 1, 100000, true),
  ('ONEUSDT', 25, 'altcoin', 100, 10000000, true),
  ('IOTAUSDT', 25, 'altcoin', 10, 1000000, true),
  ('NEOUSDT', 25, 'altcoin', 0.1, 10000, true),
  ('QTUMUSDT', 25, 'altcoin', 1, 100000, true),
  ('ICXUSDT', 25, 'altcoin', 10, 1000000, true),
  ('ONTUSDT', 25, 'altcoin', 10, 1000000, true),
  ('ZENUSDT', 25, 'altcoin', 0.1, 10000, true),
  
  -- Infrastructure & Storage
  ('IOTXUSDT', 25, 'altcoin', 100, 10000000, true),
  ('RVNUSDT', 25, 'lowcap', 100, 10000000, true),
  ('SCUSDT', 25, 'lowcap', 1000, 10000000, true),
  ('STORJUSDT', 25, 'altcoin', 1, 100000, true),
  ('ARUSDT', 25, 'altcoin', 0.1, 10000, true),
  ('ANKRUSDT', 25, 'altcoin', 100, 10000000, true),
  ('CELOUST', 25, 'altcoin', 1, 100000, true),
  ('SKLUSDT', 25, 'altcoin', 100, 10000000, true),
  ('VETUSDT', 50, 'altcoin', 100, 10000000, true),
  ('ICPUSDT', 50, 'altcoin', 0.1, 10000, true),
  ('FILUSDT', 50, 'altcoin', 0.1, 10000, true),
  ('HBARUSDT', 25, 'altcoin', 100, 10000000, true),
  
  -- More DeFi
  ('MASKUSDT', 25, 'altcoin', 1, 100000, true),
  ('AUDIOUSDT', 25, 'altcoin', 10, 1000000, true),
  ('AMPUSDT', 25, 'altcoin', 1000, 10000000, true),
  ('CVCUSDT', 25, 'lowcap', 10, 1000000, true),
  ('OMGUSDT', 25, 'altcoin', 1, 100000, true),
  ('BANDUSDT', 25, 'altcoin', 1, 100000, true),
  ('NKNUSDT', 25, 'lowcap', 100, 10000000, true),
  ('CTSIUSDT', 25, 'altcoin', 10, 1000000, true),
  ('WOOUSDT', 25, 'altcoin', 10, 1000000, true),
  ('PEOPLEUSDT', 25, 'lowcap', 100, 10000000, true),
  ('JOEUSDT', 25, 'altcoin', 1, 100000, true),
  ('CVXUSDT', 25, 'altcoin', 1, 100000, true),
  ('SPELLUSDT', 25, 'lowcap', 10000, 100000000, true),
  ('DYDXUSDT', 25, 'altcoin', 1, 100000, true),
  ('LOOKSUSDT', 25, 'lowcap', 10, 1000000, true),
  ('API3USDT', 25, 'altcoin', 1, 100000, true),
  ('TUSDT', 25, 'lowcap', 100, 10000000, true),
  ('GLMUSDT', 25, 'altcoin', 10, 1000000, true),
  ('PAXGUSDT', 25, 'altcoin', 0.001, 100, true),
  ('RBNUSDT', 25, 'lowcap', 1, 100000, true),
  ('BNTUSDT', 25, 'altcoin', 1, 100000, true),
  ('PERPUSDT', 25, 'altcoin', 1, 100000, true),
  ('ALCXUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('TRBUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('BADGERUSDT', 25, 'altcoin', 1, 10000, true),
  ('SLPUSDT', 25, 'lowcap', 1000, 10000000, true),
  ('PLAUSDT', 25, 'lowcap', 10, 1000000, true),
  ('BOBAUSDT', 25, 'lowcap', 10, 1000000, true),
  ('MPLUSDT', 25, 'lowcap', 0.1, 10000, true),
  ('RADUSDT', 25, 'lowcap', 1, 100000, true),
  ('TRIBEUSDT', 25, 'lowcap', 10, 1000000, true),
  ('FXSUSDT', 25, 'altcoin', 1, 10000, true),
  ('POLSUSDT', 25, 'lowcap', 1, 100000, true),
  ('DAOUSDT', 25, 'lowcap', 1, 100000, true),
  ('C98USDT', 25, 'altcoin', 10, 1000000, true),
  
  -- More layer 1s
  ('ACAUSDT', 25, 'lowcap', 10, 1000000, true),
  ('MOVRUSDT', 25, 'lowcap', 0.1, 10000, true),
  ('SYNUSDT', 25, 'altcoin', 1, 100000, true),
  ('DPIUSDT', 25, 'lowcap', 0.1, 1000, true),
  ('FLOWUSDT', 25, 'altcoin', 1, 100000, true),
  ('EGLDUSDT', 25, 'altcoin', 0.1, 10000, true),
  ('THETAUSDT', 25, 'altcoin', 1, 100000, true),
  ('STXUSDT', 50, 'altcoin', 1, 100000, true),
  
  -- Gaming tokens
  ('CHZUSDT', 25, 'altcoin', 10, 1000000, true),
  ('MAGICUSDT', 25, 'altcoin', 1, 100000, true),
  ('PRIMEUSDT', 25, 'lowcap', 0.1, 10000, true),
  ('BLURUSDT', 25, 'altcoin', 10, 1000000, true),
  
  -- More DeFi
  ('CRVUSDT', 25, 'altcoin', 1, 100000, true),
  ('SUSHIUSDT', 25, 'altcoin', 1, 100000, true),
  ('COMPUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('YFIUSDT', 25, 'altcoin', 0.001, 10, true),
  ('SNXUSDT', 25, 'altcoin', 1, 100000, true),
  ('1INCHUSDT', 25, 'altcoin', 10, 1000000, true),
  ('BALUSDT', 25, 'altcoin', 1, 100000, true),
  
  -- More layer 1s
  ('MINAUSDT', 25, 'altcoin', 1, 100000, true),
  ('ROSEUSDT', 25, 'altcoin', 100, 10000000, true),
  ('ZILUSDT', 25, 'altcoin', 100, 10000000, true),
  ('ZRXUSDT', 25, 'altcoin', 1, 100000, true),
  ('BATUSDT', 25, 'altcoin', 10, 1000000, true),
  ('ENSUSDT', 25, 'altcoin', 0.1, 10000, true),
  ('LDOUSDT', 25, 'altcoin', 1, 100000, true),
  ('RPLUSDT', 25, 'altcoin', 0.1, 1000, true),
  ('APEUSDT', 25, 'altcoin', 1, 100000, true),
  ('GMTUSDT', 25, 'altcoin', 10, 1000000, true),
  ('ILVUSDT', 25, 'lowcap', 0.1, 1000, true),
  ('XTZUSDT', 25, 'altcoin', 1, 100000, true),
  ('EOSUSDT', 25, 'altcoin', 1, 100000, true),
  ('REEFUSDT', 25, 'lowcap', 1000, 10000000, true),
  ('OXTUSDT', 25, 'lowcap', 10, 1000000, true),
  ('AUCTIONUSDT', 25, 'lowcap', 0.1, 10000, true),
  ('PYRUSDT', 25, 'lowcap', 1, 10000, true),
  ('SUPERUSDT', 25, 'lowcap', 10, 1000000, true),
  ('UFTUSDT', 25, 'lowcap', 10, 1000000, true),
  ('ACHUSDT', 25, 'lowcap', 100, 10000000, true),
  ('ERNUSDT', 25, 'lowcap', 1, 100000, true),
  ('CFXUSDT', 25, 'altcoin', 100, 10000000, true),
  ('BICOUSDT', 25, 'altcoin', 10, 1000000, true),
  ('AGLDUSDT', 25, 'lowcap', 1, 100000, true),
  ('RAREUSDT', 25, 'lowcap', 10, 1000000, true),
  
  -- Fan tokens
  ('LAZIOUSDT', 25, 'lowcap', 1, 100000, true),
  ('SANTOSUSDT', 25, 'lowcap', 1, 10000, true),
  ('MCUSDT', 25, 'lowcap', 10, 1000000, true),
  ('POWRUSDT', 25, 'lowcap', 10, 1000000, true),
  ('VGXUSDT', 25, 'lowcap', 10, 1000000, true),
  ('NOAIUSDT', 25, 'lowcap', 100, 10000000, true),
  ('VITEUSDT', 25, 'lowcap', 100, 10000000, true),
  ('TVKUSDT', 25, 'lowcap', 100, 10000000, true),
  ('PSGUSDT', 25, 'lowcap', 1, 10000, true),
  ('CITYUSDT', 25, 'lowcap', 1, 10000, true),
  ('MBLUSDT', 25, 'lowcap', 1000, 10000000, true),
  ('JUVUSDT', 25, 'lowcap', 1, 10000, true),
  ('ACMUSDT', 25, 'lowcap', 1, 10000, true),
  ('ASRUSDT', 25, 'lowcap', 1, 10000, true),
  ('ATMUSDT', 25, 'lowcap', 1, 10000, true),
  ('BARUSDT', 25, 'lowcap', 1, 10000, true),
  ('OGUSDT', 25, 'lowcap', 1, 10000, true),
  ('PORTOUSDT', 25, 'lowcap', 1, 10000, true),
  ('ALPINEUSDT', 25, 'lowcap', 1, 10000, true),
  ('WHALEUSDT', 25, 'lowcap', 1, 100000, true),
  ('NEXOUSDT', 25, 'altcoin', 1, 100000, true),
  
  -- Additional stablecoins
  ('USDCUSDT', 25, 'major', 1, 1000000, true)
  
ON CONFLICT (pair) DO NOTHING;

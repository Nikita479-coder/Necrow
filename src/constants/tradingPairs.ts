export interface TradingPair {
  symbol: string;
  name: string;
  type: 'crypto' | 'forex' | 'stock' | 'commodity';
}

export const TOP_CRYPTO_PAIRS: TradingPair[] = [
  { symbol: 'BTCUSDT', name: 'Bitcoin', type: 'crypto' },
  { symbol: 'ETHUSDT', name: 'Ethereum', type: 'crypto' },
  { symbol: 'BNBUSDT', name: 'BNB', type: 'crypto' },
  { symbol: 'SOLUSDT', name: 'Solana', type: 'crypto' },
  { symbol: 'XRPUSDT', name: 'Ripple', type: 'crypto' },
  { symbol: 'ADAUSDT', name: 'Cardano', type: 'crypto' },
  { symbol: 'AVAXUSDT', name: 'Avalanche', type: 'crypto' },
  { symbol: 'DOTUSDT', name: 'Polkadot', type: 'crypto' },
  { symbol: 'MATICUSDT', name: 'Polygon', type: 'crypto' },
  { symbol: 'LTCUSDT', name: 'Litecoin', type: 'crypto' },
];

export const ALL_CRYPTO_PAIRS: string[] = [
  'BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'SOL/USDT', 'XRP/USDT',
  'ADA/USDT', 'AVAX/USDT', 'DOT/USDT', 'MATIC/USDT', 'LTC/USDT',
  'DOGE/USDT', 'SHIB/USDT', 'LINK/USDT', 'ATOM/USDT', 'UNI/USDT',
  'XLM/USDT', 'TRX/USDT', 'NEAR/USDT', 'FTM/USDT', 'ALGO/USDT',
  'VET/USDT', 'ICP/USDT', 'FIL/USDT', 'APT/USDT', 'ARB/USDT',
  'OP/USDT', 'INJ/USDT', 'SUI/USDT', 'TIA/USDT', 'SEI/USDT',
  'PEPE/USDT', 'WIF/USDT', 'BONK/USDT', 'FLOKI/USDT', 'MEME/USDT',
  'AAVE/USDT', 'MKR/USDT', 'CRV/USDT', 'SNX/USDT', 'COMP/USDT',
  'LDO/USDT', 'RPL/USDT', 'GMX/USDT', 'DYDX/USDT', 'JUP/USDT',
  'SAND/USDT', 'MANA/USDT', 'AXS/USDT', 'GALA/USDT', 'IMX/USDT',
  'APE/USDT', 'ENJ/USDT', 'BLUR/USDT', 'ILV/USDT', 'MAGIC/USDT',
  'RNDR/USDT', 'FET/USDT', 'AGIX/USDT', 'WLD/USDT', 'ARKM/USDT',
  'TAO/USDT', 'OCEAN/USDT', 'AI/USDT', 'NMR/USDT', 'GRT/USDT',
  'STX/USDT', 'CFX/USDT', 'ENS/USDT', 'QNT/USDT', 'HBAR/USDT',
  'EOS/USDT', 'XTZ/USDT', 'THETA/USDT', 'NEO/USDT', 'EGLD/USDT',
  'KAVA/USDT', 'ROSE/USDT', 'ZIL/USDT', 'IOTA/USDT', 'ONE/USDT',
  'FLOW/USDT', 'MINA/USDT', 'KSM/USDT', 'ZEC/USDT', 'DASH/USDT',
  'ETC/USDT', 'BCH/USDT', 'XMR/USDT', 'CAKE/USDT', 'SUSHI/USDT',
  'YFI/USDT', 'BAL/USDT', 'PERP/USDT', 'PENDLE/USDT', 'RUNE/USDT',
  'ORDI/USDT', 'SATS/USDT', '1000SATS/USDT', 'RATS/USDT', 'PIXEL/USDT',
  'STRK/USDT', 'PYTH/USDT', 'JTO/USDT', 'BOME/USDT', 'W/USDT',
  'ENA/USDT', 'ETHFI/USDT', 'REZ/USDT', 'NOT/USDT', 'IO/USDT',
  'ZK/USDT', 'LISTA/USDT', 'ZRO/USDT', 'BLAST/USDT', 'DOGS/USDT',
  'TON/USDT', 'RENDER/USDT', 'KAS/USDT', 'JASMY/USDT', 'CHZ/USDT',
];

export const CFD_INSTRUMENTS: TradingPair[] = [
  // Forex
  { symbol: 'EUR/USD', name: 'Euro / US Dollar', type: 'forex' },
  { symbol: 'GBP/USD', name: 'British Pound / US Dollar', type: 'forex' },
  { symbol: 'USD/JPY', name: 'US Dollar / Japanese Yen', type: 'forex' },
  { symbol: 'AUD/USD', name: 'Australian Dollar / US Dollar', type: 'forex' },
  { symbol: 'USD/CAD', name: 'US Dollar / Canadian Dollar', type: 'forex' },

  // Stocks
  { symbol: 'AAPL', name: 'Apple Inc.', type: 'stock' },
  { symbol: 'GOOGL', name: 'Alphabet Inc.', type: 'stock' },
  { symbol: 'MSFT', name: 'Microsoft Corporation', type: 'stock' },
  { symbol: 'TSLA', name: 'Tesla Inc.', type: 'stock' },
  { symbol: 'AMZN', name: 'Amazon.com Inc.', type: 'stock' },

  // Commodities
  { symbol: 'XAUUSD', name: 'Gold', type: 'commodity' },
  { symbol: 'XAU/USD', name: 'Gold', type: 'commodity' },
  { symbol: 'XAGUSD', name: 'Silver', type: 'commodity' },
  { symbol: 'XAG/USD', name: 'Silver', type: 'commodity' },
  { symbol: 'XPTUSD', name: 'Platinum', type: 'commodity' },
  { symbol: 'XPT/USD', name: 'Platinum', type: 'commodity' },
  { symbol: 'XPDUSD', name: 'Palladium', type: 'commodity' },
  { symbol: 'XPD/USD', name: 'Palladium', type: 'commodity' },
  { symbol: 'WTICOUSD', name: 'WTI Crude Oil', type: 'commodity' },
  { symbol: 'WTI/USD', name: 'WTI Crude Oil', type: 'commodity' },
  { symbol: 'WTICO/USD', name: 'WTI Crude Oil', type: 'commodity' },
  { symbol: 'BCOUSD', name: 'Brent Crude Oil', type: 'commodity' },
  { symbol: 'Brent Crude', name: 'Brent Crude Oil', type: 'commodity' },
  { symbol: 'NATGASUSD', name: 'Natural Gas', type: 'commodity' },
  { symbol: 'NATGAS/USD', name: 'Natural Gas', type: 'commodity' },
  { symbol: 'Natural Gas', name: 'Natural Gas', type: 'commodity' },
  { symbol: 'CORNUSD', name: 'Corn', type: 'commodity' },
  { symbol: 'SOYBNUSD', name: 'Soybean', type: 'commodity' },
  { symbol: 'Soybean', name: 'Soybean', type: 'commodity' },
];

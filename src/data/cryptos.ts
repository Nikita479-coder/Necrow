export interface CryptoToken {
  symbol: string;
  name: string;
  price: number;
  change24h: number;
  volume24h: number;
  marketCap: number;
  icon: string;
  categories: string[];
  isNew?: boolean;
  isAlpha?: boolean;
}

export const hotTokens = [
  { symbol: 'BNB', name: 'BNB', price: 1090, change24h: 1.73, icon: '🟡' },
  { symbol: 'BTC', name: 'Bitcoin', price: 106730, change24h: 0.11, icon: '₿' },
  { symbol: 'ETH', name: 'Ethereum', price: 3880, change24h: 1.88, icon: '⟠' },
];

export const newTokens = [
  { symbol: 'ZBT', name: 'ZBT', price: 0.3416, change24h: -19.45, icon: '🔵' },
  { symbol: 'YB', name: 'YB', price: 0.476, change24h: -2.32, icon: '⚪' },
  { symbol: 'ENSO', name: 'ENSO', price: 1.87, change24h: 0.27, icon: '⚫' },
];

export const topGainers = [
  { symbol: 'TOWNS', name: 'TOWNS', price: 0.01298, change24h: 28.64, icon: '🟣' },
  { symbol: 'C', name: 'C', price: 0.1228, change24h: 20.51, icon: '❄️' },
  { symbol: 'MITO', name: 'MITO', price: 0.12795, change24h: 16.21, icon: '🟣' },
];

export const topVolume = [
  { symbol: 'BTC', name: 'Bitcoin', price: 106730, change24h: 0.11, icon: '₿' },
  { symbol: 'ETH', name: 'Ethereum', price: 3880, change24h: 1.88, icon: '⟠' },
  { symbol: 'SOL', name: 'Solana', price: 185.46, change24h: 1.05, icon: '◎' },
];

const generateRandomChange = () => (Math.random() * 20 - 10);
const generateRandomVolume = (min: number, max: number) => Math.random() * (max - min) + min;

export const allTokens: CryptoToken[] = [
  { symbol: 'BTC/USDT', name: 'Bitcoin', price: 106735.80, change24h: 0.11, volume24h: 44190000000, marketCap: 2120000000000, icon: '₿', categories: ['layer1', 'payments'] },
  { symbol: 'ETH/USDT', name: 'Ethereum', price: 3887.92, change24h: 1.88, volume24h: 27550000000, marketCap: 469190000000, icon: '⟠', categories: ['layer1'] },
  { symbol: 'BNB/USDT', name: 'BNB', price: 1090, change24h: 1.73, volume24h: 2340000000, marketCap: 157000000000, icon: '🟡', categories: ['bnbchain', 'layer1'] },
  { symbol: 'SOL/USDT', name: 'Solana', price: 185.46, change24h: 1.05, volume24h: 4560000000, marketCap: 92300000000, icon: '◎', categories: ['solana', 'layer1'] },
  { symbol: 'XRP/USDT', name: 'Ripple', price: 2.47, change24h: -1.23, volume24h: 8900000000, marketCap: 145000000000, icon: '◯', categories: ['payments'] },
  { symbol: 'ADA/USDT', name: 'Cardano', price: 0.89, change24h: 2.31, volume24h: 1200000000, marketCap: 31500000000, icon: '🔵', categories: ['layer1'] },
  { symbol: 'AVAX/USDT', name: 'Avalanche', price: 35.67, change24h: -1.45, volume24h: 680000000, marketCap: 15300000000, icon: '🔺', categories: ['layer1'] },
  { symbol: 'DOT/USDT', name: 'Polkadot', price: 6.42, change24h: 1.89, volume24h: 450000000, marketCap: 9800000000, icon: '⚫', categories: ['layer1'] },
  { symbol: 'MATIC/USDT', name: 'Polygon', price: 0.43, change24h: 3.12, volume24h: 890000000, marketCap: 4200000000, icon: '🟣', categories: ['layer2'] },
  { symbol: 'LTC/USDT', name: 'Litecoin', price: 102.45, change24h: 0.78, volume24h: 950000000, marketCap: 7600000000, icon: 'Ł', categories: ['payments'] },

  { symbol: 'LINK/USDT', name: 'Chainlink', price: 22.15, change24h: 4.23, volume24h: 820000000, marketCap: 14100000000, icon: '🔗', categories: ['ai'] },
  { symbol: 'UNI/USDT', name: 'Uniswap', price: 11.23, change24h: 2.87, volume24h: 320000000, marketCap: 8500000000, icon: '🦄', categories: ['layer2'], isAlpha: true },
  { symbol: 'ATOM/USDT', name: 'Cosmos', price: 7.89, change24h: 1.34, volume24h: 280000000, marketCap: 3100000000, icon: '⚛️', categories: ['layer1'] },
  { symbol: 'ETC/USDT', name: 'Ethereum Classic', price: 26.34, change24h: -0.92, volume24h: 420000000, marketCap: 3900000000, icon: '⟠', categories: ['layer1'] },
  { symbol: 'DOGE/USDT', name: 'Dogecoin', price: 0.32, change24h: -0.65, volume24h: 2100000000, marketCap: 47200000000, icon: '🐕', categories: ['meme', 'payments'] },
  { symbol: 'SHIB/USDT', name: 'Shiba Inu', price: 0.00002456, change24h: 5.67, volume24h: 890000000, marketCap: 14500000000, icon: '🐕', categories: ['meme'] },
  { symbol: 'TRX/USDT', name: 'TRON', price: 0.24, change24h: 1.45, volume24h: 650000000, marketCap: 21200000000, icon: '⚡', categories: ['layer1'] },
  { symbol: 'BCH/USDT', name: 'Bitcoin Cash', price: 478.90, change24h: -1.23, volume24h: 320000000, marketCap: 9500000000, icon: '₿', categories: ['payments'] },
  { symbol: 'NEAR/USDT', name: 'NEAR Protocol', price: 5.67, change24h: 3.45, volume24h: 290000000, marketCap: 6200000000, icon: '◆', categories: ['layer1'] },
  { symbol: 'APT/USDT', name: 'Aptos', price: 12.34, change24h: 2.11, volume24h: 180000000, marketCap: 5800000000, icon: '🔷', categories: ['layer1'], isNew: true },

  { symbol: 'ARB/USDT', name: 'Arbitrum', price: 1.89, change24h: 4.56, volume24h: 350000000, marketCap: 7100000000, icon: '🔵', categories: ['layer2'] },
  { symbol: 'OP/USDT', name: 'Optimism', price: 3.45, change24h: 2.34, volume24h: 210000000, marketCap: 4200000000, icon: '🔴', categories: ['layer2'] },
  { symbol: 'FTM/USDT', name: 'Fantom', price: 0.67, change24h: -2.11, volume24h: 180000000, marketCap: 1900000000, icon: '👻', categories: ['layer1'] },
  { symbol: 'ALGO/USDT', name: 'Algorand', price: 0.34, change24h: 1.78, volume24h: 120000000, marketCap: 2800000000, icon: '▲', categories: ['layer1'] },
  { symbol: 'VET/USDT', name: 'VeChain', price: 0.045, change24h: 3.21, volume24h: 95000000, marketCap: 3300000000, icon: '✓', categories: ['layer1'] },
  { symbol: 'ICP/USDT', name: 'Internet Computer', price: 12.67, change24h: -0.89, volume24h: 110000000, marketCap: 5900000000, icon: '∞', categories: ['layer1'] },
  { symbol: 'FIL/USDT', name: 'Filecoin', price: 6.78, change24h: 2.45, volume24h: 150000000, marketCap: 3200000000, icon: '🗄️', categories: ['layer1'] },
  { symbol: 'HBAR/USDT', name: 'Hedera', price: 0.087, change24h: 1.56, volume24h: 125000000, marketCap: 3100000000, icon: 'ℏ', categories: ['layer1'] },
  { symbol: 'AAVE/USDT', name: 'Aave', price: 245.60, change24h: 3.89, volume24h: 95000000, marketCap: 3600000000, icon: '👻', categories: ['layer2'] },
  { symbol: 'MKR/USDT', name: 'Maker', price: 2340.50, change24h: 1.23, volume24h: 65000000, marketCap: 2300000000, icon: '🟢', categories: ['layer2'] },

  { symbol: 'PEPE/USDT', name: 'Pepe', price: 0.000012, change24h: 12.34, volume24h: 580000000, marketCap: 5100000000, icon: '🐸', categories: ['meme'] },
  { symbol: 'WIF/USDT', name: 'dogwifhat', price: 2.87, change24h: 8.92, volume24h: 420000000, marketCap: 2800000000, icon: '🐕', categories: ['meme', 'solana'], isNew: true },
  { symbol: 'BONK/USDT', name: 'Bonk', price: 0.000034, change24h: 6.78, volume24h: 310000000, marketCap: 2200000000, icon: '🐕', categories: ['meme', 'solana'] },
  { symbol: 'FLOKI/USDT', name: 'Floki', price: 0.00019, change24h: 4.56, volume24h: 180000000, marketCap: 1800000000, icon: '🐕', categories: ['meme'] },
  { symbol: 'BABYDOGE/USDT', name: 'Baby Doge Coin', price: 0.0000000034, change24h: 3.21, volume24h: 95000000, marketCap: 1200000000, icon: '🐶', categories: ['meme'] },

  { symbol: 'SAND/USDT', name: 'The Sandbox', price: 0.56, change24h: 2.34, volume24h: 140000000, marketCap: 1200000000, icon: '🏖️', categories: ['metaverse', 'gaming'] },
  { symbol: 'MANA/USDT', name: 'Decentraland', price: 0.67, change24h: 1.89, volume24h: 110000000, marketCap: 1300000000, icon: '🎮', categories: ['metaverse', 'gaming'] },
  { symbol: 'AXS/USDT', name: 'Axie Infinity', price: 8.90, change24h: -1.23, volume24h: 85000000, marketCap: 1100000000, icon: '🎮', categories: ['gaming', 'metaverse'] },
  { symbol: 'GALA/USDT', name: 'Gala', price: 0.045, change24h: 2.67, volume24h: 95000000, marketCap: 780000000, icon: '🎮', categories: ['gaming'] },
  { symbol: 'ENJ/USDT', name: 'Enjin Coin', price: 0.34, change24h: 1.45, volume24h: 65000000, marketCap: 580000000, icon: '🎮', categories: ['gaming'] },

  { symbol: 'FET/USDT', name: 'Fetch.ai', price: 1.45, change24h: 5.67, volume24h: 125000000, marketCap: 1200000000, icon: '🤖', categories: ['ai'] },
  { symbol: 'RENDER/USDT', name: 'Render', price: 8.90, change24h: 4.23, volume24h: 95000000, marketCap: 3400000000, icon: '🎨', categories: ['ai'] },
  { symbol: 'AGIX/USDT', name: 'SingularityNET', price: 0.67, change24h: 3.45, volume24h: 75000000, marketCap: 850000000, icon: '🤖', categories: ['ai'] },
  { symbol: 'OCEAN/USDT', name: 'Ocean Protocol', price: 0.89, change24h: 2.89, volume24h: 65000000, marketCap: 620000000, icon: '🌊', categories: ['ai'] },
  { symbol: 'GRT/USDT', name: 'The Graph', price: 0.23, change24h: 1.67, volume24h: 110000000, marketCap: 2200000000, icon: '📊', categories: ['ai'] },

  { symbol: 'XLM/USDT', name: 'Stellar', price: 0.13, change24h: 2.11, volume24h: 180000000, marketCap: 3700000000, icon: '⭐', categories: ['payments'] },
  { symbol: 'XMR/USDT', name: 'Monero', price: 187.50, change24h: -0.78, volume24h: 95000000, marketCap: 3400000000, icon: 'Ɱ', categories: ['payments'] },
  { symbol: 'DASH/USDT', name: 'Dash', price: 34.67, change24h: 1.23, volume24h: 45000000, marketCap: 390000000, icon: '💳', categories: ['payments'] },
  { symbol: 'ZEC/USDT', name: 'Zcash', price: 45.80, change24h: 0.89, volume24h: 55000000, marketCap: 720000000, icon: '🛡️', categories: ['payments'] },

  { symbol: 'CAKE/USDT', name: 'PancakeSwap', price: 3.45, change24h: 2.34, volume24h: 75000000, marketCap: 890000000, icon: '🥞', categories: ['bnbchain'] },
  { symbol: 'BSV/USDT', name: 'Bitcoin SV', price: 67.80, change24h: -1.45, volume24h: 85000000, marketCap: 1340000000, icon: '₿', categories: ['bnbchain'] },

  { symbol: 'JUP/USDT', name: 'Jupiter', price: 1.23, change24h: 7.89, volume24h: 210000000, marketCap: 1600000000, icon: '♃', categories: ['solana'], isNew: true },
  { symbol: 'RAY/USDT', name: 'Raydium', price: 4.56, change24h: 5.43, volume24h: 150000000, marketCap: 1100000000, icon: '☀️', categories: ['solana'] },
  { symbol: 'ORCA/USDT', name: 'Orca', price: 2.34, change24h: 3.21, volume24h: 65000000, marketCap: 420000000, icon: '🐋', categories: ['solana'] },

  { symbol: 'IMX/USDT', name: 'Immutable X', price: 2.67, change24h: 4.12, volume24h: 95000000, marketCap: 1800000000, icon: '⚔️', categories: ['layer2', 'gaming'] },
  { symbol: 'LRC/USDT', name: 'Loopring', price: 0.45, change24h: 2.78, volume24h: 75000000, marketCap: 580000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'METIS/USDT', name: 'Metis', price: 67.80, change24h: 1.89, volume24h: 45000000, marketCap: 790000000, icon: '🔷', categories: ['layer2'] },

  { symbol: 'INJ/USDT', name: 'Injective', price: 34.50, change24h: 3.67, volume24h: 125000000, marketCap: 3200000000, icon: '💉', categories: ['layer1'] },
  { symbol: 'SEI/USDT', name: 'Sei', price: 0.67, change24h: 5.23, volume24h: 180000000, marketCap: 1900000000, icon: '⚡', categories: ['layer1'], isNew: true },
  { symbol: 'SUI/USDT', name: 'Sui', price: 1.89, change24h: 6.78, volume24h: 210000000, marketCap: 5200000000, icon: '💧', categories: ['layer1'], isNew: true },
  { symbol: 'TIA/USDT', name: 'Celestia', price: 12.34, change24h: 4.56, volume24h: 150000000, marketCap: 2100000000, icon: '🌟', categories: ['layer1'], isNew: true },
  { symbol: 'STRK/USDT', name: 'Starknet', price: 1.56, change24h: 3.89, volume24h: 95000000, marketCap: 1200000000, icon: '⚡', categories: ['layer2'], isNew: true },

  { symbol: 'RUNE/USDT', name: 'THORChain', price: 4.56, change24h: 2.34, volume24h: 75000000, marketCap: 1400000000, icon: 'ᚱ', categories: ['layer1'] },
  { symbol: 'KAVA/USDT', name: 'Kava', price: 0.89, change24h: 1.67, volume24h: 45000000, marketCap: 890000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'OSMO/USDT', name: 'Osmosis', price: 0.78, change24h: 2.11, volume24h: 35000000, marketCap: 620000000, icon: '🌌', categories: ['layer1'] },
  { symbol: 'JUNO/USDT', name: 'Juno', price: 0.56, change24h: 1.45, volume24h: 25000000, marketCap: 180000000, icon: '⚛️', categories: ['layer1'] },

  { symbol: 'STX/USDT', name: 'Stacks', price: 1.89, change24h: 3.56, volume24h: 85000000, marketCap: 2800000000, icon: '📚', categories: ['layer2'] },
  { symbol: 'FLOW/USDT', name: 'Flow', price: 1.23, change24h: 2.11, volume24h: 65000000, marketCap: 1300000000, icon: '🌊', categories: ['layer1'] },
  { symbol: 'EGLD/USDT', name: 'MultiversX', price: 56.70, change24h: 1.89, volume24h: 45000000, marketCap: 1200000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'THETA/USDT', name: 'Theta Network', price: 1.45, change24h: 2.34, volume24h: 55000000, marketCap: 1450000000, icon: '📺', categories: ['layer1'] },

  { symbol: 'CHZ/USDT', name: 'Chiliz', price: 0.12, change24h: 3.45, volume24h: 95000000, marketCap: 1100000000, icon: '🌶️', categories: ['gaming'] },
  { symbol: 'MAGIC/USDT', name: 'Magic', price: 0.89, change24h: 4.23, volume24h: 45000000, marketCap: 290000000, icon: '🎩', categories: ['gaming'] },
  { symbol: 'PRIME/USDT', name: 'Echelon Prime', price: 12.34, change24h: 2.78, volume24h: 35000000, marketCap: 420000000, icon: '👑', categories: ['gaming'], isNew: true },
  { symbol: 'BLUR/USDT', name: 'Blur', price: 0.45, change24h: 1.89, volume24h: 65000000, marketCap: 680000000, icon: '🎨', categories: ['layer2'] },

  { symbol: 'CRV/USDT', name: 'Curve DAO', price: 0.67, change24h: 2.34, volume24h: 85000000, marketCap: 890000000, icon: '📈', categories: ['layer2'] },
  { symbol: 'SUSHI/USDT', name: 'SushiSwap', price: 1.23, change24h: 1.67, volume24h: 45000000, marketCap: 320000000, icon: '🍣', categories: ['layer2'] },
  { symbol: 'COMP/USDT', name: 'Compound', price: 67.80, change24h: 2.11, volume24h: 35000000, marketCap: 590000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'YFI/USDT', name: 'yearn.finance', price: 8900.50, change24h: 1.45, volume24h: 25000000, marketCap: 320000000, icon: '💎', categories: ['layer2'] },

  { symbol: 'SNX/USDT', name: 'Synthetix', price: 3.45, change24h: 2.78, volume24h: 55000000, marketCap: 1100000000, icon: '⚡', categories: ['layer2'] },
  { symbol: '1INCH/USDT', name: '1inch', price: 0.45, change24h: 3.21, volume24h: 65000000, marketCap: 670000000, icon: '🦄', categories: ['layer2'] },
  { symbol: 'BAL/USDT', name: 'Balancer', price: 3.67, change24h: 1.89, volume24h: 35000000, marketCap: 290000000, icon: '⚖️', categories: ['layer2'] },

  { symbol: 'MINA/USDT', name: 'Mina Protocol', price: 0.89, change24h: 2.45, volume24h: 45000000, marketCap: 920000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'ROSE/USDT', name: 'Oasis Network', price: 0.12, change24h: 3.67, volume24h: 55000000, marketCap: 780000000, icon: '🌹', categories: ['layer1'] },
  { symbol: 'ZIL/USDT', name: 'Zilliqa', price: 0.034, change24h: 1.23, volume24h: 35000000, marketCap: 690000000, icon: '⚡', categories: ['layer1'] },
  { symbol: 'ONE/USDT', name: 'Harmony', price: 0.023, change24h: 2.11, volume24h: 25000000, marketCap: 310000000, icon: '🔷', categories: ['layer1'] },

  { symbol: 'WAVES/USDT', name: 'Waves', price: 2.34, change24h: 1.78, volume24h: 45000000, marketCap: 240000000, icon: '🌊', categories: ['layer1'] },
  { symbol: 'KSM/USDT', name: 'Kusama', price: 34.50, change24h: 2.34, volume24h: 35000000, marketCap: 340000000, icon: '🐦', categories: ['layer1'] },
  { symbol: 'ZRX/USDT', name: '0x Protocol', price: 0.56, change24h: 1.45, volume24h: 45000000, marketCap: 470000000, icon: '0️⃣', categories: ['layer2'] },
  { symbol: 'BAT/USDT', name: 'Basic Attention', price: 0.23, change24h: 2.67, volume24h: 55000000, marketCap: 340000000, icon: '🦇', categories: ['payments'] },

  { symbol: 'ENS/USDT', name: 'Ethereum Name Service', price: 23.45, change24h: 3.12, volume24h: 65000000, marketCap: 720000000, icon: '🌐', categories: ['layer2'] },
  { symbol: 'LDO/USDT', name: 'Lido DAO', price: 2.34, change24h: 2.89, volume24h: 85000000, marketCap: 2100000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'RPL/USDT', name: 'Rocket Pool', price: 34.60, change24h: 1.67, volume24h: 25000000, marketCap: 680000000, icon: '🚀', categories: ['layer2'] },

  { symbol: 'APE/USDT', name: 'ApeCoin', price: 1.89, change24h: 4.56, volume24h: 125000000, marketCap: 890000000, icon: '🦍', categories: ['metaverse', 'gaming'] },
  { symbol: 'GMT/USDT', name: 'STEPN', price: 0.34, change24h: 2.11, volume24h: 75000000, marketCap: 210000000, icon: '👟', categories: ['gaming'] },
  { symbol: 'ILV/USDT', name: 'Illuvium', price: 89.50, change24h: 1.89, volume24h: 25000000, marketCap: 180000000, icon: '🎮', categories: ['gaming', 'metaverse'] },

  { symbol: 'XTZ/USDT', name: 'Tezos', price: 1.12, change24h: 2.45, volume24h: 65000000, marketCap: 1100000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'EOS/USDT', name: 'EOS', price: 0.89, change24h: 1.78, volume24h: 95000000, marketCap: 1000000000, icon: '◆', categories: ['layer1'] },
  { symbol: 'IOTA/USDT', name: 'IOTA', price: 0.23, change24h: 3.21, volume24h: 45000000, marketCap: 640000000, icon: 'ι', categories: ['layer1'] },
  { symbol: 'NEO/USDT', name: 'Neo', price: 12.34, change24h: 1.67, volume24h: 55000000, marketCap: 870000000, icon: '🟢', categories: ['layer1'] },

  { symbol: 'QTUM/USDT', name: 'Qtum', price: 3.45, change24h: 2.11, volume24h: 35000000, marketCap: 360000000, icon: '◆', categories: ['layer1'] },
  { symbol: 'ICX/USDT', name: 'ICON', price: 0.34, change24h: 1.89, volume24h: 25000000, marketCap: 240000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'ONT/USDT', name: 'Ontology', price: 0.23, change24h: 2.45, volume24h: 35000000, marketCap: 190000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'ZEN/USDT', name: 'Horizen', price: 12.34, change24h: 1.23, volume24h: 15000000, marketCap: 180000000, icon: '💎', categories: ['layer1'] },

  { symbol: 'IOTX/USDT', name: 'IoTeX', price: 0.045, change24h: 3.67, volume24h: 45000000, marketCap: 420000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'RVN/USDT', name: 'Ravencoin', price: 0.023, change24h: 2.34, volume24h: 25000000, marketCap: 330000000, icon: '🦅', categories: ['layer1'] },
  { symbol: 'SC/USDT', name: 'Siacoin', price: 0.0056, change24h: 1.89, volume24h: 15000000, marketCap: 290000000, icon: '💾', categories: ['layer1'] },
  { symbol: 'STORJ/USDT', name: 'Storj', price: 0.67, change24h: 2.11, volume24h: 25000000, marketCap: 180000000, icon: '💾', categories: ['layer1'] },

  { symbol: 'AR/USDT', name: 'Arweave', price: 12.34, change24h: 3.45, volume24h: 65000000, marketCap: 810000000, icon: '🗄️', categories: ['layer1'] },
  { symbol: 'ANKR/USDT', name: 'Ankr', price: 0.045, change24h: 2.67, volume24h: 45000000, marketCap: 450000000, icon: '⚓', categories: ['layer1'] },
  { symbol: 'CELO/USDT', name: 'Celo', price: 0.78, change24h: 1.89, volume24h: 35000000, marketCap: 390000000, icon: '💚', categories: ['layer1'] },
  { symbol: 'SKL/USDT', name: 'SKALE', price: 0.067, change24h: 2.45, volume24h: 25000000, marketCap: 270000000, icon: '🔷', categories: ['layer2'] },

  { symbol: 'MASK/USDT', name: 'Mask Network', price: 3.45, change24h: 1.67, volume24h: 35000000, marketCap: 340000000, icon: '🎭', categories: ['layer2'] },
  { symbol: 'AUDIO/USDT', name: 'Audius', price: 0.23, change24h: 2.89, volume24h: 45000000, marketCap: 290000000, icon: '🎵', categories: ['layer1'] },
  { symbol: 'AMP/USDT', name: 'Amp', price: 0.0056, change24h: 3.12, volume24h: 35000000, marketCap: 240000000, icon: '⚡', categories: ['payments'] },
  { symbol: 'CVC/USDT', name: 'Civic', price: 0.12, change24h: 1.45, volume24h: 15000000, marketCap: 120000000, icon: '🆔', categories: ['layer1'] },

  { symbol: 'OMG/USDT', name: 'OMG Network', price: 0.89, change24h: 2.34, volume24h: 25000000, marketCap: 180000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'BAND/USDT', name: 'Band Protocol', price: 1.45, change24h: 1.78, volume24h: 35000000, marketCap: 220000000, icon: '🎵', categories: ['ai'] },
  { symbol: 'NKN/USDT', name: 'NKN', price: 0.12, change24h: 2.11, volume24h: 15000000, marketCap: 95000000, icon: '🌐', categories: ['layer1'] },
  { symbol: 'CTSI/USDT', name: 'Cartesi', price: 0.34, change24h: 3.45, volume24h: 25000000, marketCap: 130000000, icon: '🔷', categories: ['layer2'] },

  { symbol: 'WOO/USDT', name: 'WOO Network', price: 0.23, change24h: 2.67, volume24h: 45000000, marketCap: 290000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'PEOPLE/USDT', name: 'ConstitutionDAO', price: 0.045, change24h: 4.56, volume24h: 65000000, marketCap: 210000000, icon: '👥', categories: ['meme'] },
  { symbol: 'JOE/USDT', name: 'Trader Joe', price: 0.56, change24h: 2.11, volume24h: 25000000, marketCap: 180000000, icon: '🍵', categories: ['layer1'] },
  { symbol: 'CVX/USDT', name: 'Convex Finance', price: 3.45, change24h: 1.89, volume24h: 35000000, marketCap: 390000000, icon: '🔷', categories: ['layer2'] },

  { symbol: 'SPELL/USDT', name: 'Spell Token', price: 0.00089, change24h: 3.21, volume24h: 45000000, marketCap: 180000000, icon: '✨', categories: ['layer2'] },
  { symbol: 'DYDX/USDT', name: 'dYdX', price: 2.34, change24h: 2.45, volume24h: 65000000, marketCap: 560000000, icon: '📊', categories: ['layer2'] },
  { symbol: 'LOOKS/USDT', name: 'LooksRare', price: 0.12, change24h: 1.67, volume24h: 15000000, marketCap: 85000000, icon: '👀', categories: ['layer2'] },
  { symbol: 'API3/USDT', name: 'API3', price: 1.89, change24h: 2.89, volume24h: 25000000, marketCap: 180000000, icon: '🔌', categories: ['ai'] },

  { symbol: 'T/USDT', name: 'Threshold', price: 0.034, change24h: 1.45, volume24h: 25000000, marketCap: 340000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'GLM/USDT', name: 'Golem', price: 0.45, change24h: 2.34, volume24h: 35000000, marketCap: 450000000, icon: '🤖', categories: ['ai'] },
  { symbol: 'PAXG/USDT', name: 'PAX Gold', price: 2100.50, change24h: 0.12, volume24h: 15000000, marketCap: 290000000, icon: '🥇', categories: ['rwa'] },
  { symbol: 'MCO2/USDT', name: 'Moss Carbon Credit', price: 1.23, change24h: 1.89, volume24h: 5000000, marketCap: 45000000, icon: '🌱', categories: ['rwa'] },

  { symbol: 'RBN/USDT', name: 'Ribbon Finance', price: 0.56, change24h: 2.11, volume24h: 15000000, marketCap: 95000000, icon: '🎀', categories: ['layer2'] },
  { symbol: 'BNT/USDT', name: 'Bancor', price: 0.67, change24h: 1.67, volume24h: 25000000, marketCap: 180000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'PERP/USDT', name: 'Perpetual Protocol', price: 0.89, change24h: 2.89, volume24h: 35000000, marketCap: 220000000, icon: '♾️', categories: ['layer2'] },
  { symbol: 'ALCX/USDT', name: 'Alchemix', price: 23.45, change24h: 3.45, volume24h: 15000000, marketCap: 95000000, icon: '⚗️', categories: ['layer2'] },

  { symbol: 'TRB/USDT', name: 'Tellor', price: 67.80, change24h: 4.56, volume24h: 25000000, marketCap: 180000000, icon: '🔷', categories: ['ai'] },
  { symbol: 'BADGER/USDT', name: 'Badger DAO', price: 4.56, change24h: 2.11, volume24h: 15000000, marketCap: 120000000, icon: '🦡', categories: ['layer2'] },
  { symbol: 'SLP/USDT', name: 'Smooth Love Potion', price: 0.0034, change24h: 1.89, volume24h: 25000000, marketCap: 140000000, icon: '💕', categories: ['gaming'] },
  { symbol: 'PLA/USDT', name: 'PlayDapp', price: 0.45, change24h: 2.67, volume24h: 15000000, marketCap: 95000000, icon: '🎮', categories: ['gaming'] },

  { symbol: 'BOBA/USDT', name: 'Boba Network', price: 0.23, change24h: 1.45, volume24h: 25000000, marketCap: 130000000, icon: '🧋', categories: ['layer2'] },
  { symbol: 'MPL/USDT', name: 'Maple', price: 12.34, change24h: 2.89, volume24h: 15000000, marketCap: 85000000, icon: '🍁', categories: ['layer2'] },
  { symbol: 'TRIBE/USDT', name: 'Tribe', price: 0.34, change24h: 2.34, volume24h: 25000000, marketCap: 120000000, icon: '🏛️', categories: ['layer2'] },

  { symbol: 'FXS/USDT', name: 'Frax Share', price: 8.90, change24h: 3.12, volume24h: 35000000, marketCap: 680000000, icon: '💎', categories: ['layer2'] },
  { symbol: 'POLS/USDT', name: 'Polkastarter', price: 0.56, change24h: 2.45, volume24h: 15000000, marketCap: 95000000, icon: '🚀', categories: ['launchpool'] },
  { symbol: 'DAO/USDT', name: 'DAO Maker', price: 1.23, change24h: 1.89, volume24h: 25000000, marketCap: 140000000, icon: '🏗️', categories: ['launchpool'] },
  { symbol: 'C98/USDT', name: 'Coin98', price: 0.34, change24h: 2.67, volume24h: 35000000, marketCap: 210000000, icon: '🔷', categories: ['layer1'] },

  { symbol: 'ACA/USDT', name: 'Acala', price: 0.12, change24h: 1.45, volume24h: 15000000, marketCap: 95000000, icon: '🔺', categories: ['layer1'] },
  { symbol: 'MOVR/USDT', name: 'Moonriver', price: 12.34, change24h: 2.89, volume24h: 25000000, marketCap: 180000000, icon: '🌙', categories: ['layer1'] },
  { symbol: 'SYN/USDT', name: 'Synapse', price: 0.67, change24h: 1.67, volume24h: 35000000, marketCap: 220000000, icon: '🔗', categories: ['layer2'] },
  { symbol: 'DPI/USDT', name: 'DeFi Pulse Index', price: 89.50, change24h: 2.11, volume24h: 15000000, marketCap: 95000000, icon: '📊', categories: ['layer2'] },

  { symbol: 'ALPACA/USDT', name: 'Alpaca Finance', price: 0.34, change24h: 2.34, volume24h: 15000000, marketCap: 75000000, icon: '🦙', categories: ['bnbchain'] },
  { symbol: 'AUTO/USDT', name: 'Auto', price: 45.60, change24h: 1.89, volume24h: 5000000, marketCap: 35000000, icon: '🚗', categories: ['bnbchain'] },
  { symbol: 'BETA/USDT', name: 'Beta Finance', price: 0.12, change24h: 2.67, volume24h: 15000000, marketCap: 65000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'JASMY/USDT', name: 'JasmyCoin', price: 0.0089, change24h: 3.45, volume24h: 45000000, marketCap: 420000000, icon: '🔷', categories: ['layer1'] },

  { symbol: 'HIGH/USDT', name: 'Highstreet', price: 1.89, change24h: 2.11, volume24h: 25000000, marketCap: 95000000, icon: '🏙️', categories: ['metaverse', 'gaming'] },
  { symbol: 'VOXEL/USDT', name: 'Voxies', price: 0.23, change24h: 1.67, volume24h: 15000000, marketCap: 75000000, icon: '🎮', categories: ['gaming', 'metaverse'] },
  { symbol: 'TLM/USDT', name: 'Alien Worlds', price: 0.023, change24h: 2.89, volume24h: 35000000, marketCap: 95000000, icon: '👽', categories: ['gaming', 'metaverse'] },
  { symbol: 'ALICE/USDT', name: 'My Neighbor Alice', price: 1.45, change24h: 1.45, volume24h: 15000000, marketCap: 85000000, icon: '🏰', categories: ['gaming', 'metaverse'] },

  { symbol: 'BLZ/USDT', name: 'Bluzelle', price: 0.12, change24h: 2.34, volume24h: 15000000, marketCap: 65000000, icon: '💎', categories: ['layer1'] },
  { symbol: 'REQ/USDT', name: 'Request', price: 0.089, change24h: 1.89, volume24h: 25000000, marketCap: 95000000, icon: '💳', categories: ['payments'] },
  { symbol: 'MTL/USDT', name: 'Metal', price: 1.23, change24h: 2.67, volume24h: 15000000, marketCap: 85000000, icon: '⚙️', categories: ['payments'] },
  { symbol: 'DENT/USDT', name: 'Dent', price: 0.0012, change24h: 3.12, volume24h: 25000000, marketCap: 120000000, icon: '📱', categories: ['layer1'] },

  { symbol: 'KNC/USDT', name: 'Kyber Network', price: 0.89, change24h: 2.11, volume24h: 35000000, marketCap: 180000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'RLC/USDT', name: 'iExec RLC', price: 1.67, change24h: 1.67, volume24h: 25000000, marketCap: 140000000, icon: '☁️', categories: ['ai'] },
  { symbol: 'MLN/USDT', name: 'Enzyme', price: 23.45, change24h: 2.89, volume24h: 15000000, marketCap: 95000000, icon: '💎', categories: ['layer2'] },
  { symbol: 'OGN/USDT', name: 'Origin Protocol', price: 0.12, change24h: 1.45, volume24h: 25000000, marketCap: 85000000, icon: '🔷', categories: ['layer2'] },

  { symbol: 'POLY/USDT', name: 'Polymath', price: 0.23, change24h: 2.34, volume24h: 15000000, marketCap: 75000000, icon: '🔷', categories: ['rwa'] },
  { symbol: 'DATA/USDT', name: 'Streamr', price: 0.045, change24h: 1.89, volume24h: 25000000, marketCap: 95000000, icon: '💧', categories: ['ai'] },
  { symbol: 'HARD/USDT', name: 'HARD Protocol', price: 0.12, change24h: 2.67, volume24h: 15000000, marketCap: 65000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'WIN/USDT', name: 'WINkLink', price: 0.00012, change24h: 3.45, volume24h: 45000000, marketCap: 120000000, icon: '🎰', categories: ['gaming'] },

  { symbol: 'SUN/USDT', name: 'Sun Token', price: 0.0089, change24h: 2.11, volume24h: 25000000, marketCap: 95000000, icon: '☀️', categories: ['layer1'] },
  { symbol: 'BAKE/USDT', name: 'BakeryToken', price: 0.34, change24h: 1.67, volume24h: 35000000, marketCap: 85000000, icon: '🍰', categories: ['bnbchain'] },
  { symbol: 'BURGER/USDT', name: 'BurgerSwap', price: 0.56, change24h: 2.89, volume24h: 15000000, marketCap: 45000000, icon: '🍔', categories: ['bnbchain'] },
  { symbol: 'SFP/USDT', name: 'SafePal', price: 0.67, change24h: 1.45, volume24h: 25000000, marketCap: 95000000, icon: '🔐', categories: ['bnbchain'] },

  { symbol: 'DEXE/USDT', name: 'DeXe', price: 8.90, change24h: 2.34, volume24h: 15000000, marketCap: 75000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'ELF/USDT', name: 'aelf', price: 0.45, change24h: 1.89, volume24h: 25000000, marketCap: 95000000, icon: '🧝', categories: ['layer1'] },
  { symbol: 'GTC/USDT', name: 'Gitcoin', price: 1.23, change24h: 2.67, volume24h: 35000000, marketCap: 85000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'POND/USDT', name: 'Marlin', price: 0.023, change24h: 1.45, volume24h: 15000000, marketCap: 65000000, icon: '🔷', categories: ['layer1'] },

  { symbol: 'DEGO/USDT', name: 'Dego Finance', price: 2.34, change24h: 2.11, volume24h: 15000000, marketCap: 45000000, icon: '🎨', categories: ['layer2'] },
  { symbol: 'FORTH/USDT', name: 'Ampleforth Governance', price: 4.56, change24h: 1.67, volume24h: 15000000, marketCap: 55000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'QUICK/USDT', name: 'QuickSwap', price: 56.70, change24h: 2.89, volume24h: 25000000, marketCap: 95000000, icon: '⚡', categories: ['layer2'] },
  { symbol: 'TKO/USDT', name: 'Tokocrypto', price: 0.45, change24h: 1.45, volume24h: 35000000, marketCap: 95000000, icon: '🔷', categories: ['bnbchain'] },

  { symbol: 'PUNDIX/USDT', name: 'Pundi X', price: 0.67, change24h: 2.34, volume24h: 25000000, marketCap: 160000000, icon: '💳', categories: ['payments'] },
  { symbol: 'GODS/USDT', name: 'Gods Unchained', price: 0.34, change24h: 1.89, volume24h: 15000000, marketCap: 65000000, icon: '🎴', categories: ['gaming'] },
  { symbol: 'REEF/USDT', name: 'Reef', price: 0.0023, change24h: 2.67, volume24h: 25000000, marketCap: 95000000, icon: '🪸', categories: ['layer1'] },

  { symbol: 'OXT/USDT', name: 'Orchid', price: 0.12, change24h: 1.45, volume24h: 15000000, marketCap: 85000000, icon: '🌸', categories: ['layer1'] },
  { symbol: 'AUCTION/USDT', name: 'Bounce Token', price: 12.34, change24h: 2.11, volume24h: 15000000, marketCap: 65000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'PYR/USDT', name: 'Vulcan Forged', price: 4.56, change24h: 1.89, volume24h: 25000000, marketCap: 95000000, icon: '🔥', categories: ['gaming', 'metaverse'] },
  { symbol: 'SUPER/USDT', name: 'SuperFarm', price: 0.23, change24h: 2.67, volume24h: 15000000, marketCap: 75000000, icon: '🎮', categories: ['gaming'] },

  { symbol: 'UFT/USDT', name: 'UniLend', price: 0.45, change24h: 1.45, volume24h: 15000000, marketCap: 45000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'ACH/USDT', name: 'Alchemy Pay', price: 0.023, change24h: 2.34, volume24h: 35000000, marketCap: 140000000, icon: '💳', categories: ['payments'] },
  { symbol: 'ERN/USDT', name: 'Ethernity Chain', price: 1.89, change24h: 1.67, volume24h: 15000000, marketCap: 65000000, icon: '🔷', categories: ['gaming'] },
  { symbol: 'CFX/USDT', name: 'Conflux', price: 0.12, change24h: 2.89, volume24h: 45000000, marketCap: 580000000, icon: '🔷', categories: ['layer1'] },

  { symbol: 'BICO/USDT', name: 'Biconomy', price: 0.34, change24h: 2.11, volume24h: 25000000, marketCap: 95000000, icon: '🔷', categories: ['layer2'] },
  { symbol: 'AGLD/USDT', name: 'Adventure Gold', price: 0.89, change24h: 1.89, volume24h: 15000000, marketCap: 75000000, icon: '🎮', categories: ['gaming', 'metaverse'] },
  { symbol: 'RARE/USDT', name: 'SuperRare', price: 0.12, change24h: 2.45, volume24h: 15000000, marketCap: 85000000, icon: '🎨', categories: ['layer2'] },

  { symbol: 'LAZIO/USDT', name: 'Lazio Fan Token', price: 2.34, change24h: 1.23, volume24h: 15000000, marketCap: 65000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'SANTOS/USDT', name: 'Santos FC Fan Token', price: 4.56, change24h: 2.11, volume24h: 15000000, marketCap: 55000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'MC/USDT', name: 'Merit Circle', price: 0.45, change24h: 1.89, volume24h: 25000000, marketCap: 95000000, icon: '🎮', categories: ['gaming'] },
  { symbol: 'POWR/USDT', name: 'Powerledger', price: 0.23, change24h: 2.67, volume24h: 15000000, marketCap: 120000000, icon: '⚡', categories: ['layer1'] },

  { symbol: 'VGX/USDT', name: 'Voyager Token', price: 0.12, change24h: 1.45, volume24h: 15000000, marketCap: 65000000, icon: '🚀', categories: ['payments'] },
  { symbol: 'NOIA/USDT', name: 'Syntropy', price: 0.089, change24h: 2.34, volume24h: 15000000, marketCap: 45000000, icon: '🌐', categories: ['layer1'] },
  { symbol: 'VITE/USDT', name: 'Vite', price: 0.023, change24h: 1.67, volume24h: 15000000, marketCap: 55000000, icon: '🔷', categories: ['layer1'] },
  { symbol: 'TVK/USDT', name: 'Terra Virtua Kolect', price: 0.034, change24h: 2.11, volume24h: 15000000, marketCap: 45000000, icon: '🎨', categories: ['gaming', 'metaverse'] },

  { symbol: 'PSG/USDT', name: 'Paris Saint-Germain', price: 3.45, change24h: 1.89, volume24h: 15000000, marketCap: 65000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'CITY/USDT', name: 'Manchester City FC', price: 4.56, change24h: 2.45, volume24h: 15000000, marketCap: 55000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'MBL/USDT', name: 'MovieBloc', price: 0.0045, change24h: 1.67, volume24h: 15000000, marketCap: 65000000, icon: '🎬', categories: ['layer1'] },
  { symbol: 'JUV/USDT', name: 'Juventus Fan Token', price: 2.34, change24h: 1.23, volume24h: 15000000, marketCap: 45000000, icon: '⚽', categories: ['gaming'] },

  { symbol: 'ACM/USDT', name: 'AC Milan Fan Token', price: 2.89, change24h: 2.11, volume24h: 15000000, marketCap: 55000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'ASR/USDT', name: 'AS Roma Fan Token', price: 2.67, change24h: 1.89, volume24h: 15000000, marketCap: 45000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'ATM/USDT', name: 'Atletico Madrid', price: 3.12, change24h: 1.45, volume24h: 15000000, marketCap: 55000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'BAR/USDT', name: 'FC Barcelona Fan Token', price: 2.89, change24h: 2.34, volume24h: 15000000, marketCap: 65000000, icon: '⚽', categories: ['gaming'] },

  { symbol: 'OG/USDT', name: 'OG Fan Token', price: 5.67, change24h: 1.67, volume24h: 15000000, marketCap: 55000000, icon: '🎮', categories: ['gaming'] },
  { symbol: 'PORTO/USDT', name: 'FC Porto Fan Token', price: 2.45, change24h: 1.89, volume24h: 15000000, marketCap: 45000000, icon: '⚽', categories: ['gaming'] },
  { symbol: 'ALPINE/USDT', name: 'Alpine F1 Team', price: 1.89, change24h: 2.11, volume24h: 15000000, marketCap: 35000000, icon: '🏎️', categories: ['gaming'], isNew: true },
  { symbol: 'BULL/USDT', name: 'Bull Token', price: 0.012, change24h: 3.45, volume24h: 5000000, marketCap: 25000000, icon: '🐂', categories: ['meme'], isNew: true },

  { symbol: 'WHALE/USDT', name: 'Whale', price: 0.89, change24h: 2.34, volume24h: 15000000, marketCap: 45000000, icon: '🐋', categories: ['meme'] },
  { symbol: 'CULT/USDT', name: 'Cult DAO', price: 0.0000045, change24h: 4.56, volume24h: 25000000, marketCap: 95000000, icon: '🔷', categories: ['meme'], isNew: true },
  { symbol: 'GMBL/USDT', name: 'GMBL', price: 0.0012, change24h: 1.89, volume24h: 5000000, marketCap: 15000000, icon: '🎰', categories: ['gaming'], isNew: true },
  { symbol: 'NEXO/USDT', name: 'Nexo', price: 1.23, change24h: 1.67, volume24h: 45000000, marketCap: 680000000, icon: '🔷', categories: ['payments'] },
];

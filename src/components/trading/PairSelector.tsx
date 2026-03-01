import { useState, useRef, useEffect } from 'react';
import { ChevronDown, Search, Star } from 'lucide-react';
import CryptoIcon from '../CryptoIcon';
import { usePrices } from '../../hooks/usePrices';

interface PairSelectorProps {
  selectedPair: string;
  onPairChange: (pair: string) => void;
}

const TRADING_PAIRS = [
  { symbol: 'BTC', name: 'Bitcoin', category: 'Layer 1' },
  { symbol: 'ETH', name: 'Ethereum', category: 'Layer 1' },
  { symbol: 'BNB', name: 'BNB', category: 'Exchange' },
  { symbol: 'SOL', name: 'Solana', category: 'Layer 1' },
  { symbol: 'XRP', name: 'Ripple', category: 'Payment' },
  { symbol: 'ADA', name: 'Cardano', category: 'Layer 1' },
  { symbol: 'DOGE', name: 'Dogecoin', category: 'Meme' },
  { symbol: 'MATIC', name: 'Polygon', category: 'Layer 2' },
  { symbol: 'DOT', name: 'Polkadot', category: 'Layer 0' },
  { symbol: 'LTC', name: 'Litecoin', category: 'Payment' },
  { symbol: 'AVAX', name: 'Avalanche', category: 'Layer 1' },
  { symbol: 'LINK', name: 'Chainlink', category: 'Oracle' },
  { symbol: 'UNI', name: 'Uniswap', category: 'DeFi' },
  { symbol: 'ATOM', name: 'Cosmos', category: 'Layer 0' },
  { symbol: 'ALGO', name: 'Algorand', category: 'Layer 1' },
  { symbol: 'FTM', name: 'Fantom', category: 'Layer 1' },
  { symbol: 'NEAR', name: 'NEAR', category: 'Layer 1' },
  { symbol: 'APT', name: 'Aptos', category: 'Layer 1' },
  { symbol: 'ARB', name: 'Arbitrum', category: 'Layer 2' },
  { symbol: 'OP', name: 'Optimism', category: 'Layer 2' },
  { symbol: 'INJ', name: 'Injective', category: 'DeFi' },
  { symbol: 'SUI', name: 'Sui', category: 'Layer 1' },
  { symbol: 'TIA', name: 'Celestia', category: 'Modular' },
  { symbol: 'SEI', name: 'Sei', category: 'Layer 1' },
  { symbol: 'PEPE', name: 'Pepe', category: 'Meme' },
  { symbol: 'SHIB', name: 'Shiba Inu', category: 'Meme' },
  { symbol: 'TRX', name: 'Tron', category: 'Layer 1' },
  { symbol: 'TON', name: 'Toncoin', category: 'Layer 1' },
  { symbol: 'ICP', name: 'Internet Computer', category: 'Layer 1' },
  { symbol: 'VET', name: 'VeChain', category: 'Enterprise' },
  { symbol: 'FIL', name: 'Filecoin', category: 'Storage' },
  { symbol: 'HBAR', name: 'Hedera', category: 'Enterprise' },
  { symbol: 'STX', name: 'Stacks', category: 'Bitcoin L2' },
  { symbol: 'IMX', name: 'Immutable X', category: 'Gaming' },
  { symbol: 'RUNE', name: 'THORChain', category: 'DeFi' },
  { symbol: 'ETC', name: 'Ethereum Classic', category: 'Layer 1' },
  { symbol: 'BCH', name: 'Bitcoin Cash', category: 'Payment' },
  { symbol: 'XLM', name: 'Stellar', category: 'Payment' },
  { symbol: 'AAVE', name: 'Aave', category: 'DeFi' },
  { symbol: 'MKR', name: 'Maker', category: 'DeFi' },
  { symbol: 'CRV', name: 'Curve', category: 'DeFi' },
  { symbol: 'SUSHI', name: 'SushiSwap', category: 'DeFi' },
  { symbol: 'COMP', name: 'Compound', category: 'DeFi' },
  { symbol: 'SNX', name: 'Synthetix', category: 'DeFi' },
  { symbol: 'LDO', name: 'Lido DAO', category: 'DeFi' },
  { symbol: 'CAKE', name: 'PancakeSwap', category: 'DeFi' },
  { symbol: 'SAND', name: 'The Sandbox', category: 'Gaming' },
  { symbol: 'MANA', name: 'Decentraland', category: 'Gaming' },
  { symbol: 'AXS', name: 'Axie Infinity', category: 'Gaming' },
  { symbol: 'GALA', name: 'Gala', category: 'Gaming' },
  { symbol: 'ENJ', name: 'Enjin', category: 'Gaming' },
  { symbol: 'CHZ', name: 'Chiliz', category: 'Gaming' },
  { symbol: 'FET', name: 'Fetch.ai', category: 'AI' },
  { symbol: 'RENDER', name: 'Render', category: 'AI' },
  { symbol: 'AGIX', name: 'SingularityNET', category: 'AI' },
  { symbol: 'OCEAN', name: 'Ocean Protocol', category: 'AI' },
  { symbol: 'GRT', name: 'The Graph', category: 'AI' },
  { symbol: 'XTZ', name: 'Tezos', category: 'Layer 1' },
  { symbol: 'EOS', name: 'EOS', category: 'Layer 1' },
  { symbol: 'THETA', name: 'Theta', category: 'Media' },
  { symbol: 'FLOW', name: 'Flow', category: 'Layer 1' },
  { symbol: 'EGLD', name: 'MultiversX', category: 'Layer 1' },
  { symbol: 'KAVA', name: 'Kava', category: 'DeFi' },
  { symbol: 'ZIL', name: 'Zilliqa', category: 'Layer 1' },
  { symbol: 'MINA', name: 'Mina', category: 'Layer 1' },
  { symbol: 'ROSE', name: 'Oasis', category: 'Privacy' },
  { symbol: 'AR', name: 'Arweave', category: 'Storage' },
  { symbol: 'ANKR', name: 'Ankr', category: 'Infrastructure' },
  { symbol: 'CELO', name: 'Celo', category: 'Layer 1' },
  { symbol: 'ZRX', name: '0x', category: 'DeFi' },
  { symbol: 'ENS', name: 'ENS', category: 'Infrastructure' },
  { symbol: 'MASK', name: 'Mask Network', category: 'Social' },
  { symbol: 'BLUR', name: 'Blur', category: 'NFT' },
  { symbol: 'LRC', name: 'Loopring', category: 'Layer 2' },
  { symbol: 'METIS', name: 'Metis', category: 'Layer 2' },
  { symbol: 'STRK', name: 'Starknet', category: 'Layer 2' },
  { symbol: 'WIF', name: 'dogwifhat', category: 'Meme' },
  { symbol: 'BONK', name: 'Bonk', category: 'Meme' },
  { symbol: 'FLOKI', name: 'Floki', category: 'Meme' },
  { symbol: 'JUP', name: 'Jupiter', category: 'DeFi' },
  { symbol: 'RAY', name: 'Raydium', category: 'DeFi' },
  { symbol: 'ORCA', name: 'Orca', category: 'DeFi' },
  { symbol: 'APE', name: 'ApeCoin', category: 'Gaming' },
  { symbol: 'GMT', name: 'STEPN', category: 'Gaming' },
  { symbol: 'MAGIC', name: 'Magic', category: 'Gaming' },
  { symbol: 'PRIME', name: 'Echelon Prime', category: 'Gaming' },
  { symbol: 'OSMO', name: 'Osmosis', category: 'DeFi' },
  { symbol: 'JUNO', name: 'Juno', category: 'Layer 1' },
  { symbol: 'KSM', name: 'Kusama', category: 'Layer 0' },
  { symbol: 'WAVES', name: 'Waves', category: 'Layer 1' },
  { symbol: 'ONE', name: 'Harmony', category: 'Layer 1' },
  { symbol: 'IOTA', name: 'IOTA', category: 'IoT' },
  { symbol: 'NEO', name: 'Neo', category: 'Layer 1' },
  { symbol: 'QTUM', name: 'Qtum', category: 'Layer 1' },
  { symbol: 'ICX', name: 'ICON', category: 'Layer 1' },
  { symbol: 'ONT', name: 'Ontology', category: 'Layer 1' },
  { symbol: 'ZEN', name: 'Horizen', category: 'Privacy' },
  { symbol: 'IOTX', name: 'IoTeX', category: 'IoT' },
  { symbol: 'RVN', name: 'Ravencoin', category: 'Layer 1' },
  { symbol: 'SC', name: 'Siacoin', category: 'Storage' },
  { symbol: 'STORJ', name: 'Storj', category: 'Storage' },
  { symbol: 'SKL', name: 'SKALE', category: 'Layer 2' },
  { symbol: 'AUDIO', name: 'Audius', category: 'Media' },
  { symbol: 'BAT', name: 'Basic Attention', category: 'Media' },
  { symbol: 'OMG', name: 'OMG Network', category: 'Layer 2' },
  { symbol: 'BAND', name: 'Band Protocol', category: 'Oracle' },
  { symbol: 'NKN', name: 'NKN', category: 'Infrastructure' },
  { symbol: 'CTSI', name: 'Cartesi', category: 'Layer 2' },
  { symbol: 'WOO', name: 'WOO Network', category: 'DeFi' },
  { symbol: 'CVX', name: 'Convex', category: 'DeFi' },
  { symbol: 'DYDX', name: 'dYdX', category: 'DeFi' },
  { symbol: 'API3', name: 'API3', category: 'Oracle' },
  { symbol: 'GLM', name: 'Golem', category: 'AI' },
  { symbol: 'BNT', name: 'Bancor', category: 'DeFi' },
  { symbol: 'PERP', name: 'Perpetual', category: 'DeFi' },
  { symbol: 'ALCX', name: 'Alchemix', category: 'DeFi' },
  { symbol: 'TRB', name: 'Tellor', category: 'Oracle' },
  { symbol: 'BADGER', name: 'Badger DAO', category: 'DeFi' },
  { symbol: 'BOBA', name: 'Boba Network', category: 'Layer 2' },
  { symbol: 'MPL', name: 'Maple', category: 'DeFi' },
  { symbol: 'FXS', name: 'Frax Share', category: 'DeFi' },
  { symbol: 'C98', name: 'Coin98', category: 'DeFi' },
  { symbol: 'ACA', name: 'Acala', category: 'DeFi' },
  { symbol: 'MOVR', name: 'Moonriver', category: 'Layer 1' },
  { symbol: 'SYN', name: 'Synapse', category: 'Bridge' },
  { symbol: 'JASMY', name: 'JasmyCoin', category: 'IoT' },
  { symbol: 'HIGH', name: 'Highstreet', category: 'Gaming' },
  { symbol: 'VOXEL', name: 'Voxies', category: 'Gaming' },
  { symbol: 'TLM', name: 'Alien Worlds', category: 'Gaming' },
  { symbol: 'ALICE', name: 'My Neighbor Alice', category: 'Gaming' },
  { symbol: 'BLZ', name: 'Bluzelle', category: 'Storage' },
  { symbol: 'KNC', name: 'Kyber Network', category: 'DeFi' },
  { symbol: 'RLC', name: 'iExec', category: 'Cloud' },
  { symbol: 'MLN', name: 'Enzyme', category: 'DeFi' },
  { symbol: 'OGN', name: 'Origin Protocol', category: 'DeFi' },
  { symbol: 'DATA', name: 'Streamr', category: 'Data' },
  { symbol: 'DEXE', name: 'DeXe', category: 'DeFi' },
  { symbol: 'ELF', name: 'aelf', category: 'Layer 1' },
  { symbol: 'GTC', name: 'Gitcoin', category: 'DAO' },
  { symbol: 'POND', name: 'Marlin', category: 'Infrastructure' },
  { symbol: 'QUICK', name: 'QuickSwap', category: 'DeFi' },
  { symbol: 'GODS', name: 'Gods Unchained', category: 'Gaming' },
  { symbol: 'REEF', name: 'Reef', category: 'DeFi' },
  { symbol: 'OXT', name: 'Orchid', category: 'Privacy' },
  { symbol: 'AUCTION', name: 'Bounce', category: 'DeFi' },
  { symbol: 'PYR', name: 'Vulcan Forged', category: 'Gaming' },
  { symbol: 'SUPER', name: 'SuperFarm', category: 'Gaming' },
  { symbol: 'UFT', name: 'UniLend', category: 'DeFi' },
  { symbol: 'ACH', name: 'Alchemy Pay', category: 'Payment' },
  { symbol: 'ERN', name: 'Ethernity Chain', category: 'NFT' },
  { symbol: 'CFX', name: 'Conflux', category: 'Layer 1' },
  { symbol: 'BICO', name: 'Biconomy', category: 'Infrastructure' },
  { symbol: 'AGLD', name: 'Adventure Gold', category: 'Gaming' },
  { symbol: 'RARE', name: 'SuperRare', category: 'NFT' },
  { symbol: 'MC', name: 'Merit Circle', category: 'Gaming' },
  { symbol: 'POWR', name: 'Powerledger', category: 'Energy' },
];

const CATEGORIES = ['All', 'Layer 1', 'Layer 2', 'DeFi', 'Meme', 'Gaming', 'AI', 'Layer 0', 'Oracle', 'Payment', 'Exchange', 'Enterprise', 'Storage', 'Bitcoin L2', 'Modular', 'Privacy', 'Infrastructure', 'NFT', 'Media', 'Social', 'Bridge', 'IoT', 'Cloud', 'Data', 'DAO', 'Energy'];

function PairSelector({ selectedPair, onPairChange }: PairSelectorProps) {
  const [showDropdown, setShowDropdown] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [favorites, setFavorites] = useState<string[]>(['BTC', 'ETH', 'SOL']);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const prices = usePrices();

  const selectedSymbol = selectedPair.replace('USDT', '');
  const selectedPairData = TRADING_PAIRS.find(p => p.symbol === selectedSymbol);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const toggleFavorite = (symbol: string) => {
    setFavorites(prev =>
      prev.includes(symbol)
        ? prev.filter(s => s !== symbol)
        : [...prev, symbol]
    );
  };

  const filteredPairs = TRADING_PAIRS.filter(pair => {
    const matchesSearch = pair.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         pair.name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = selectedCategory === 'All' || pair.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const favoritePairs = TRADING_PAIRS.filter(pair => favorites.includes(pair.symbol));

  const getPairPrice = (symbol: string) => {
    const priceData = prices.get(`${symbol}/USDT`);
    return priceData ? parseFloat(priceData.price) : 0;
  };

  const getPairChange = (symbol: string) => {
    const priceData = prices.get(`${symbol}/USDT`);
    return priceData ? priceData.change24h : 0;
  };

  const renderPairRow = (pair: typeof TRADING_PAIRS[0]) => {
    const price = getPairPrice(pair.symbol);
    const change = getPairChange(pair.symbol);
    const isFavorite = favorites.includes(pair.symbol);

    return (
      <div
        key={pair.symbol}
        className="flex items-center gap-3 px-3 py-2 hover:bg-[#2b2e35] cursor-pointer transition-colors"
        onClick={() => {
          onPairChange(pair.symbol + 'USDT');
          setShowDropdown(false);
        }}
      >
        <button
          onClick={(e) => {
            e.stopPropagation();
            toggleFavorite(pair.symbol);
          }}
          className="hover:scale-110 transition-transform"
        >
          <Star
            size={13}
            className={isFavorite ? 'fill-[#f0b90b] text-[#f0b90b]' : 'text-gray-700'}
          />
        </button>
        <CryptoIcon symbol={pair.symbol} size={18} />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="font-semibold text-xs">{pair.symbol}/USDT</span>
            <span className="text-[10px] text-gray-600 truncate">{pair.name}</span>
          </div>
        </div>
        <div className="text-right">
          <div className="text-xs font-medium text-white">{price > 0 ? price.toFixed(2) : '---'}</div>
          <div className={`text-[10px] font-medium ${change >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
            {change > 0 ? '+' : ''}{change.toFixed(2)}%
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        onClick={() => setShowDropdown(!showDropdown)}
        className="flex items-center gap-2 px-3 py-1.5 bg-[#2b2e35] hover:bg-[#31353d] rounded-md transition-colors"
      >
        <CryptoIcon symbol={selectedSymbol} size={20} />
        <div className="text-left">
          <div className="font-semibold text-sm">{selectedSymbol}/USDT</div>
          {selectedPairData && (
            <div className="text-[10px] text-gray-500">{selectedPairData.name}</div>
          )}
        </div>
        <ChevronDown className={`w-3.5 h-3.5 text-gray-500 transition-transform ${showDropdown ? 'rotate-180' : ''}`} />
      </button>

      {showDropdown && (
        <div className="absolute top-full left-0 mt-1 w-96 bg-[#0b0e11] border border-[#2b2e35] rounded-lg shadow-xl z-50">
          <div className="p-3 border-b border-[#2b2e35]">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-600" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search pairs..."
                className="w-full bg-[#2b2e35] border-none rounded-md pl-9 pr-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:ring-1 focus:ring-[#f0b90b]"
              />
            </div>
          </div>

          <div className="px-3 py-2 border-b border-[#2b2e35] overflow-x-auto">
            <div className="flex gap-1.5">
              {CATEGORIES.map(cat => (
                <button
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-2.5 py-1 text-[10px] rounded-md whitespace-nowrap transition-colors ${
                    selectedCategory === cat
                      ? 'bg-[#f0b90b] text-black font-semibold'
                      : 'bg-[#2b2e35] text-gray-500 hover:bg-[#31353d] hover:text-gray-400'
                  }`}
                >
                  {cat}
                </button>
              ))}
            </div>
          </div>

          <div className="max-h-96 overflow-y-auto">
            {favorites.length > 0 && searchQuery === '' && selectedCategory === 'All' && (
              <div>
                <div className="px-3 py-2 text-[10px] font-semibold text-gray-500 bg-[#0c0d0f]">
                  Favorites
                </div>
                {favoritePairs.map(renderPairRow)}
              </div>
            )}

            <div>
              {searchQuery === '' && selectedCategory === 'All' && favorites.length > 0 && (
                <div className="px-3 py-2 text-[10px] font-semibold text-gray-500 bg-[#0c0d0f]">
                  All Pairs
                </div>
              )}
              {filteredPairs.length > 0 ? (
                filteredPairs.map(renderPairRow)
              ) : (
                <div className="px-3 py-8 text-center text-sm text-gray-500">
                  No pairs found
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default PairSelector;

import { useState, useEffect, useRef } from 'react';
import Navbar from '../components/Navbar';
import TradingChart from '../components/trading/TradingChart';
import OrderBook from '../components/trading/OrderBook';
import VerticalTradingPanel from '../components/trading/VerticalTradingPanel';
import TickerBar from '../components/trading/TickerBar';
import FuturesPositionsPanel from '../components/trading/FuturesPositionsPanel';
import PairSelector from '../components/trading/PairSelector';
import PairTabs from '../components/trading/PairTabs';
import CryptoIcon from '../components/CryptoIcon';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { tpslMonitorService } from '../services/tpslMonitorService';
import { usePrices } from '../hooks/usePrices';
import { Star, ChevronDown, X, Search } from 'lucide-react';

type MobileTab = 'chart' | 'orderbook' | 'trades' | 'info' | 'data';

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
  { symbol: 'WIF', name: 'dogwifhat', category: 'Meme' },
  { symbol: 'BONK', name: 'Bonk', category: 'Meme' },
  { symbol: 'FLOKI', name: 'Floki', category: 'Meme' },
  { symbol: 'JUP', name: 'Jupiter', category: 'DeFi' },
  { symbol: 'RAY', name: 'Raydium', category: 'DeFi' },
  { symbol: 'APE', name: 'ApeCoin', category: 'Gaming' },
  { symbol: 'GMT', name: 'STEPN', category: 'Gaming' },
  { symbol: 'DYDX', name: 'dYdX', category: 'DeFi' },
];

function FuturesTrading() {
  const { user } = useAuth();
  const { navigationState } = useNavigation();
  const prices = usePrices();
  const initialPair = navigationState?.selectedPair || 'BTCUSDT';
  const [selectedPair, setSelectedPair] = useState(initialPair);
  const [openTabs, setOpenTabs] = useState<string[]>([initialPair]);
  const [mobileTab, setMobileTab] = useState<MobileTab>('chart');
  const [showMobileTradePanel, setShowMobileTradePanel] = useState(false);
  const [mobileTradeSide, setMobileTradeSide] = useState<'long' | 'short'>('long');
  const [showPairSelector, setShowPairSelector] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const mobileScrollRef = useRef<HTMLDivElement>(null);

  const baseCurrency = selectedPair.replace('USDT', '');
  const priceKey = `${baseCurrency}/USDT`;
  const priceData = prices.get(priceKey) || prices.get(baseCurrency) || prices.get(selectedPair);
  const currentPrice = priceData?.price || 0;
  const change24h = priceData?.change24h || 0;
  const high24h = priceData?.high24h || 0;
  const low24h = priceData?.low24h || 0;
  const volume24h = priceData?.volume24h || 0;

  useEffect(() => {
    const saved = localStorage.getItem('futureTradingTabs');
    if (saved) {
      try {
        const tabs = JSON.parse(saved);
        if (tabs.length > 0) {
          setOpenTabs(tabs);
        }
      } catch (e) {
        console.error('Failed to load tabs:', e);
      }
    }
  }, []);

  useEffect(() => {
    localStorage.setItem('futureTradingTabs', JSON.stringify(openTabs));
  }, [openTabs]);

  const handlePairChange = (pair: string) => {
    setSelectedPair(pair);
    if (!openTabs.includes(pair)) {
      setOpenTabs([...openTabs, pair]);
    }
    setShowPairSelector(false);
    setSearchQuery('');
  };

  useEffect(() => {
    if (navigationState?.selectedPair && navigationState.selectedPair !== selectedPair) {
      handlePairChange(navigationState.selectedPair);
    }
  }, [navigationState, selectedPair]);

  useEffect(() => {
    if (user) {
      tpslMonitorService.start(user.id);
    }

    return () => {
      tpslMonitorService.stop();
    };
  }, [user]);

  const handleRemoveTab = (pair: string) => {
    const newTabs = openTabs.filter(p => p !== pair);
    if (newTabs.length === 0) {
      newTabs.push('BTCUSDT');
    }
    setOpenTabs(newTabs);

    if (selectedPair === pair) {
      setSelectedPair(newTabs[0]);
    }
  };

  const handleMobileBuy = () => {
    setMobileTradeSide('long');
    setShowMobileTradePanel(true);
  };

  const handleMobileSell = () => {
    setMobileTradeSide('short');
    setShowMobileTradePanel(true);
  };

  const formatVolume = (vol: number) => {
    if (vol >= 1e9) return (vol / 1e9).toFixed(2) + 'B';
    if (vol >= 1e6) return (vol / 1e6).toFixed(2) + 'M';
    if (vol >= 1e3) return (vol / 1e3).toFixed(2) + 'K';
    return vol.toFixed(2);
  };

  const formatPrice = (price: number) => {
    if (price >= 1000) return price.toFixed(1);
    if (price >= 1) return price.toFixed(2);
    return price.toFixed(4);
  };

  const filteredPairs = TRADING_PAIRS.filter(pair =>
    pair.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
    pair.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const getPairPrice = (symbol: string) => {
    const pd = prices.get(`${symbol}/USDT`);
    return pd ? pd.price : 0;
  };

  const getPairChange = (symbol: string) => {
    const pd = prices.get(`${symbol}/USDT`);
    return pd ? pd.change24h : 0;
  };

  return (
    <div className="min-h-screen bg-[#0c0d0f] text-white flex flex-col">
      {/* Desktop Layout */}
      <div className="hidden lg:flex flex-col min-h-screen">
        <Navbar />
        <TickerBar selectedPair={selectedPair} onPairChange={handlePairChange} />

        <div className="flex-1 flex flex-col overflow-hidden min-h-0">
          <div className="flex border-b border-[#1e2329] bg-[#0b0e11]">
            <div className="flex-1 px-4 py-2 flex items-center gap-3">
              <PairSelector selectedPair={selectedPair} onPairChange={handlePairChange} />
              <PairTabs
                tabs={openTabs}
                selectedPair={selectedPair}
                onPairChange={setSelectedPair}
                onRemoveTab={handleRemoveTab}
              />
            </div>
          </div>

          <div className="flex-1 flex flex-col overflow-hidden min-h-0">
            <div className="flex-1 flex overflow-hidden min-h-0">
              <div className="flex-1 min-w-0 bg-[#131722]">
                <TradingChart pair={selectedPair} />
              </div>

              <div className="w-72 border-l border-[#1e2329] flex flex-col">
                <div className="flex-1 overflow-auto bg-[#0b0e11]">
                  <OrderBook pair={selectedPair} />
                </div>
              </div>

              <div className="w-80 border-l border-[#1e2329] overflow-hidden bg-[#0b0e11]">
                <VerticalTradingPanel pair={selectedPair} />
              </div>
            </div>

            <div className="border-t border-[#1e2329] flex-shrink-0 bg-[#0b0e11]" style={{ height: '280px' }}>
              <FuturesPositionsPanel />
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Layout - Binance Style */}
      <div className="lg:hidden flex flex-col h-screen">
        <Navbar />

        {/* Mobile Header with Pair Info */}
        <div className="bg-[#0b0e11] px-3 py-2 border-b border-[#2b2e35] flex-shrink-0">
          <div className="flex items-center justify-between">
            <button
              onClick={() => setShowPairSelector(true)}
              className="flex items-center gap-2"
            >
              <CryptoIcon symbol={baseCurrency} size={24} />
              <div>
                <div className="flex items-center gap-1">
                  <span className="text-white font-bold text-base">{baseCurrency}USDT</span>
                  <span className="text-[9px] text-gray-500 bg-[#2b2e35] px-1 rounded">Perp</span>
                  <ChevronDown className="w-4 h-4 text-gray-400" />
                </div>
              </div>
            </button>
            <div className="flex items-center gap-2">
              <div className="text-right">
                <div className={`text-lg font-bold ${change24h >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                  {formatPrice(currentPrice)}
                </div>
                <div className={`text-xs ${change24h >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                  {change24h >= 0 ? '+' : ''}{change24h.toFixed(2)}%
                </div>
              </div>
            </div>
          </div>

          {/* 24h Stats Row */}
          <div className="flex items-center gap-3 mt-2 text-[10px] overflow-x-auto scrollbar-hide">
            <div className="flex flex-col whitespace-nowrap">
              <span className="text-gray-500">24h High</span>
              <span className="text-white">{formatPrice(high24h)}</span>
            </div>
            <div className="flex flex-col whitespace-nowrap">
              <span className="text-gray-500">24h Low</span>
              <span className="text-white">{formatPrice(low24h)}</span>
            </div>
            <div className="flex flex-col whitespace-nowrap">
              <span className="text-gray-500">24h Vol({baseCurrency})</span>
              <span className="text-white">{formatVolume(volume24h)}</span>
            </div>
            <div className="flex flex-col whitespace-nowrap">
              <span className="text-gray-500">24h Vol(USDT)</span>
              <span className="text-white">{formatVolume(volume24h * currentPrice)}</span>
            </div>
          </div>
        </div>

        {/* Mobile Tab Navigation */}
        <div className="bg-[#0b0e11] border-b border-[#2b2e35] overflow-x-auto flex-shrink-0 scrollbar-hide">
          <div className="flex">
            {[
              { id: 'chart', label: 'Chart' },
              { id: 'orderbook', label: 'Order Book' },
              { id: 'trades', label: 'Trades' },
              { id: 'info', label: 'Coin Info' },
              { id: 'data', label: 'Trading Data' },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setMobileTab(tab.id as MobileTab)}
                className={`px-4 py-2.5 text-sm whitespace-nowrap border-b-2 transition-colors ${
                  mobileTab === tab.id
                    ? 'text-[#f0b90b] border-[#f0b90b]'
                    : 'text-gray-400 border-transparent hover:text-white'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Scrollable Content Area */}
        <div ref={mobileScrollRef} className="flex-1 overflow-y-auto bg-[#131722]">
          {mobileTab === 'chart' && (
            <>
              {/* Full Screen Chart */}
              <div className="h-[calc(100vh-280px)] min-h-[400px]">
                <TradingChart pair={selectedPair} />
              </div>
              {/* Positions Panel - scroll to see */}
              <div className="bg-[#0b0e11] border-t border-[#2b2e35]">
                <FuturesPositionsPanel />
              </div>
            </>
          )}

          {mobileTab === 'orderbook' && (
            <div className="min-h-full bg-[#0b0e11]">
              <OrderBook pair={selectedPair} />
            </div>
          )}

          {mobileTab === 'trades' && (
            <div className="p-4 bg-[#0b0e11] min-h-full">
              <div className="text-center text-gray-500 py-8">
                Recent trades will appear here
              </div>
            </div>
          )}

          {mobileTab === 'info' && (
            <div className="p-4 bg-[#0b0e11] min-h-full">
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol={baseCurrency} size={40} />
                  <div>
                    <div className="font-bold text-white">{baseCurrency}</div>
                    <div className="text-xs text-gray-500">Perpetual Contract</div>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div className="bg-[#1e2329] p-3 rounded">
                    <div className="text-gray-500 text-xs">Contract Type</div>
                    <div className="text-white">USDT-Margined</div>
                  </div>
                  <div className="bg-[#1e2329] p-3 rounded">
                    <div className="text-gray-500 text-xs">Settlement Asset</div>
                    <div className="text-white">USDT</div>
                  </div>
                  <div className="bg-[#1e2329] p-3 rounded">
                    <div className="text-gray-500 text-xs">Max Leverage</div>
                    <div className="text-white">125x</div>
                  </div>
                  <div className="bg-[#1e2329] p-3 rounded">
                    <div className="text-gray-500 text-xs">Min Order</div>
                    <div className="text-white">0.001 {baseCurrency}</div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {mobileTab === 'data' && (
            <div className="p-4 bg-[#0b0e11] min-h-full">
              <div className="space-y-3">
                <div className="flex justify-between py-2 border-b border-[#2b2e35]">
                  <span className="text-gray-500">Mark Price</span>
                  <span className="text-white">{formatPrice(currentPrice)}</span>
                </div>
                <div className="flex justify-between py-2 border-b border-[#2b2e35]">
                  <span className="text-gray-500">Index Price</span>
                  <span className="text-white">{formatPrice(currentPrice * 0.9999)}</span>
                </div>
                <div className="flex justify-between py-2 border-b border-[#2b2e35]">
                  <span className="text-gray-500">Funding Rate / Countdown</span>
                  <span className="text-[#0ecb81]">0.0100% / 03:45:21</span>
                </div>
                <div className="flex justify-between py-2 border-b border-[#2b2e35]">
                  <span className="text-gray-500">Open Interest</span>
                  <span className="text-white">{formatVolume(volume24h * 0.3)} USDT</span>
                </div>
                <div className="flex justify-between py-2 border-b border-[#2b2e35]">
                  <span className="text-gray-500">24h Volume</span>
                  <span className="text-white">{formatVolume(volume24h * currentPrice)} USDT</span>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Mobile Bottom Buy/Sell Bar - Fixed */}
        <div className="bg-[#0b0e11] border-t border-[#2b2e35] p-3 flex gap-3 flex-shrink-0 safe-area-bottom">
          <button
            onClick={handleMobileBuy}
            className="flex-1 bg-[#0ecb81] hover:bg-[#0ecb81]/90 text-white font-semibold py-3 rounded text-sm transition-colors"
          >
            Buy/Long
          </button>
          <button
            onClick={handleMobileSell}
            className="flex-1 bg-[#f6465d] hover:bg-[#f6465d]/90 text-white font-semibold py-3 rounded text-sm transition-colors"
          >
            Sell/Short
          </button>
        </div>
      </div>

      {/* Mobile Pair Selector Modal */}
      {showPairSelector && (
        <div className="lg:hidden fixed inset-0 z-50 bg-[#0b0e11]">
          <div className="flex flex-col h-full">
            {/* Header */}
            <div className="flex items-center justify-between p-4 border-b border-[#2b2e35]">
              <span className="font-semibold text-lg">Select Symbol</span>
              <button onClick={() => { setShowPairSelector(false); setSearchQuery(''); }}>
                <X className="w-6 h-6" />
              </button>
            </div>

            {/* Search */}
            <div className="p-3 border-b border-[#2b2e35]">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search symbol or name"
                  className="w-full bg-[#1e2329] rounded-lg pl-10 pr-4 py-2.5 text-sm focus:outline-none focus:ring-1 focus:ring-[#f0b90b]"
                  autoFocus
                />
              </div>
            </div>

            {/* Column Headers */}
            <div className="flex items-center px-4 py-2 text-xs text-gray-500 border-b border-[#2b2e35]">
              <div className="flex-1">Symbol</div>
              <div className="w-24 text-right">Last Price</div>
              <div className="w-20 text-right">24h %</div>
            </div>

            {/* Pairs List */}
            <div className="flex-1 overflow-y-auto">
              {filteredPairs.map((pair) => {
                const pairPrice = getPairPrice(pair.symbol);
                const pairChange = getPairChange(pair.symbol);

                return (
                  <button
                    key={pair.symbol}
                    onClick={() => handlePairChange(pair.symbol + 'USDT')}
                    className={`w-full flex items-center px-4 py-3 border-b border-[#1e2329] hover:bg-[#1e2329] transition-colors ${
                      selectedPair === pair.symbol + 'USDT' ? 'bg-[#1e2329]' : ''
                    }`}
                  >
                    <div className="flex items-center gap-3 flex-1">
                      <CryptoIcon symbol={pair.symbol} size={28} />
                      <div className="text-left">
                        <div className="font-semibold text-sm">{pair.symbol}USDT</div>
                        <div className="text-xs text-gray-500">{pair.name}</div>
                      </div>
                    </div>
                    <div className="w-24 text-right">
                      <div className="text-sm font-medium">{pairPrice > 0 ? formatPrice(pairPrice) : '---'}</div>
                    </div>
                    <div className="w-20 text-right">
                      <div className={`text-sm font-medium ${pairChange >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                        {pairChange >= 0 ? '+' : ''}{pairChange.toFixed(2)}%
                      </div>
                    </div>
                  </button>
                );
              })}
              {filteredPairs.length === 0 && (
                <div className="text-center text-gray-500 py-8">
                  No pairs found
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Mobile Trade Panel Slide-up */}
      {showMobileTradePanel && (
        <div className="lg:hidden fixed inset-0 z-50 bg-black/80" onClick={() => setShowMobileTradePanel(false)}>
          <div
            className="absolute bottom-0 left-0 right-0 bg-[#0b0e11] rounded-t-xl max-h-[90vh] overflow-hidden animate-slide-up"
            onClick={e => e.stopPropagation()}
          >
            <div className="flex items-center justify-between p-4 border-b border-[#2b2e35]">
              <div className="flex items-center gap-2">
                <CryptoIcon symbol={baseCurrency} size={24} />
                <span className="font-semibold">{baseCurrency}USDT</span>
                <span className="text-[10px] text-gray-500 bg-[#2b2e35] px-1.5 py-0.5 rounded">Perp</span>
              </div>
              <button onClick={() => setShowMobileTradePanel(false)}>
                <X className="w-6 h-6" />
              </button>
            </div>
            <div className="overflow-y-auto max-h-[calc(90vh-60px)]">
              <VerticalTradingPanel pair={selectedPair} initialSide={mobileTradeSide} />
            </div>
          </div>
        </div>
      )}

      <style>{`
        .safe-area-bottom {
          padding-bottom: max(12px, env(safe-area-inset-bottom));
        }

        .scrollbar-hide::-webkit-scrollbar {
          display: none;
        }

        .scrollbar-hide {
          -ms-overflow-style: none;
          scrollbar-width: none;
        }

        @keyframes slide-up {
          from {
            transform: translateY(100%);
          }
          to {
            transform: translateY(0);
          }
        }

        .animate-slide-up {
          animation: slide-up 0.3s ease-out;
        }
      `}</style>
    </div>
  );
}

export default FuturesTrading;

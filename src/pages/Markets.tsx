import Navbar from '../components/Navbar';
import TokenTable from '../components/TokenTable';
import TabNavigation from '../components/TabNavigation';
import CryptoIcon from '../components/CryptoIcon';
import { Search, Bell, Star } from 'lucide-react';
import { usePrices } from '../hooks/usePrices';
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

function Markets() {
  const prices = usePrices();
  const { user } = useAuth();
  const [viewMode, setViewMode] = useState('overview');
  const [activeTab, setActiveTab] = useState('cryptos');
  const [activeCategory, setActiveCategory] = useState('all');
  const [favorites, setFavorites] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (user) {
      loadFavorites();
    }
  }, [user]);

  const loadFavorites = async () => {
    if (!user) return;

    const { data, error } = await supabase
      .from('favorites')
      .select('crypto_symbol')
      .eq('user_id', user.id);

    if (data) {
      setFavorites(new Set(data.map(f => f.crypto_symbol)));
    }
  };

  const toggleFavorite = async (symbol: string) => {
    if (!user) return;

    const newFavorites = new Set(favorites);
    if (newFavorites.has(symbol)) {
      newFavorites.delete(symbol);
      await supabase
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('crypto_symbol', symbol);
    } else {
      newFavorites.add(symbol);
      await supabase
        .from('favorites')
        .insert({
          user_id: user.id,
          crypto_symbol: symbol
        });
    }
    setFavorites(newFavorites);
  };

  const getCryptoData = (symbol: string) => {
    const priceData = prices.get(symbol);
    return {
      price: priceData ? priceData.price : 0,
      change: priceData ? priceData.change24h : 0
    };
  };

  const bnbData = getCryptoData('BNB/USDT');
  const btcData = getCryptoData('BTC/USDT');
  const ethData = getCryptoData('ETH/USDT');
  const solData = getCryptoData('SOL/USDT');

  const hotCoins = [
    { symbol: 'BNB', name: 'BNB', price: bnbData.price || 1121.06, change: bnbData.change || 2.52 },
    { symbol: 'BTC', name: 'Bitcoin', price: btcData.price || 108481.75, change: btcData.change || 1.42 },
    { symbol: 'ETH', name: 'Ethereum', price: ethData.price || 3990.66, change: ethData.change || 3.04 }
  ];

  const newCoins = [
    { symbol: 'ZBT', name: 'ZBT', price: 0.3283, change: -9.16 },
    { symbol: 'YB', name: 'YB', price: 0.4441, change: -6.66 },
    { symbol: 'ENSO', name: 'ENSO', price: 1.87, change: -3.80 }
  ];

  const topGainers = [
    { symbol: 'MLN', name: 'MLN', price: 13.10, change: 149.05 },
    { symbol: 'ALCX', name: 'ALCX', price: 10.56, change: 42.90 },
    { symbol: 'TRU', name: 'TRU', price: 0.022, change: 20.22 }
  ];

  const topVolume = [
    { symbol: 'BTC', name: 'Bitcoin', price: btcData.price || 108481.75, change: btcData.change || 1.42 },
    { symbol: 'ETH', name: 'Ethereum', price: ethData.price || 3990.66, change: ethData.change || 3.04 },
    { symbol: 'SOL', name: 'Solana', price: solData.price || 191.51, change: solData.change || 3.27 }
  ];

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="max-w-[1600px] mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-6">
        <div className="flex items-center justify-between mb-4 sm:mb-6">
          <h1 className="text-xl sm:text-2xl md:text-3xl font-bold text-white">Overview</h1>
          <div className="flex items-center gap-2 sm:gap-4">
            <button className="text-gray-400 hover:text-white transition-colors p-2">
              <Search className="w-5 h-5" />
            </button>
            <button className="text-gray-400 hover:text-white transition-colors p-2">
              <Bell className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="flex gap-2 mb-4 sm:mb-6 overflow-x-auto pb-2 scrollbar-hide">
          <button
            onClick={() => setViewMode('overview')}
            className={`px-3 sm:px-4 py-2 rounded-lg font-medium whitespace-nowrap text-sm transition-colors ${
              viewMode === 'overview'
                ? 'bg-[#f0b90b] text-black'
                : 'bg-[#181a20] text-gray-300 hover:bg-[#2b3139]'
            }`}
          >
            Overview
          </button>
          <button
            onClick={() => setViewMode('trading-data')}
            className={`px-3 sm:px-4 py-2 rounded-lg font-medium whitespace-nowrap text-sm transition-colors ${
              viewMode === 'trading-data'
                ? 'bg-[#f0b90b] text-black'
                : 'bg-[#181a20] text-gray-300 hover:bg-[#2b3139]'
            }`}
          >
            Trading Data
          </button>
          <button
            onClick={() => setViewMode('ai-select')}
            className={`px-3 sm:px-4 py-2 rounded-lg font-medium whitespace-nowrap text-sm transition-colors ${
              viewMode === 'ai-select'
                ? 'bg-[#f0b90b] text-black'
                : 'bg-[#181a20] text-gray-300 hover:bg-[#2b3139]'
            }`}
          >
            AI Select
          </button>
          <button
            onClick={() => setViewMode('token-unlock')}
            className={`px-3 sm:px-4 py-2 rounded-lg font-medium whitespace-nowrap text-sm transition-colors ${
              viewMode === 'token-unlock'
                ? 'bg-[#f0b90b] text-black'
                : 'bg-[#181a20] text-gray-300 hover:bg-[#2b3139]'
            }`}
          >
            Token Unlock
          </button>
        </div>

        {viewMode === 'overview' && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6 sm:mb-8">
          <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-semibold">Hot</h3>
              <button
                onClick={() => {
                  setViewMode('overview');
                  setActiveTab('cryptos');
                  setActiveCategory('all');
                  document.getElementById('market-table')?.scrollIntoView({ behavior: 'smooth' });
                }}
                className="text-gray-400 text-sm hover:text-[#f0b90b] transition-colors"
              >
                More →
              </button>
            </div>
            <div className="space-y-3">
              {hotCoins.map((coin, idx) => (
                <div key={idx} className="flex items-center justify-between hover:bg-[#0b0e11] p-2 rounded cursor-pointer transition-colors">
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={coin.symbol} size={32} />
                    <div>
                      <div className="text-white font-semibold text-sm">{coin.symbol}</div>
                      <div className="text-gray-500 text-xs">${coin.price >= 1000 ? `${(coin.price / 1000).toFixed(2)}K` : coin.price.toFixed(4)}</div>
                    </div>
                  </div>
                  <div className={`text-sm font-semibold ${coin.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {coin.change >= 0 ? '+' : ''}{coin.change.toFixed(2)}%
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-semibold">New</h3>
              <button
                onClick={() => {
                  setViewMode('overview');
                  setActiveTab('new');
                  setActiveCategory('all');
                  document.getElementById('market-table')?.scrollIntoView({ behavior: 'smooth' });
                }}
                className="text-gray-400 text-sm hover:text-[#f0b90b] transition-colors"
              >
                More →
              </button>
            </div>
            <div className="space-y-3">
              {newCoins.map((coin, idx) => (
                <div key={idx} className="flex items-center justify-between hover:bg-[#0b0e11] p-2 rounded cursor-pointer transition-colors">
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={coin.symbol} size={32} />
                    <div>
                      <div className="text-white font-semibold text-sm">{coin.symbol}</div>
                      <div className="text-gray-500 text-xs">${coin.price.toFixed(4)}</div>
                    </div>
                  </div>
                  <div className={`text-sm font-semibold ${coin.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {coin.change >= 0 ? '+' : ''}{coin.change.toFixed(2)}%
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-semibold">Top Gainer</h3>
              <button
                onClick={() => {
                  setViewMode('overview');
                  setActiveTab('cryptos');
                  setActiveCategory('all');
                  document.getElementById('market-table')?.scrollIntoView({ behavior: 'smooth' });
                }}
                className="text-gray-400 text-sm hover:text-[#f0b90b] transition-colors"
              >
                More →
              </button>
            </div>
            <div className="space-y-3">
              {topGainers.map((coin, idx) => (
                <div key={idx} className="flex items-center justify-between hover:bg-[#0b0e11] p-2 rounded cursor-pointer transition-colors">
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={coin.symbol} size={32} />
                    <div>
                      <div className="text-white font-semibold text-sm">{coin.symbol}</div>
                      <div className="text-gray-500 text-xs">${coin.price.toFixed(2)}</div>
                    </div>
                  </div>
                  <div className="text-sm font-semibold text-emerald-400">
                    +{coin.change.toFixed(2)}%
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-semibold">Top Volume</h3>
              <button
                onClick={() => {
                  setViewMode('overview');
                  setActiveTab('cryptos');
                  setActiveCategory('all');
                  document.getElementById('market-table')?.scrollIntoView({ behavior: 'smooth' });
                }}
                className="text-gray-400 text-sm hover:text-[#f0b90b] transition-colors"
              >
                More →
              </button>
            </div>
            <div className="space-y-3">
              {topVolume.map((coin, idx) => (
                <div key={idx} className="flex items-center justify-between hover:bg-[#0b0e11] p-2 rounded cursor-pointer transition-colors">
                  <div className="flex items-center gap-3">
                    <CryptoIcon symbol={coin.symbol} size={32} />
                    <div>
                      <div className="text-white font-semibold text-sm">{coin.symbol}</div>
                      <div className="text-gray-500 text-xs">${coin.price >= 1000 ? `${(coin.price / 1000).toFixed(2)}K` : coin.price.toFixed(2)}</div>
                    </div>
                  </div>
                  <div className={`text-sm font-semibold ${coin.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {coin.change >= 0 ? '+' : ''}{coin.change.toFixed(2)}%
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
        )}

        {viewMode === 'trading-data' && (
        <div className="bg-[#181a20] rounded-xl border border-gray-800 p-6 mb-6">
          <h2 className="text-2xl font-bold text-white mb-6">Trading Data Analytics</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <h3 className="text-gray-400 text-sm mb-2">24h Trading Volume</h3>
              <p className="text-3xl font-bold text-white mb-1">$1.2B</p>
              <p className="text-emerald-400 text-sm">+12.3% vs yesterday</p>
            </div>
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <h3 className="text-gray-400 text-sm mb-2">Active Traders</h3>
              <p className="text-3xl font-bold text-white mb-1">7.1M</p>
              <p className="text-emerald-400 text-sm">+8.7% vs yesterday</p>
            </div>
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <h3 className="text-gray-400 text-sm mb-2">Total Users</h3>
              <p className="text-3xl font-bold text-white mb-1">7.14M</p>
              <p className="text-emerald-400 text-sm">+5.2% vs last month</p>
            </div>
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <h3 className="text-gray-400 text-sm mb-2">Total Assets</h3>
              <p className="text-3xl font-bold text-white mb-1">$1.5B</p>
              <p className="text-emerald-400 text-sm">+7.8% vs last month</p>
            </div>
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <h3 className="text-gray-400 text-sm mb-2">Buy/Sell Ratio</h3>
              <p className="text-3xl font-bold text-white mb-1">1.34</p>
              <p className="text-emerald-400 text-sm">More buying pressure</p>
            </div>
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <h3 className="text-gray-400 text-sm mb-2">Market Sentiment</h3>
              <p className="text-3xl font-bold text-emerald-400 mb-1">Bullish</p>
              <p className="text-gray-400 text-sm">68% positive signals</p>
            </div>
          </div>
        </div>
        )}

        {viewMode === 'ai-select' && (
        <div className="bg-[#181a20] rounded-xl border border-gray-800 p-6 mb-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-12 h-12 bg-gradient-to-br from-[#f0b90b] to-[#f8d12f] rounded-xl flex items-center justify-center">
              <span className="text-2xl">🤖</span>
            </div>
            <div>
              <h2 className="text-2xl font-bold text-white">AI-Powered Crypto Selection</h2>
              <p className="text-gray-400 text-sm">Machine learning algorithms analyze market trends to suggest top performers</p>
            </div>
          </div>
          <div className="space-y-4">
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800 hover:border-[#f0b90b] transition-colors cursor-pointer">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="BTC" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Bitcoin (BTC)</h3>
                    <p className="text-gray-400 text-sm">AI Confidence: 94%</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold text-lg">${btcData.price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</p>
                  <p className={`text-sm ${btcData.change >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>{btcData.change >= 0 ? '+' : ''}{btcData.change.toFixed(2)}%</p>
                </div>
              </div>
              <div className="flex gap-2 flex-wrap">
                <span className="bg-emerald-500/20 text-emerald-400 text-xs px-2 py-1 rounded">Strong Buy</span>
                <span className="bg-blue-500/20 text-blue-400 text-xs px-2 py-1 rounded">Low Volatility</span>
                <span className="bg-[#f0b90b]/20 text-[#f0b90b] text-xs px-2 py-1 rounded">High Volume</span>
              </div>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800 hover:border-[#f0b90b] transition-colors cursor-pointer">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="ETH" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Ethereum (ETH)</h3>
                    <p className="text-gray-400 text-sm">AI Confidence: 91%</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold text-lg">${ethData.price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</p>
                  <p className={`text-sm ${ethData.change >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>{ethData.change >= 0 ? '+' : ''}{ethData.change.toFixed(2)}%</p>
                </div>
              </div>
              <div className="flex gap-2 flex-wrap">
                <span className="bg-emerald-500/20 text-emerald-400 text-xs px-2 py-1 rounded">Buy</span>
                <span className="bg-[#f0b90b]/20 text-[#f0b90b] text-xs px-2 py-1 rounded">Accumulation Phase</span>
              </div>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800 hover:border-[#f0b90b] transition-colors cursor-pointer">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="SOL" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Solana (SOL)</h3>
                    <p className="text-gray-400 text-sm">AI Confidence: 87%</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold text-lg">${solData.price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</p>
                  <p className={`text-sm ${solData.change >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>{solData.change >= 0 ? '+' : ''}{solData.change.toFixed(2)}%</p>
                </div>
              </div>
              <div className="flex gap-2 flex-wrap">
                <span className="bg-emerald-500/20 text-emerald-400 text-xs px-2 py-1 rounded">Buy</span>
                <span className="bg-blue-500/20 text-blue-400 text-xs px-2 py-1 rounded">Growing Adoption</span>
              </div>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800 hover:border-[#f0b90b] transition-colors cursor-pointer">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="LINK" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Chainlink (LINK)</h3>
                    <p className="text-gray-400 text-sm">AI Confidence: 83%</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold text-lg">$22.15</p>
                  <p className="text-emerald-400 text-sm">+4.23%</p>
                </div>
              </div>
              <div className="flex gap-2 flex-wrap">
                <span className="bg-emerald-500/20 text-emerald-400 text-xs px-2 py-1 rounded">Moderate Buy</span>
                <span className="bg-blue-500/20 text-blue-400 text-xs px-2 py-1 rounded">AI Sector Leader</span>
              </div>
            </div>
          </div>
        </div>
        )}

        {viewMode === 'token-unlock' && (
        <div className="bg-[#181a20] rounded-xl border border-gray-800 p-6 mb-6">
          <h2 className="text-2xl font-bold text-white mb-4">Upcoming Token Unlocks</h2>
          <p className="text-gray-400 mb-6">Track scheduled token unlocks that may impact market prices</p>
          <div className="space-y-4">
            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="ARB" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Arbitrum (ARB)</h3>
                    <p className="text-gray-400 text-sm">Unlock Date: Dec 15, 2025</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold">92.65M tokens</p>
                  <p className="text-rose-400 text-sm">$19.46M value</p>
                </div>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-[#f0b90b] h-2 rounded-full" style={{ width: '56%' }}></div>
              </div>
              <p className="text-gray-400 text-xs mt-2">56.1% of total supply circulating | MCap: $1.18B</p>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="OP" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Optimism (OP)</h3>
                    <p className="text-gray-400 text-sm">Unlock Date: Dec 28, 2025</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold">31.34M tokens</p>
                  <p className="text-rose-400 text-sm">$9.85M value</p>
                </div>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-[#f0b90b] h-2 rounded-full" style={{ width: '45%' }}></div>
              </div>
              <p className="text-gray-400 text-xs mt-2">45.2% of total supply circulating | MCap: $611.49M</p>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="STRK" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Starknet (STRK)</h3>
                    <p className="text-gray-400 text-sm">Unlock Date: Jan 5, 2026</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold">64M tokens</p>
                  <p className="text-rose-400 text-sm">$6.7M value</p>
                </div>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-[#f0b90b] h-2 rounded-full" style={{ width: '48%' }}></div>
              </div>
              <p className="text-gray-400 text-xs mt-2">48% of total supply circulating | MCap: $502.72M</p>
            </div>

            <div className="bg-[#0b0e11] rounded-lg p-5 border border-gray-800">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol="SUI" size={40} />
                  <div>
                    <h3 className="text-white font-bold">Sui (SUI)</h3>
                    <p className="text-gray-400 text-sm">Unlock Date: Jan 12, 2026</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-white font-bold">256.19M tokens</p>
                  <p className="text-rose-400 text-sm">$409.9M value</p>
                </div>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-[#f0b90b] h-2 rounded-full" style={{ width: '37%' }}></div>
              </div>
              <p className="text-gray-400 text-xs mt-2">37.3% of total supply circulating | MCap: $6B</p>
            </div>
          </div>
        </div>
        )}

        <div id="market-table" className="bg-gradient-to-br from-[#181a20] to-[#1a1d24] rounded-2xl border border-gray-800/50 shadow-2xl overflow-hidden">
          <div className="bg-gradient-to-r from-[#0b0e11] to-[#181a20] px-6 py-5 border-b border-gray-800/50">
            <div className="flex items-center justify-between">
              <div className="flex gap-8 overflow-x-auto scrollbar-hide">
                <button
                  onClick={() => setActiveTab('favorites')}
                  className={`relative font-semibold pb-3 transition-all duration-300 whitespace-nowrap group ${
                    activeTab === 'favorites'
                      ? 'text-[#f0b90b]'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  <span className="flex items-center gap-2">
                    <Star className={`w-4 h-4 ${activeTab === 'favorites' ? 'fill-[#f0b90b]' : ''}`} />
                    Favorites
                  </span>
                  {activeTab === 'favorites' && (
                    <span className="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] rounded-full shadow-[0_0_10px_rgba(240,185,11,0.5)]"></span>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('cryptos')}
                  className={`relative font-semibold pb-3 transition-all duration-300 whitespace-nowrap ${
                    activeTab === 'cryptos'
                      ? 'text-[#f0b90b]'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  Cryptos
                  {activeTab === 'cryptos' && (
                    <span className="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] rounded-full shadow-[0_0_10px_rgba(240,185,11,0.5)]"></span>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('spot')}
                  className={`relative font-semibold pb-3 transition-all duration-300 whitespace-nowrap ${
                    activeTab === 'spot'
                      ? 'text-[#f0b90b]'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  Spot
                  {activeTab === 'spot' && (
                    <span className="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] rounded-full shadow-[0_0_10px_rgba(240,185,11,0.5)]"></span>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('futures')}
                  className={`relative font-semibold pb-3 transition-all duration-300 whitespace-nowrap ${
                    activeTab === 'futures'
                      ? 'text-[#f0b90b]'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  Futures
                  {activeTab === 'futures' && (
                    <span className="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] rounded-full shadow-[0_0_10px_rgba(240,185,11,0.5)]"></span>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('alpha')}
                  className={`relative font-semibold pb-3 transition-all duration-300 flex items-center gap-2 whitespace-nowrap ${
                    activeTab === 'alpha'
                      ? 'text-[#f0b90b]'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  Alpha
                  <span className="bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black text-[10px] px-2 py-0.5 rounded-full font-bold shadow-lg animate-pulse">NEW</span>
                  {activeTab === 'alpha' && (
                    <span className="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] rounded-full shadow-[0_0_10px_rgba(240,185,11,0.5)]"></span>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('new')}
                  className={`relative font-semibold pb-3 transition-all duration-300 whitespace-nowrap ${
                    activeTab === 'new'
                      ? 'text-[#f0b90b]'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  New
                  {activeTab === 'new' && (
                    <span className="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] rounded-full shadow-[0_0_10px_rgba(240,185,11,0.5)]"></span>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('zones')}
                  className={`relative font-semibold pb-3 transition-all duration-300 whitespace-nowrap ${
                    activeTab === 'zones'
                      ? 'text-[#f0b90b]'
                      : 'text-gray-400 hover:text-gray-200'
                  }`}
                >
                  Zones
                  {activeTab === 'zones' && (
                    <span className="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] rounded-full shadow-[0_0_10px_rgba(240,185,11,0.5)]"></span>
                  )}
                </button>
              </div>
            </div>
          </div>

          <div className="px-6 py-5 border-b border-gray-800/50">
            <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
              <button
                onClick={() => setActiveCategory('all')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'all'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                All
              </button>
              <button
                onClick={() => setActiveCategory('bnbchain')}
                className={`px-5 py-2.5 rounded-xl text-sm whitespace-nowrap flex items-center gap-2 transition-all duration-300 ${
                  activeCategory === 'bnbchain'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105 font-semibold'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                BNB Chain <span className="bg-emerald-500/20 text-emerald-400 text-[10px] px-2 py-0.5 rounded-full font-bold">New</span>
              </button>
              <button
                onClick={() => setActiveCategory('solana')}
                className={`px-5 py-2.5 rounded-xl text-sm whitespace-nowrap flex items-center gap-2 transition-all duration-300 ${
                  activeCategory === 'solana'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105 font-semibold'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Solana <span className="bg-emerald-500/20 text-emerald-400 text-[10px] px-2 py-0.5 rounded-full font-bold">New</span>
              </button>
              <button
                onClick={() => setActiveCategory('rwa')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'rwa'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                RWA
              </button>
              <button
                onClick={() => setActiveCategory('meme')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'meme'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Meme
              </button>
              <button
                onClick={() => setActiveCategory('payments')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'payments'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Payments
              </button>
              <button
                onClick={() => setActiveCategory('ai')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'ai'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                AI
              </button>
              <button
                onClick={() => setActiveCategory('layer1')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'layer1' || activeCategory === 'layer2'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Layer 1 / Layer 2
              </button>
              <button
                onClick={() => setActiveCategory('metaverse')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'metaverse'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Metaverse
              </button>
              <button
                onClick={() => setActiveCategory('seed')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'seed'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Seed
              </button>
              <button
                onClick={() => setActiveCategory('launchpool')}
                className={`px-5 py-2.5 rounded-xl text-sm whitespace-nowrap flex items-center gap-2 transition-all duration-300 ${
                  activeCategory === 'launchpool'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105 font-semibold'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Launchpool <span className="bg-emerald-500/20 text-emerald-400 text-[10px] px-2 py-0.5 rounded-full font-bold">New</span>
              </button>
              <button
                onClick={() => setActiveCategory('megadrop')}
                className={`px-5 py-2.5 rounded-xl text-sm whitespace-nowrap flex items-center gap-2 transition-all duration-300 ${
                  activeCategory === 'megadrop'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105 font-semibold'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Megadrop <span className="bg-emerald-500/20 text-emerald-400 text-[10px] px-2 py-0.5 rounded-full font-bold">New</span>
              </button>
              <button
                onClick={() => setActiveCategory('gaming')}
                className={`px-5 py-2.5 rounded-xl text-sm font-semibold whitespace-nowrap transition-all duration-300 ${
                  activeCategory === 'gaming'
                    ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30 scale-105'
                    : 'bg-[#0b0e11] text-gray-400 hover:bg-[#2b3139] hover:text-white border border-gray-800 hover:border-gray-700'
                }`}
              >
                Gaming
              </button>
            </div>
          </div>

          <div className="px-6 py-6 bg-gradient-to-r from-[#0b0e11] via-[#181a20] to-[#0b0e11] border-b border-gray-800/50">
            <div className="flex items-start gap-4">
              <div className="w-1 h-16 bg-gradient-to-b from-[#f0b90b] to-[#f8d12f] rounded-full shadow-lg shadow-[#f0b90b]/30"></div>
              <div>
                <h2 className="text-2xl font-bold text-white mb-2 bg-gradient-to-r from-white to-gray-300 bg-clip-text text-transparent">
                  Top Tokens by Market Capitalization
                </h2>
                <p className="text-gray-400 text-sm leading-relaxed">
                  Get a comprehensive snapshot of all cryptocurrencies available on Shark Trades. This page displays the latest prices, 24-hour trading volume, price changes, and market capitalizations for all cryptocurrencies.
                  <button
                    onClick={() => {
                      setActiveTab('cryptos');
                      setActiveCategory('all');
                      document.getElementById('market-table')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                    }}
                    className="text-[#f0b90b] hover:text-[#f8d12f] font-semibold ml-2 transition-colors inline-flex items-center gap-1 group"
                  >
                    More
                    <span className="inline-block transform group-hover:translate-x-1 transition-transform">→</span>
                  </button>
                </p>
              </div>
            </div>
          </div>

          <div className="px-6 py-6">
            <TokenTable
              activeTab={activeTab}
              activeCategory={activeCategory}
              favorites={favorites}
              onToggleFavorite={toggleFavorite}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

export default Markets;

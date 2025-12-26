import { Star, TrendingUp, ArrowUpRight, ChevronDown, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight } from 'lucide-react';
import { useState, useEffect } from 'react';
import { allTokens } from '../data/cryptos';
import { usePrices } from '../hooks/usePrices';
import { useNavigation } from '../App';
import CryptoIcon from './CryptoIcon';

interface TokenTableProps {
  activeTab?: string;
  activeCategory?: string;
  favorites?: Set<string>;
  onToggleFavorite?: (symbol: string) => void;
}

export default function TokenTable({
  activeTab = 'cryptos',
  activeCategory = 'all',
  favorites: propFavorites,
  onToggleFavorite
}: TokenTableProps) {
  const [localFavorites, setLocalFavorites] = useState<Set<string>>(new Set());
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [showFullDescription, setShowFullDescription] = useState(false);
  const prices = usePrices();
  const { navigateTo } = useNavigation();

  const favorites = propFavorites ?? localFavorites;
  const handleToggleFavorite = onToggleFavorite ?? ((symbol: string) => {
    const newFavorites = new Set(localFavorites);
    if (newFavorites.has(symbol)) {
      newFavorites.delete(symbol);
    } else {
      newFavorites.add(symbol);
    }
    setLocalFavorites(newFavorites);
  });

  const handleTradeClick = (symbol: string) => {
    const futuresPair = symbol.replace('/', '');
    navigateTo('futures', { selectedPair: futuresPair });
  };

  const formatNumber = (num: number) => {
    if (num >= 1e12) return `$${(num / 1e12).toFixed(2)}T`;
    if (num >= 1e9) return `$${(num / 1e9).toFixed(2)}B`;
    if (num >= 1e6) return `$${(num / 1e6).toFixed(2)}M`;
    return `$${num.toFixed(2)}`;
  };

  const getFilteredTokens = () => {
    let filtered = [...allTokens];

    if (activeTab === 'favorites') {
      filtered = filtered.filter(token => favorites.has(token.symbol));
    } else if (activeTab === 'spot') {
      filtered = filtered.filter(token => !token.symbol.includes('PERP'));
    } else if (activeTab === 'futures') {
      filtered = filtered.filter(token => token.symbol.includes('PERP'));
    } else if (activeTab === 'alpha') {
      filtered = filtered.filter(token => token.isAlpha);
    } else if (activeTab === 'new') {
      filtered = filtered.filter(token => token.isNew);
    }

    if (activeCategory !== 'all') {
      if (activeCategory === 'layer1') {
        filtered = filtered.filter(token =>
          token.categories.includes('layer1') || token.categories.includes('layer2')
        );
      } else {
        filtered = filtered.filter(token =>
          token.categories.includes(activeCategory.toLowerCase())
        );
      }
    }

    return filtered;
  };

  const filteredTokens = getFilteredTokens();
  const totalPages = Math.ceil(filteredTokens.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const paginatedTokens = filteredTokens.slice(startIndex, endIndex);

  useEffect(() => {
    setCurrentPage(1);
  }, [activeTab, activeCategory, itemsPerPage]);

  const getPageNumbers = () => {
    const pages: (number | string)[] = [];
    const maxVisible = 5;

    if (totalPages <= maxVisible + 2) {
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i);
      }
    } else {
      pages.push(1);

      if (currentPage > 3) {
        pages.push('...');
      }

      const start = Math.max(2, currentPage - 1);
      const end = Math.min(totalPages - 1, currentPage + 1);

      for (let i = start; i <= end; i++) {
        pages.push(i);
      }

      if (currentPage < totalPages - 2) {
        pages.push('...');
      }

      pages.push(totalPages);
    }

    return pages;
  };

  return (
    <div className="space-y-4 sm:space-y-6">
      <div className="space-y-2 sm:space-y-3">
        <h2 className="text-gray-100 text-lg sm:text-2xl font-bold bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] bg-clip-text text-transparent">
          Top Tokens by Market Capitalization
        </h2>
        <p className="text-gray-400 text-xs sm:text-sm leading-relaxed">
          Get a comprehensive snapshot of all cryptocurrencies available on the platform. This page displays
          the latest prices, 24-hour trading volume, price changes, and market capitalizations for all
          cryptocurrencies{showFullDescription ? '. Track real-time price movements, analyze market trends, and make informed trading decisions with comprehensive data on every listed cryptocurrency. Our advanced filtering and sorting options help you discover the best trading opportunities across all supported digital assets.' : '...'}
          <button
            onClick={() => setShowFullDescription(!showFullDescription)}
            className="text-[#f0b90b] hover:text-[#f8d12f] ml-1 font-semibold transition-colors inline-flex items-center gap-1 group"
          >
            {showFullDescription ? 'Less' : 'More'}
            <span className={`inline-block transform transition-transform ${showFullDescription ? 'rotate-180' : ''}`}>
              {showFullDescription ? '↑' : '→'}
            </span>
          </button>
        </p>
      </div>

      <div className="glass-card rounded-xl sm:rounded-2xl overflow-hidden border border-[#f0b90b]/10">
        <div className="overflow-x-auto scrollbar-custom -mx-4 px-4 sm:mx-0 sm:px-0">
          <table className="w-full">
            <thead>
              <tr className="border-b border-[#f0b90b]/10 bg-gradient-to-r from-[#f0b90b]/5 to-[#f8d12f]/5">
                <th className="text-left px-3 sm:px-6 py-3 sm:py-4 text-gray-400 text-xs font-semibold uppercase tracking-wider sticky left-0 bg-[#0b0e11] z-10">Name</th>
                <th className="text-right px-3 sm:px-6 py-3 sm:py-4 text-gray-400 text-xs font-semibold uppercase tracking-wider">Price</th>
                <th className="text-right px-3 sm:px-6 py-3 sm:py-4 text-gray-400 text-xs font-semibold uppercase tracking-wider">
                  <div className="flex items-center justify-end gap-2">
                    <span className="hidden sm:inline">24h Change</span>
                    <span className="sm:hidden">Change</span>
                    <select className="bg-white/5 border border-[#f0b90b]/20 rounded-lg px-1 sm:px-2 py-1 text-xs hover:border-[#f0b90b]/40 transition-colors cursor-pointer">
                      <option>24h</option>
                      <option>7d</option>
                      <option>30d</option>
                    </select>
                  </div>
                </th>
                <th className="text-right px-3 sm:px-6 py-3 sm:py-4 text-gray-400 text-xs font-semibold uppercase tracking-wider hidden md:table-cell">24h Volume</th>
                <th className="text-right px-3 sm:px-6 py-3 sm:py-4 text-gray-400 text-xs font-semibold uppercase tracking-wider hidden lg:table-cell">Market Cap</th>
                <th className="text-right px-3 sm:px-6 py-3 sm:py-4 text-gray-400 text-xs font-semibold uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody>
              {paginatedTokens.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center">
                    <div className="text-gray-400">
                      <div className="text-lg mb-2">No tokens found</div>
                      <div className="text-sm">Try adjusting your filters</div>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedTokens.map((token, index) => {
                const livePrice = prices.get(token.symbol);
                const displayPrice = livePrice ? livePrice.price : token.price;
                const displayChange = livePrice ? livePrice.change24h : token.change24h;
                const displayVolume = livePrice ? livePrice.volume24h : token.volume24h;

                return (
                  <tr
                    key={token.symbol}
                    className="border-b border-[#f0b90b]/5 hover:bg-gradient-to-r hover:from-[#f0b90b]/10 hover:to-[#f8d12f]/10 transition-all duration-300 group"
                    style={{ animationDelay: `${index * 50}ms` }}
                  >
                    <td className="px-3 sm:px-6 py-4 sm:py-5 sticky left-0 bg-[#0b0e11] z-10">
                      <div className="flex items-center gap-2 sm:gap-4">
                        <button
                          onClick={() => handleToggleFavorite(token.symbol)}
                          className="text-gray-500 hover:text-[#f0b90b] transition-all duration-300 hover:scale-110 hidden sm:block"
                        >
                          <Star
                            className={`w-4 sm:w-5 h-4 sm:h-5 ${favorites.has(token.symbol) ? 'fill-[#f0b90b] text-[#f0b90b]' : ''}`}
                          />
                        </button>
                        <div className="flex items-center gap-2 sm:gap-3">
                          <CryptoIcon symbol={token.symbol} size={32} />
                          <div>
                            <div className="text-gray-100 font-bold group-hover:text-[#f0b90b] transition-colors text-sm sm:text-base">
                              {token.symbol}
                            </div>
                            <div className="text-gray-500 text-xs hidden sm:block">{token.name}</div>
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-3 sm:px-6 py-4 sm:py-5 text-right">
                      <div className="text-gray-100 font-bold text-sm sm:text-base">
                        ${displayPrice.toLocaleString('en-US', {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })}
                      </div>
                      <div className="text-gray-500 text-xs mt-1 hidden sm:block">
                        {livePrice && <span className="text-emerald-400">● Live</span>}
                      </div>
                    </td>
                    <td className="px-3 sm:px-6 py-4 sm:py-5 text-right">
                      <div className="inline-flex items-center gap-1 sm:gap-2">
                        <div className="w-8 sm:w-16 h-6 sm:h-8 relative overflow-hidden hidden sm:block">
                          <svg className="w-full h-full" viewBox="0 0 60 30" preserveAspectRatio="none">
                            <path
                              d={`M 0 ${displayChange >= 0 ? 25 : 5} Q 15 ${displayChange >= 0 ? 15 : 15} 30 ${displayChange >= 0 ? 10 : 20} T 60 ${displayChange >= 0 ? 5 : 25}`}
                              fill="none"
                              stroke={displayChange >= 0 ? '#10b981' : '#ef4444'}
                              strokeWidth="2"
                              opacity="0.5"
                            />
                          </svg>
                        </div>
                        <span
                          className={`font-bold text-xs sm:text-sm px-2 sm:px-3 py-1 rounded-full ${
                            displayChange >= 0
                              ? 'text-emerald-400 bg-emerald-400/10'
                              : 'text-rose-400 bg-rose-400/10'
                          }`}
                        >
                          {displayChange >= 0 ? '+' : ''}
                          {displayChange.toFixed(2)}%
                        </span>
                      </div>
                    </td>
                    <td className="px-3 sm:px-6 py-4 sm:py-5 text-right hidden md:table-cell">
                      <div className="text-gray-100 font-semibold text-sm">{formatNumber(displayVolume)}</div>
                      <div className="text-gray-500 text-xs mt-1">Volume</div>
                    </td>
                    <td className="px-3 sm:px-6 py-4 sm:py-5 text-right hidden lg:table-cell">
                      <div className="text-gray-100 font-semibold text-sm">{formatNumber(token.marketCap)}</div>
                      <div className="text-gray-500 text-xs mt-1">Market Cap</div>
                    </td>
                  <td className="px-3 sm:px-6 py-4 sm:py-5">
                    <div className="flex items-center justify-end gap-1 sm:gap-2">
                      <button className="text-gray-500 hover:text-[#f0b90b] transition-all duration-300 p-1 sm:p-2 rounded-lg hover:bg-[#f0b90b]/10 hover:scale-110 hidden sm:block">
                        <TrendingUp className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleTradeClick(token.symbol)}
                        className="bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] hover:from-[#f8d12f] hover:to-[#f0b90b] text-black px-2 sm:px-4 py-1.5 sm:py-2 rounded-lg font-semibold text-xs flex items-center gap-1 transition-all duration-300 hover:scale-105 shadow-lg"
                      >
                        <span className="hidden sm:inline">Trade</span>
                        <span className="sm:hidden">▶</span>
                        <ArrowUpRight className="w-3 h-3 hidden sm:block" />
                      </button>
                    </div>
                  </td>
                </tr>
                );
              }))}
            </tbody>
          </table>
        </div>

        {filteredTokens.length > 0 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4 px-4 sm:px-6 py-4 border-t border-[#f0b90b]/10 bg-gradient-to-r from-[#0b0e11] to-[#181a20]">
            <div className="flex items-center gap-4">
              <div className="text-gray-400 text-sm">
                Showing <span className="text-white font-semibold">{startIndex + 1}</span> to{' '}
                <span className="text-white font-semibold">{Math.min(endIndex, filteredTokens.length)}</span> of{' '}
                <span className="text-white font-semibold">{filteredTokens.length}</span> tokens
              </div>
              <div className="flex items-center gap-2">
                <span className="text-gray-400 text-sm hidden sm:inline">Show:</span>
                <select
                  value={itemsPerPage}
                  onChange={(e) => setItemsPerPage(Number(e.target.value))}
                  className="bg-[#0b0e11] border border-gray-700 rounded-lg px-3 py-1.5 text-sm text-white outline-none focus:border-[#f0b90b] transition-colors cursor-pointer"
                >
                  <option value={10}>10</option>
                  <option value={25}>25</option>
                  <option value={50}>50</option>
                  <option value={100}>100</option>
                </select>
              </div>
            </div>

            <div className="flex items-center gap-1 sm:gap-2">
              <button
                onClick={() => setCurrentPage(1)}
                disabled={currentPage === 1}
                className="p-2 rounded-lg bg-[#0b0e11] border border-gray-700 text-gray-400 hover:text-white hover:border-[#f0b90b] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                title="First page"
              >
                <ChevronsLeft className="w-4 h-4" />
              </button>
              <button
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="p-2 rounded-lg bg-[#0b0e11] border border-gray-700 text-gray-400 hover:text-white hover:border-[#f0b90b] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                title="Previous page"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>

              <div className="flex items-center gap-1">
                {getPageNumbers().map((page, idx) => (
                  typeof page === 'number' ? (
                    <button
                      key={idx}
                      onClick={() => setCurrentPage(page)}
                      className={`min-w-[36px] h-9 px-3 rounded-lg font-medium text-sm transition-all ${
                        currentPage === page
                          ? 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black shadow-lg shadow-[#f0b90b]/30'
                          : 'bg-[#0b0e11] border border-gray-700 text-gray-400 hover:text-white hover:border-[#f0b90b]'
                      }`}
                    >
                      {page}
                    </button>
                  ) : (
                    <span key={idx} className="px-2 text-gray-500">...</span>
                  )
                ))}
              </div>

              <button
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="p-2 rounded-lg bg-[#0b0e11] border border-gray-700 text-gray-400 hover:text-white hover:border-[#f0b90b] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                title="Next page"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
              <button
                onClick={() => setCurrentPage(totalPages)}
                disabled={currentPage === totalPages}
                className="p-2 rounded-lg bg-[#0b0e11] border border-gray-700 text-gray-400 hover:text-white hover:border-[#f0b90b] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                title="Last page"
              >
                <ChevronsRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

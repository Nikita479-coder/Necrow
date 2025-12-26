import { usePrices } from '../../hooks/usePrices';

interface TickerBarProps {
  selectedPair: string;
  onPairChange: (pair: string) => void;
}

const tickerSymbols = ['BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'SOL/USDT', 'XRP/USDT', 'ADA/USDT', 'DOGE/USDT', 'MATIC/USDT', 'DOT/USDT', 'LINK/USDT', 'AVAX/USDT', 'UNI/USDT'];

function TickerBar({ selectedPair, onPairChange }: TickerBarProps) {
  const prices = usePrices();

  const renderTickerItem = (symbol: string, index: number) => {
    const priceData = prices.get(symbol);
    const displayPrice = priceData ? priceData.price.toFixed(2) : '---';
    const change = priceData ? priceData.change24h : 0;
    const isNegative = change < 0;

    return (
      <button
        key={`${symbol}-${index}`}
        onClick={() => onPairChange(symbol.replace('/', ''))}
        className={`flex items-center gap-2 px-2.5 py-1 transition-colors shrink-0 ${
          selectedPair === symbol.replace('/', '')
            ? 'bg-[#2b2e35]'
            : 'hover:bg-[#2b2e35]/50'
        }`}
      >
        <span className="text-gray-500 text-[11px] font-medium">{symbol.replace('/', '')}</span>
        <span className="text-white text-xs font-semibold">${displayPrice}</span>
        <span
          className={`text-[11px] font-semibold ${
            isNegative ? 'text-[#f6465d]' : 'text-[#0ecb81]'
          }`}
        >
          {change > 0 ? '+' : ''}
          {change.toFixed(2)}%
        </span>
      </button>
    );
  };

  return (
    <div className="bg-[#0b0e11] border-b border-[#2b2e35] px-3 py-1.5 overflow-hidden">
      <div className="ticker-scroll-container">
        <div className="ticker-scroll-content">
          {tickerSymbols.map((symbol, index) => renderTickerItem(symbol, index))}
        </div>
        <div className="ticker-scroll-content" aria-hidden="true">
          {tickerSymbols.map((symbol, index) => renderTickerItem(symbol, index + tickerSymbols.length))}
        </div>
      </div>
      <style>{`
        .ticker-scroll-container {
          display: flex;
          overflow: hidden;
          position: relative;
        }

        .ticker-scroll-content {
          display: flex;
          gap: 1rem;
          animation: scroll 60s linear infinite;
          flex-shrink: 0;
          will-change: transform;
        }

        @keyframes scroll {
          from {
            transform: translateX(0);
          }
          to {
            transform: translateX(-100%);
          }
        }

        .ticker-scroll-container:hover .ticker-scroll-content {
          animation-play-state: paused;
        }
      `}</style>
    </div>
  );
}

export default TickerBar;

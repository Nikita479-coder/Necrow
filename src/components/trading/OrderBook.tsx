import { useState, useEffect } from 'react';
import { usePrice } from '../../hooks/usePrices';

interface OrderBookProps {
  pair: string;
}

interface OrderBookEntry {
  price: number;
  size: number;
  total: number;
}

type ViewMode = 'both' | 'buy' | 'sell';

function OrderBook({ pair }: OrderBookProps) {
  const [precision, setPrecision] = useState('0.1');
  const [asks, setAsks] = useState<OrderBookEntry[]>([]);
  const [bids, setBids] = useState<OrderBookEntry[]>([]);
  const [animatingIndex, setAnimatingIndex] = useState<number>(-1);
  const [viewMode, setViewMode] = useState<ViewMode>('both');

  const symbolWithSlash = pair.replace('USDT', '/USDT');
  const priceData = usePrice(symbolWithSlash);
  const currentPrice = priceData ? parseFloat(priceData.price) : 106786.7;

  const generateOrders = (
    basePrice: number,
    count: number,
    isAsk: boolean
  ): OrderBookEntry[] => {
    const orders: OrderBookEntry[] = [];
    let total = 0;

    for (let i = 0; i < count; i++) {
      const spread = basePrice * 0.00001;
      const priceOffset = isAsk ? (i + 1) * spread : -i * spread;
      const price = basePrice + priceOffset;
      const size = (Math.random() * 0.5 + 0.1) * (1 - i * 0.05);
      total += size;

      orders.push({
        price: parseFloat(price.toFixed(2)),
        size: parseFloat(size.toFixed(4)),
        total: parseFloat(total.toFixed(4)),
      });
    }

    return orders;
  };

  useEffect(() => {
    const updateOrderBook = () => {
      const newAsks = generateOrders(currentPrice, 12, true).reverse();
      const newBids = generateOrders(currentPrice, 12, false);

      setAsks(prev => {
        if (prev.length === 0) return newAsks;
        return newAsks.map((order, idx) => ({
          ...order,
          size: prev[idx] ? prev[idx].size * 0.95 + order.size * 0.05 : order.size,
        }));
      });

      setBids(prev => {
        if (prev.length === 0) return newBids;
        return newBids.map((order, idx) => ({
          ...order,
          size: prev[idx] ? prev[idx].size * 0.95 + order.size * 0.05 : order.size,
        }));
      });

      setAnimatingIndex(Math.floor(Math.random() * 12));
      setTimeout(() => setAnimatingIndex(-1), 200);
    };

    updateOrderBook();
    const interval = setInterval(updateOrderBook, 800);

    return () => clearInterval(interval);
  }, [currentPrice]);

  const maxSize = Math.max(
    ...asks.map(o => o.size),
    ...bids.map(o => o.size)
  );

  return (
    <div className="flex-1 flex flex-col bg-[#0b0e11] border-b border-gray-800 overflow-hidden">
      <div className="flex items-center justify-between px-4 py-3 border-b border-[#2b2e35]">
        <h3 className="text-sm font-semibold text-white">Order Book</h3>
        <div className="flex items-center gap-2">
          <div className="flex gap-1 bg-gray-900 rounded p-0.5">
            <button
              onClick={() => setViewMode('both')}
              className={`px-2 py-1 text-xs rounded transition-colors ${
                viewMode === 'both'
                  ? 'bg-gray-700 text-white'
                  : 'text-gray-400 hover:text-white'
              }`}
              title="Show Both"
            >
              <svg className="w-3 h-3" viewBox="0 0 16 16" fill="currentColor">
                <rect y="0" width="16" height="7" className="text-red-500" />
                <rect y="9" width="16" height="7" className="text-green-500" />
              </svg>
            </button>
            <button
              onClick={() => setViewMode('sell')}
              className={`px-2 py-1 text-xs rounded transition-colors ${
                viewMode === 'sell'
                  ? 'bg-gray-700 text-red-500'
                  : 'text-gray-400 hover:text-red-500'
              }`}
              title="Show Sell Orders"
            >
              <svg className="w-3 h-3" viewBox="0 0 16 16" fill="currentColor">
                <rect width="16" height="16" />
              </svg>
            </button>
            <button
              onClick={() => setViewMode('buy')}
              className={`px-2 py-1 text-xs rounded transition-colors ${
                viewMode === 'buy'
                  ? 'bg-gray-700 text-green-500'
                  : 'text-gray-400 hover:text-green-500'
              }`}
              title="Show Buy Orders"
            >
              <svg className="w-3 h-3" viewBox="0 0 16 16" fill="currentColor">
                <rect width="16" height="16" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 px-4 py-2 text-xs text-gray-500 border-b border-gray-800">
        <div className="text-left">Price (USDT)</div>
        <div className="text-right">Size (BTC)</div>
        <div className="text-right">Total (BTC)</div>
      </div>

      <div className="flex-1 overflow-y-auto scrollbar-thin scrollbar-thumb-gray-800">
        {(viewMode === 'both' || viewMode === 'sell') && (
          <div className="px-4">
            {asks.map((order, idx) => (
              <div
                key={`ask-${idx}`}
                className={`grid grid-cols-3 gap-2 py-1 text-xs relative hover:bg-gray-900/50 cursor-pointer transition-all ${
                  animatingIndex === idx ? 'bg-red-500/20' : ''
                }`}
              >
                <div
                  className="absolute right-0 top-0 bottom-0 bg-red-500/10 transition-all duration-300"
                  style={{ width: `${(order.size / maxSize) * 100}%` }}
                />
                <div className="text-red-500 relative z-10">
                  {order.price.toLocaleString('en-US', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  })}
                </div>
                <div className="text-right text-gray-300 relative z-10">
                  {order.size.toFixed(4)}
                </div>
                <div className="text-right text-gray-500 relative z-10">
                  {order.total.toFixed(4)}
                </div>
              </div>
            ))}
          </div>
        )}

        {viewMode === 'both' && (
          <div className="px-4 py-3 bg-[#0f1217] border-y border-gray-800 sticky top-0 z-20">
            <div className="flex items-center justify-between">
              <div className={`text-xl font-bold transition-colors ${
                priceData && parseFloat(priceData.change24h) >= 0 ? 'text-green-500' : 'text-red-500'
              }`}>
                {currentPrice.toLocaleString('en-US', {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2,
                })}
              </div>
              <div className="text-xs text-gray-500">
                ≈ ${currentPrice.toLocaleString('en-US', {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2,
                })}
              </div>
            </div>
          </div>
        )}

        {(viewMode === 'both' || viewMode === 'buy') && (
          <div className="px-4">
            {bids.map((order, idx) => (
              <div
                key={`bid-${idx}`}
                className={`grid grid-cols-3 gap-2 py-1 text-xs relative hover:bg-gray-900/50 cursor-pointer transition-all ${
                  animatingIndex === idx ? 'bg-green-500/20' : ''
                }`}
              >
                <div
                  className="absolute right-0 top-0 bottom-0 bg-green-500/10 transition-all duration-300"
                  style={{ width: `${(order.size / maxSize) * 100}%` }}
                />
                <div className="text-green-500 relative z-10">
                  {order.price.toLocaleString('en-US', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  })}
                </div>
                <div className="text-right text-gray-300 relative z-10">
                  {order.size.toFixed(4)}
                </div>
                <div className="text-right text-gray-500 relative z-10">
                  {order.total.toFixed(4)}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default OrderBook;

import { X } from 'lucide-react';
import CryptoIcon from '../CryptoIcon';
import { usePrices } from '../../hooks/usePrices';

interface PairTabsProps {
  tabs: string[];
  selectedPair: string;
  onPairChange: (pair: string) => void;
  onRemoveTab: (pair: string) => void;
}

function PairTabs({ tabs, selectedPair, onPairChange, onRemoveTab }: PairTabsProps) {
  const prices = usePrices();

  const getPairPrice = (pair: string) => {
    const symbol = pair.replace('USDT', '');
    const priceData = prices.get(`${symbol}/USDT`);
    return priceData ? parseFloat(priceData.price).toFixed(2) : '---';
  };

  const getPairChange = (pair: string) => {
    const symbol = pair.replace('USDT', '');
    const priceData = prices.get(`${symbol}/USDT`);
    return priceData ? priceData.change24h : 0;
  };

  if (tabs.length === 0) return null;

  return (
    <div className="flex items-center gap-1 overflow-x-auto scrollbar-thin scrollbar-thumb-gray-700 scrollbar-track-transparent">
      {tabs.map((pair) => {
        const symbol = pair.replace('USDT', '');
        const isSelected = selectedPair === pair;
        const price = getPairPrice(pair);
        const change = getPairChange(pair);

        return (
          <div
            key={pair}
            className={`flex items-center gap-2 px-3 py-2 rounded transition-colors cursor-pointer group relative ${
              isSelected
                ? 'bg-[#f0b90b]/10 border border-[#f0b90b]'
                : 'bg-[#181a20] hover:bg-gray-800 border border-transparent'
            }`}
            onClick={() => onPairChange(pair)}
          >
            <CryptoIcon symbol={symbol} size={20} />
            <div className="flex flex-col min-w-[80px]">
              <div className="flex items-center gap-1">
                <span className={`font-semibold text-sm ${isSelected ? 'text-[#f0b90b]' : 'text-white'}`}>
                  {symbol}/USDT
                </span>
              </div>
              <div className="flex items-center gap-2 text-xs">
                <span className="text-gray-400">{price}</span>
                <span className={change >= 0 ? 'text-green-500' : 'text-red-500'}>
                  {change > 0 ? '+' : ''}{change.toFixed(2)}%
                </span>
              </div>
            </div>
            {tabs.length > 1 && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onRemoveTab(pair);
                }}
                className="opacity-0 group-hover:opacity-100 transition-opacity ml-1 p-0.5 hover:bg-gray-700 rounded"
              >
                <X size={14} className="text-gray-400 hover:text-white" />
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}

export default PairTabs;

import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface Position {
  position_id: string;
  pair: string;
  side: 'long' | 'short';
  entry_price: number;
  mark_price: number;
  quantity: number;
  leverage: number;
  margin_allocated: number;
  stop_loss: number | null;
  take_profit: number | null;
}

interface TPSLModalProps {
  position: Position;
  mode: 'TP' | 'SL';
  onClose: () => void;
  onUpdate: () => void;
}

type InputMode = 'Price' | 'PnL' | '%';

export default function TPSLModal({ position, mode, onClose, onUpdate }: TPSLModalProps) {
  const { user } = useAuth();
  const [inputMode, setInputMode] = useState<InputMode>('Price');
  const [inputValue, setInputValue] = useState('');
  const [sliderValue, setSliderValue] = useState(50);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isTP = mode === 'TP';
  const currentValue = isTP ? position.take_profit : position.stop_loss;

  useEffect(() => {
    if (currentValue) {
      setInputValue(currentValue.toString());
    }
  }, [currentValue]);

  const calculateTriggerPrice = (): number => {
    const entryPrice = position.entry_price;
    const value = parseFloat(inputValue) || 0;

    switch (inputMode) {
      case 'Price':
        return value;

      case 'PnL': {
        const pnlPerUnit = value / position.quantity;
        if (position.side === 'long') {
          return entryPrice + pnlPerUnit;
        } else {
          return entryPrice - pnlPerUnit;
        }
      }

      case '%': {
        const roiDecimal = value / 100;
        const pnlTarget = position.margin_allocated * roiDecimal;
        const pnlPerUnit = pnlTarget / position.quantity;
        if (position.side === 'long') {
          return entryPrice + pnlPerUnit;
        } else {
          return entryPrice - pnlPerUnit;
        }
      }

      default:
        return entryPrice;
    }
  };

  const calculateEstimatedPnL = (triggerPrice: number): number => {
    if (position.side === 'long') {
      return (triggerPrice - position.entry_price) * position.quantity;
    } else {
      return (position.entry_price - triggerPrice) * position.quantity;
    }
  };

  const calculatePriceChange = (triggerPrice: number): number => {
    return ((triggerPrice - position.entry_price) / position.entry_price) * 100;
  };

  const calculateROI = (estimatedPnL: number): number => {
    return (estimatedPnL / position.margin_allocated) * 100;
  };

  const handleSliderChange = (value: number) => {
    setSliderValue(value);

    if (inputMode === 'PnL') {
      const maxPnL = position.margin_allocated * 10;
      const pnlValue = (value / 100) * maxPnL;
      setInputValue(pnlValue.toFixed(2));
    } else if (inputMode === '%') {
      const roiValue = (value / 100) * 1000;
      setInputValue(roiValue.toFixed(2));
    }
  };

  const handleRemove = async () => {
    if (!user) return;

    setIsSubmitting(true);
    try {
      const updateData = isTP
        ? { take_profit: null }
        : { stop_loss: null };

      const { error } = await supabase
        .from('futures_positions')
        .update(updateData)
        .eq('position_id', position.position_id)
        .eq('user_id', user.id);

      if (error) throw error;

      onUpdate();
      onClose();
    } catch (error) {
      console.error('Error removing TP/SL:', error);
      alert('Failed to remove TP/SL');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleConfirm = async () => {
    if (!user || !inputValue) return;

    const triggerPrice = calculateTriggerPrice();

    if (triggerPrice <= 0) {
      alert('Invalid trigger price');
      return;
    }

    if (isTP) {
      if (position.side === 'long' && triggerPrice <= position.entry_price) {
        alert('Take Profit price must be higher than entry price for long positions');
        return;
      }
      if (position.side === 'short' && triggerPrice >= position.entry_price) {
        alert('Take Profit price must be lower than entry price for short positions');
        return;
      }
    } else {
      if (position.side === 'long' && triggerPrice >= position.entry_price) {
        alert('Stop Loss price must be lower than entry price for long positions');
        return;
      }
      if (position.side === 'short' && triggerPrice <= position.entry_price) {
        alert('Stop Loss price must be higher than entry price for short positions');
        return;
      }
    }

    setIsSubmitting(true);
    try {
      const updateData = isTP
        ? { take_profit: triggerPrice }
        : { stop_loss: triggerPrice };

      const { error } = await supabase
        .from('futures_positions')
        .update(updateData)
        .eq('position_id', position.position_id)
        .eq('user_id', user.id);

      if (error) throw error;

      onUpdate();
      onClose();
    } catch (error) {
      console.error('Error updating TP/SL:', error);
      alert('Failed to update TP/SL');
    } finally {
      setIsSubmitting(false);
    }
  };

  const triggerPrice = calculateTriggerPrice();
  const estimatedPnL = calculateEstimatedPnL(triggerPrice);
  const priceChange = calculatePriceChange(triggerPrice);
  const roi = calculateROI(estimatedPnL);

  const pnlColor = estimatedPnL >= 0 ? 'text-green-500' : 'text-red-500';

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
      <div className="bg-[#0b0e11] border border-[#2b2e35] rounded-lg w-full max-w-md">
        <div className="flex items-center justify-between p-4 border-b border-[#2b2e35]">
          <div className="flex items-center gap-2">
            <span className={isTP ? 'text-green-500' : 'text-red-500'}>
              {isTP ? '↗' : '↘'}
            </span>
            <h3 className={`font-semibold ${isTP ? 'text-green-500' : 'text-red-500'}`}>
              {isTP ? 'Take Profit' : 'Stop Loss'}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-4 space-y-4">
          <div className="bg-[#1a1d23] rounded-lg p-3 grid grid-cols-2 gap-3 text-sm">
            <div>
              <div className="text-gray-400 text-xs mb-1">Side:</div>
              <div className={position.side === 'long' ? 'text-green-500' : 'text-red-500'}>
                {position.side.toUpperCase()}
              </div>
            </div>
            <div>
              <div className="text-gray-400 text-xs mb-1">Entry:</div>
              <div className="text-white">${position.entry_price.toFixed(2)}</div>
            </div>
            <div>
              <div className="text-gray-400 text-xs mb-1">Amount:</div>
              <div className="text-white">{position.quantity.toFixed(6)}</div>
            </div>
            <div>
              <div className="text-gray-400 text-xs mb-1">Leverage:</div>
              <div className="text-white">{position.leverage}x</div>
            </div>
          </div>

          <div className="flex gap-2">
            <button
              onClick={() => setInputMode('Price')}
              className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                inputMode === 'Price'
                  ? isTP
                    ? 'bg-green-500/20 text-green-500 border border-green-500'
                    : 'bg-red-500/20 text-red-500 border border-red-500'
                  : 'bg-[#1a1d23] text-gray-400 border border-transparent hover:border-gray-600'
              }`}
            >
              $ Price
            </button>
            <button
              onClick={() => setInputMode('PnL')}
              className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                inputMode === 'PnL'
                  ? isTP
                    ? 'bg-green-500/20 text-green-500 border border-green-500'
                    : 'bg-red-500/20 text-red-500 border border-red-500'
                  : 'bg-[#1a1d23] text-gray-400 border border-transparent hover:border-gray-600'
              }`}
            >
              PnL
            </button>
            <button
              onClick={() => setInputMode('%')}
              className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                inputMode === '%'
                  ? isTP
                    ? 'bg-green-500/20 text-green-500 border border-green-500'
                    : 'bg-red-500/20 text-red-500 border border-red-500'
                  : 'bg-[#1a1d23] text-gray-400 border border-transparent hover:border-gray-600'
              }`}
            >
              % %
            </button>
          </div>

          <div>
            <label className="text-gray-400 text-xs mb-2 block">
              {inputMode === 'Price' && 'Trigger Price'}
              {inputMode === 'PnL' && 'Target PnL (USD)'}
              {inputMode === '%' && 'Target ROI (%)'}
            </label>
            <input
              type="number"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              placeholder={inputMode === 'Price' ? '100000' : inputMode === 'PnL' ? '10' : '2'}
              className={`w-full bg-[#1a1d23] text-white px-4 py-3 rounded-md border-2 ${
                isTP ? 'border-green-500/30 focus:border-green-500' : 'border-red-500/30 focus:border-red-500'
              } focus:outline-none`}
            />
          </div>

          {inputMode !== 'Price' && (
            <div>
              <div className="flex justify-between text-xs text-gray-400 mb-2">
                <span>Quick Select {inputMode === '%' ? 'ROI' : '(% of Margin)'}</span>
                <span className="text-gray-500">0% - 100%</span>
              </div>
              <input
                type="range"
                min="0"
                max="100"
                value={sliderValue}
                onChange={(e) => handleSliderChange(parseInt(e.target.value))}
                className={`w-full h-1 rounded-lg appearance-none cursor-pointer ${
                  isTP ? 'accent-green-500' : 'accent-red-500'
                }`}
                style={{
                  background: `linear-gradient(to right, ${isTP ? '#0ecb81' : '#f6465d'} 0%, ${isTP ? '#0ecb81' : '#f6465d'} ${sliderValue}%, #1a1d23 ${sliderValue}%, #1a1d23 100%)`
                }}
              />
              <div className="flex justify-between text-xs text-gray-500 mt-1">
                <span>0%</span>
                <span>50%</span>
                <span>100%</span>
              </div>
            </div>
          )}

          {inputValue && triggerPrice > 0 && (
            <div className="bg-[#1a1d23] rounded-lg p-3 space-y-2 text-sm border border-[#2b2e35]">
              <div className="flex justify-between">
                <span className="text-gray-400">Trigger Price:</span>
                <span className="text-white font-medium">${triggerPrice.toFixed(2)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Est. PnL:</span>
                <span className={`font-semibold ${pnlColor}`}>
                  {estimatedPnL >= 0 ? '+' : ''}${estimatedPnL.toFixed(2)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Price Change:</span>
                <span className="text-white">{priceChange >= 0 ? '+' : ''}{priceChange.toFixed(2)}%</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">ROI:</span>
                <span className={`font-semibold ${pnlColor}`}>
                  {roi >= 0 ? '+' : ''}{roi.toFixed(2)}%
                </span>
              </div>
            </div>
          )}

          <div>
            <label className="text-gray-400 text-xs mb-2 block">Execution Type</label>
            <select className="w-full bg-[#1a1d23] text-white px-4 py-3 rounded-md border border-[#2b2e35] focus:outline-none focus:border-[#f0b90b]">
              <option>Market</option>
              <option disabled>Limit (Coming Soon)</option>
            </select>
          </div>

          <div className="flex gap-2 pt-2">
            <button
              onClick={onClose}
              disabled={isSubmitting}
              className="flex-1 py-3 bg-[#2b2e35] hover:bg-[#31353d] text-white rounded-md font-medium transition-colors disabled:opacity-50"
            >
              Cancel
            </button>
            {currentValue && (
              <button
                onClick={handleRemove}
                disabled={isSubmitting}
                className="flex-1 py-3 bg-[#3a3d45] hover:bg-[#44474f] text-white rounded-md font-medium transition-colors disabled:opacity-50"
              >
                Remove
              </button>
            )}
            <button
              onClick={handleConfirm}
              disabled={isSubmitting || !inputValue}
              className={`flex-1 py-3 ${
                isTP
                  ? 'bg-green-500 hover:bg-green-600'
                  : 'bg-red-500 hover:bg-red-600'
              } text-white rounded-md font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              {isSubmitting ? 'Processing...' : 'Confirm'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

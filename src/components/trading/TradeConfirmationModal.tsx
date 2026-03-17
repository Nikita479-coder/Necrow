import { X, Info } from 'lucide-react';
import { useState } from 'react';

interface TradeConfirmationModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  orderType: 'Market' | 'Limit';
  side: 'Long' | 'Short';
  pair: string;
  price: string;
  lastPrice: string;
  quantity: string;
  leverage: number;
  orderCost: number;
  orderValue: number;
  estimatedLiqPrice: string;
  marginMode: string;
  initialMarginRate: string;
  maintenanceMarginRate: string;
}

interface TooltipProps {
  text: string;
  children: React.ReactNode;
}

function Tooltip({ text, children }: TooltipProps) {
  const [show, setShow] = useState(false);

  return (
    <div className="relative inline-block">
      <div
        onMouseEnter={() => setShow(true)}
        onMouseLeave={() => setShow(false)}
        onClick={() => setShow(!show)}
      >
        {children}
      </div>
      {show && (
        <div className="absolute z-50 bottom-full left-1/2 -translate-x-1/2 mb-2 w-64 px-3 py-2 text-xs text-white bg-[#2b2e35] rounded border border-[#3a3d45] shadow-lg">
          {text}
          <div className="absolute top-full left-1/2 -translate-x-1/2 -mt-1 border-4 border-transparent border-t-[#2b2e35]"></div>
        </div>
      )}
    </div>
  );
}

export default function TradeConfirmationModal({
  isOpen,
  onClose,
  onConfirm,
  orderType,
  side,
  pair,
  price,
  lastPrice,
  quantity,
  leverage,
  orderCost,
  orderValue,
  estimatedLiqPrice,
  marginMode,
  initialMarginRate,
  maintenanceMarginRate,
}: TradeConfirmationModalProps) {
  const [dontShowAgain, setDontShowAgain] = useState(false);

  if (!isOpen) return null;

  const handleConfirm = () => {
    if (dontShowAgain) {
      localStorage.setItem('hideTradeConfirmation', 'true');
    }
    onConfirm();
  };

  const sideColor = side === 'Long' ? 'text-[#0ecb81]' : 'text-[#f6465d]';
  const buttonColor = side === 'Long' ? 'bg-[#0ecb81] hover:bg-[#0bb872]' : 'bg-[#f6465d] hover:bg-[#e0415c]';

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
      <div className="bg-[#1a1d23] rounded-lg w-full max-w-lg border border-[#2b2e35]">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-[#2b2e35]">
          <h3 className="text-base font-medium">
            <span className={sideColor}>{orderType} {side}</span> {pair}
          </h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        {/* Content */}
        <div className="p-4 space-y-3">
          {/* Order Price vs Last Traded Price */}
          <div className="flex justify-between text-sm">
            <div className="flex items-center gap-1 text-gray-400">
              Order Price
              <Tooltip text="The price at which your order will be executed. For market orders, this is the current market price. For limit orders, this is your specified price.">
                <Info size={12} className="text-gray-600 cursor-help hover:text-gray-400 transition-colors" />
              </Tooltip>
            </div>
            <div className="text-gray-400">Last Traded Price</div>
          </div>

          {/* Quantity and Price */}
          <div className="flex justify-between text-sm">
            <div className="text-gray-400">Qty</div>
            <div className="text-white font-medium">{quantity} {pair.replace('USDT', '')}</div>
          </div>

          {/* Order Cost */}
          <div className="flex justify-between text-sm">
            <div className="text-gray-400">Order Cost</div>
            <div className="text-white font-medium">{orderCost.toLocaleString(undefined, { minimumFractionDigits: 4, maximumFractionDigits: 4 })} USDT</div>
          </div>

          {/* Order Value */}
          <div className="flex justify-between text-sm">
            <div className="text-gray-400">Order Value</div>
            <div className="text-white font-medium">{orderValue.toLocaleString(undefined, { minimumFractionDigits: 4, maximumFractionDigits: 4 })} USDT</div>
          </div>

          {/* Estimated Liquidation Price */}
          <div className="flex justify-between text-sm">
            <div className="flex items-center gap-1 text-gray-400">
              Estimated Liq. Price
              <Tooltip text="The price at which your position will be automatically liquidated if the market moves against you. This happens when your losses approach your initial margin. Higher leverage means liquidation price is closer to entry price.">
                <Info size={12} className="text-gray-600 cursor-help hover:text-gray-400 transition-colors" />
              </Tooltip>
            </div>
            <div className="text-[#f0b90b] font-medium">{estimatedLiqPrice} USDT</div>
          </div>

          {/* Leverage */}
          <div className="flex justify-between text-sm">
            <div className="text-gray-400">Leverage</div>
            <div className="text-white font-medium">{marginMode} {leverage}.00x</div>
          </div>

          {/* Time in Force */}
          <div className="flex justify-between text-sm">
            <div className="text-gray-400">Time in Force</div>
            <div className="text-white font-medium">{orderType === 'Market' ? 'Immediate-Or-Cancel' : 'Good Till Cancel'}</div>
          </div>

          {/* Initial Margin Rate */}
          <div className="flex justify-between text-sm">
            <div className="flex items-center gap-1 text-gray-400">
              Initial Margin Rate
              <Tooltip text="The minimum percentage of the position value you must provide as collateral to open this trade. This is calculated as 1/leverage. For example, 20x leverage requires 5% initial margin (1/20 = 0.05 = 5%).">
                <Info size={12} className="text-gray-600 cursor-help hover:text-gray-400 transition-colors" />
              </Tooltip>
            </div>
            <div className="text-white font-medium">{initialMarginRate}</div>
          </div>

          {/* Maintenance Margin Rate */}
          <div className="flex justify-between text-sm">
            <div className="flex items-center gap-1 text-gray-400">
              Maintenance Margin Rate
              <Tooltip text="The minimum margin level required to keep your position open. If your margin falls below this level due to losses, your position will be liquidated. This rate varies based on leverage: higher leverage has lower maintenance margin rates.">
                <Info size={12} className="text-gray-600 cursor-help hover:text-gray-400 transition-colors" />
              </Tooltip>
            </div>
            <div className="text-white font-medium">{maintenanceMarginRate}</div>
          </div>

          {/* Checkbox */}
          <div className="pt-2">
            <label className="flex items-center gap-2 text-xs text-gray-400 cursor-pointer">
              <input
                type="checkbox"
                checked={dontShowAgain}
                onChange={(e) => setDontShowAgain(e.target.checked)}
                className="w-4 h-4 rounded border-gray-600 bg-[#0c0d0f] text-[#0ecb81] focus:ring-0 focus:ring-offset-0"
              />
              Do not show confirmation window anymore
            </label>
          </div>
        </div>

        {/* Footer Buttons */}
        <div className="flex gap-3 p-4 border-t border-[#2b2e35]">
          <button
            onClick={handleConfirm}
            className={`flex-1 ${buttonColor} text-white py-3 rounded font-medium transition-colors`}
          >
            Confirm
          </button>
          <button
            onClick={onClose}
            className="flex-1 bg-[#2b2e35] hover:bg-[#3a3d45] text-white py-3 rounded font-medium transition-colors"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
}

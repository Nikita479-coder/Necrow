import { useState, useEffect } from 'react';
import { X, Calculator } from 'lucide-react';
import { usePrice } from '../../hooks/usePrices';

interface TradingCalculatorProps {
  pair: string;
  onClose: () => void;
}

type CalculatorTab = 'profit' | 'target' | 'liquidation' | 'entry';

function TradingCalculator({ pair, onClose }: TradingCalculatorProps) {
  const [activeTab, setActiveTab] = useState<CalculatorTab>('profit');
  const [side, setSide] = useState<'long' | 'short'>('long');
  const [leverage, setLeverage] = useState('10');
  const [entryPrice, setEntryPrice] = useState('');
  const [closePrice, setClosePrice] = useState('');
  const [quantity, setQuantity] = useState('');
  const [targetProfit, setTargetProfit] = useState('');
  const [targetProfitType, setTargetProfitType] = useState<'amount' | 'percent'>('amount');
  const [liquidationPrice, setLiquidationPrice] = useState('');
  const [targetPrice, setTargetPrice] = useState('');

  const symbolWithSlash = pair.replace('USDT', '/USDT');
  const priceData = usePrice(symbolWithSlash);
  const baseCurrency = pair.replace('USDT', '');
  const currentPrice = priceData ? parseFloat(priceData.price) : 0;

  useEffect(() => {
    if (currentPrice && !entryPrice) {
      setEntryPrice(currentPrice.toFixed(2));
    }
  }, [currentPrice]);

  const calculateProfitLoss = () => {
    const entry = parseFloat(entryPrice) || 0;
    const close = parseFloat(closePrice) || 0;
    const qty = parseFloat(quantity) || 0;
    const lev = parseFloat(leverage) || 1;

    if (!entry || !close || !qty) {
      return {
        initialMargin: 0,
        profitLoss: 0,
        profitLossPercent: 0,
        roi: 0
      };
    }

    const positionValue = qty * entry;
    const initialMargin = positionValue / lev;

    let profitLoss = 0;
    if (side === 'long') {
      profitLoss = (close - entry) * qty;
    } else {
      profitLoss = (entry - close) * qty;
    }

    const profitLossPercent = (profitLoss / positionValue) * 100;
    const roi = (profitLoss / initialMargin) * 100;

    return {
      initialMargin,
      profitLoss,
      profitLossPercent,
      roi
    };
  };

  const calculateTargetPrice = () => {
    const entry = parseFloat(entryPrice) || 0;
    const qty = parseFloat(quantity) || 0;
    const lev = parseFloat(leverage) || 1;
    const target = parseFloat(targetProfit) || 0;

    if (!entry || !qty || !target) {
      return { targetPrice: 0, initialMargin: 0 };
    }

    const positionValue = qty * entry;
    const initialMargin = positionValue / lev;

    let targetPrice = 0;
    if (targetProfitType === 'amount') {
      if (side === 'long') {
        targetPrice = entry + (target / qty);
      } else {
        targetPrice = entry - (target / qty);
      }
    } else {
      const profitAmount = (target / 100) * positionValue;
      if (side === 'long') {
        targetPrice = entry + (profitAmount / qty);
      } else {
        targetPrice = entry - (profitAmount / qty);
      }
    }

    return { targetPrice, initialMargin };
  };

  const calculateLiquidation = () => {
    const entry = parseFloat(entryPrice) || 0;
    const qty = parseFloat(quantity) || 0;
    const lev = parseFloat(leverage) || 1;

    if (!entry || !qty) {
      return { liquidationPrice: 0, initialMargin: 0 };
    }

    const positionValue = qty * entry;
    const initialMargin = positionValue / lev;
    const maintenanceMarginRate = 0.005;

    let liquidationPrice = 0;
    if (side === 'long') {
      liquidationPrice = entry * (1 - (1 / lev) + maintenanceMarginRate);
    } else {
      liquidationPrice = entry * (1 + (1 / lev) - maintenanceMarginRate);
    }

    return { liquidationPrice, initialMargin };
  };

  const calculateEntryPrice = () => {
    const target = parseFloat(targetPrice) || 0;
    const liq = parseFloat(liquidationPrice) || 0;

    if (!target || !liq) {
      return { entryPrice: 0, leverage: 0 };
    }

    const maintenanceMarginRate = 0.005;

    let calcEntry = 0;
    let calcLeverage = 0;

    if (side === 'long') {
      calcEntry = liq / (1 - (1 / 10) + maintenanceMarginRate);
      calcLeverage = 1 / (1 - (liq / calcEntry) + maintenanceMarginRate);
    } else {
      calcEntry = liq / (1 + (1 / 10) - maintenanceMarginRate);
      calcLeverage = 1 / ((calcEntry / liq) - 1 + maintenanceMarginRate);
    }

    return { entryPrice: calcEntry, leverage: calcLeverage };
  };

  const results = activeTab === 'profit' ? calculateProfitLoss() :
                  activeTab === 'target' ? calculateTargetPrice() :
                  activeTab === 'liquidation' ? calculateLiquidation() :
                  calculateEntryPrice();

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-[#1e2329] rounded-lg w-full max-w-3xl max-h-[90vh] overflow-hidden flex flex-col">
        <div className="flex items-center justify-between p-4 border-b border-gray-700">
          <div className="flex items-center gap-2">
            <Calculator className="w-5 h-5 text-[#f0b90b]" />
            <h2 className="text-lg font-semibold text-white">{pair}</h2>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex border-b border-gray-700">
          <button
            onClick={() => setActiveTab('profit')}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${
              activeTab === 'profit'
                ? 'text-white border-b-2 border-[#f0b90b]'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Profit/Loss
          </button>
          <button
            onClick={() => setActiveTab('target')}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${
              activeTab === 'target'
                ? 'text-white border-b-2 border-[#f0b90b]'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Target Price
          </button>
          <button
            onClick={() => setActiveTab('liquidation')}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${
              activeTab === 'liquidation'
                ? 'text-white border-b-2 border-[#f0b90b]'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Liq. Price
          </button>
          <button
            onClick={() => setActiveTab('entry')}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${
              activeTab === 'entry'
                ? 'text-white border-b-2 border-[#f0b90b]'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Entry Price
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6">
          <div className="grid grid-cols-2 gap-6">
            <div className="space-y-4">
              <div className="flex gap-2">
                <button
                  onClick={() => setSide('long')}
                  className={`flex-1 py-2 rounded font-medium transition-colors ${
                    side === 'long'
                      ? 'bg-[#0ecb81] text-white'
                      : 'bg-[#1e2329] text-gray-400 border border-gray-700'
                  }`}
                >
                  Long
                </button>
                <button
                  onClick={() => setSide('short')}
                  className={`flex-1 py-2 rounded font-medium transition-colors ${
                    side === 'short'
                      ? 'bg-[#f6465d] text-white'
                      : 'bg-[#1e2329] text-gray-400 border border-gray-700'
                  }`}
                >
                  Short
                </button>
              </div>

              {activeTab !== 'entry' && (
                <>
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Leverage</label>
                    <div className="relative">
                      <input
                        type="text"
                        value={leverage}
                        onChange={(e) => setLeverage(e.target.value)}
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 pr-8 text-white focus:outline-none focus:border-[#f0b90b]"
                      />
                      <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">x</span>
                    </div>
                    <p className="text-xs text-[#f0b90b] mt-1">
                      Max Position at Current Leverage: {(parseFloat(leverage) || 0) > 0 ? '0 USDT' : '0 USDT'}
                    </p>
                  </div>

                  <div>
                    <label className="flex items-center justify-between text-sm text-gray-400 mb-2">
                      <span>Entry Price</span>
                      <span className="text-xs">Price: --</span>
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={entryPrice}
                        onChange={(e) => setEntryPrice(e.target.value)}
                        placeholder="Enter Price"
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 text-white focus:outline-none focus:border-[#f0b90b]"
                      />
                      <button
                        onClick={() => setEntryPrice(currentPrice.toFixed(2))}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-[#f0b90b] hover:text-[#f0b90b]/80"
                      >
                        Last
                      </button>
                    </div>
                  </div>
                </>
              )}

              {activeTab === 'profit' && (
                <>
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Close Price</label>
                    <div className="relative">
                      <input
                        type="text"
                        value={closePrice}
                        onChange={(e) => setClosePrice(e.target.value)}
                        placeholder="Enter Price"
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 text-white focus:outline-none focus:border-[#f0b90b]"
                      />
                      <button
                        onClick={() => setClosePrice(currentPrice.toFixed(2))}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-[#f0b90b] hover:text-[#f0b90b]/80"
                      >
                        Last
                      </button>
                    </div>
                  </div>

                  <div>
                    <label className="flex items-center justify-between text-sm text-gray-400 mb-2">
                      <span>Qty</span>
                      <span className="text-xs">Position: --</span>
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={quantity}
                        onChange={(e) => setQuantity(e.target.value)}
                        placeholder="Enter Quantity"
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 pr-16 text-white focus:outline-none focus:border-[#f0b90b]"
                      />
                      <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">{baseCurrency}</span>
                    </div>
                  </div>
                </>
              )}

              {activeTab === 'target' && (
                <>
                  <div>
                    <label className="flex items-center justify-between text-sm text-gray-400 mb-2">
                      <span>Qty</span>
                      <span className="text-xs">Position: --</span>
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={quantity}
                        onChange={(e) => setQuantity(e.target.value)}
                        placeholder="Enter Quantity"
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 pr-16 text-white focus:outline-none focus:border-[#f0b90b]"
                      />
                      <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">{baseCurrency}</span>
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Target Profit</label>
                    <div className="relative">
                      <input
                        type="text"
                        value={targetProfit}
                        onChange={(e) => setTargetProfit(e.target.value)}
                        placeholder="Enter Amount"
                        className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 pr-20 text-white focus:outline-none focus:border-[#f0b90b]"
                      />
                      <select
                        value={targetProfitType}
                        onChange={(e) => setTargetProfitType(e.target.value as 'amount' | 'percent')}
                        className="absolute right-2 top-1/2 -translate-y-1/2 bg-transparent text-sm text-gray-400 focus:outline-none cursor-pointer"
                      >
                        <option value="amount">USDT</option>
                        <option value="percent">%</option>
                      </select>
                    </div>
                  </div>
                </>
              )}

              {activeTab === 'liquidation' && (
                <div>
                  <label className="flex items-center justify-between text-sm text-gray-400 mb-2">
                    <span>Qty</span>
                    <span className="text-xs">Position: --</span>
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      value={quantity}
                      onChange={(e) => setQuantity(e.target.value)}
                      placeholder="Enter Quantity"
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 pr-16 text-white focus:outline-none focus:border-[#f0b90b]"
                    />
                    <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-400">{baseCurrency}</span>
                  </div>
                </div>
              )}

              {activeTab === 'entry' && (
                <>
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Target Price</label>
                    <input
                      type="text"
                      value={targetPrice}
                      onChange={(e) => setTargetPrice(e.target.value)}
                      placeholder="Enter Price"
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 text-white focus:outline-none focus:border-[#f0b90b]"
                    />
                  </div>

                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Liquidation Price</label>
                    <input
                      type="text"
                      value={liquidationPrice}
                      onChange={(e) => setLiquidationPrice(e.target.value)}
                      placeholder="Enter Price"
                      className="w-full bg-[#0b0e11] border border-gray-700 rounded px-3 py-2.5 text-white focus:outline-none focus:border-[#f0b90b]"
                    />
                  </div>
                </>
              )}
            </div>

            <div>
              <div className="bg-[#0b0e11] rounded-lg p-4 border border-gray-700">
                <h3 className="text-sm font-medium text-gray-400 mb-4 flex items-center gap-2">
                  Results
                  <span className="text-xs">↓</span>
                </h3>

                {activeTab === 'profit' && (
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Initial Margin</span>
                      <span className="text-sm text-white font-medium">
                        {results.initialMargin?.toFixed(2) || '0.00'} USDT
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Profit/Loss</span>
                      <span className={`text-sm font-medium ${
                        (results.profitLoss || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'
                      }`}>
                        {(results.profitLoss || 0) >= 0 ? '+' : ''}{results.profitLoss?.toFixed(4) || '0.0000'} USDT
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Profit/Loss%</span>
                      <span className={`text-sm font-medium ${
                        (results.profitLossPercent || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'
                      }`}>
                        {(results.profitLossPercent || 0) >= 0 ? '+' : ''}{results.profitLossPercent?.toFixed(2) || '0.00'}%
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">ROI</span>
                      <span className={`text-sm font-medium ${
                        (results.roi || 0) >= 0 ? 'text-[#0ecb81]' : 'text-[#f6465d]'
                      }`}>
                        {(results.roi || 0) >= 0 ? '+' : ''}{results.roi?.toFixed(2) || '0.00'}%
                      </span>
                    </div>
                  </div>
                )}

                {activeTab === 'target' && (
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Initial Margin</span>
                      <span className="text-sm text-white font-medium">
                        {results.initialMargin?.toFixed(2) || '0.00'} USDT
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Target Price</span>
                      <span className="text-sm text-[#f0b90b] font-medium">
                        {results.targetPrice?.toFixed(2) || '0.00'} USDT
                      </span>
                    </div>
                  </div>
                )}

                {activeTab === 'liquidation' && (
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Initial Margin</span>
                      <span className="text-sm text-white font-medium">
                        {results.initialMargin?.toFixed(2) || '0.00'} USDT
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Liquidation Price</span>
                      <span className="text-sm text-[#f6465d] font-medium">
                        {results.liquidationPrice?.toFixed(2) || '0.00'} USDT
                      </span>
                    </div>
                  </div>
                )}

                {activeTab === 'entry' && (
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Entry Price</span>
                      <span className="text-sm text-white font-medium">
                        {results.entryPrice?.toFixed(2) || '0.00'} USDT
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Leverage</span>
                      <span className="text-sm text-[#f0b90b] font-medium">
                        {results.leverage?.toFixed(2) || '0.00'}x
                      </span>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default TradingCalculator;

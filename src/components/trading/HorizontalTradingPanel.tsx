import { useState, useEffect } from 'react';
import { Info, ChevronDown } from 'lucide-react';
import { usePrice } from '../../hooks/usePrices';
import { useAuth } from '../../context/AuthContext';
import { useNavigation } from '../../App';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';
import { ToastContainer } from '../Toast';

interface HorizontalTradingPanelProps {
  pair: string;
}

function HorizontalTradingPanel({ pair }: HorizontalTradingPanelProps) {
  const { isAuthenticated, user } = useAuth();
  const { navigateTo } = useNavigation();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const [size, setSize] = useState('');
  const [marginMode, setMarginMode] = useState<'Cross' | 'Isolated'>('Cross');
  const [leverage, setLeverage] = useState(20);
  const [showLeverageModal, setShowLeverageModal] = useState(false);
  const [tpslEnabled, setTpslEnabled] = useState(false);
  const [stopLoss, setStopLoss] = useState('');
  const [takeProfit, setTakeProfit] = useState('');
  const [tpMode, setTpMode] = useState<'price' | 'pnl' | 'percent'>('price');
  const [slMode, setSlMode] = useState<'price' | 'pnl' | 'percent'>('price');
  const [isPlacingOrder, setIsPlacingOrder] = useState(false);
  const [futuresBalance, setFuturesBalance] = useState(0);
  const [availableMargin, setAvailableMargin] = useState(0);
  const [usedMargin, setUsedMargin] = useState(0);
  const [sizeUnit, setSizeUnit] = useState<string>('BTC');
  const [maxLeverage, setMaxLeverage] = useState(125);
  const [orderType] = useState<'Market' | 'Limit'>('Market');

  const symbolWithSlash = pair.replace('USDT', '/USDT');
  const priceData = usePrice(symbolWithSlash);
  const baseCurrency = pair.replace('USDT', '');

  useEffect(() => {
    setSizeUnit(baseCurrency);
  }, [baseCurrency]);

  useEffect(() => {
    if (user) {
      fetchFuturesBalance();
      const interval = setInterval(fetchFuturesBalance, 2000);
      return () => clearInterval(interval);
    }
  }, [user]);

  useEffect(() => {
    if (user && pair) {
      fetchMaxLeverage();
    }
  }, [user, pair]);

  const fetchFuturesBalance = async () => {
    if (!user) return;
    try {
      const { data, error } = await supabase.rpc('get_wallet_balances', {
        p_user_id: user.id
      });
      if (!error && data) {
        // Updated to match new data structure from get_wallet_balances
        const available = parseFloat(data.futures?.available_balance || 0);
        const locked = parseFloat(data.futures?.locked_balance || 0);
        const lockedBonus = parseFloat(data.locked_bonus?.balance || 0);
        const totalAvailable = parseFloat(data.total_trading_available || 0);
        const totalEquity = parseFloat(data.futures?.total_equity || 0);
        const marginInPositions = parseFloat(data.futures?.margin_in_positions || 0);

        setFuturesBalance(totalEquity);
        setAvailableMargin(totalAvailable); // Includes locked bonus
        setUsedMargin(marginInPositions);
      }
    } catch (err) {
      console.error('Error fetching balance:', err);
    }
  };

  const fetchMaxLeverage = async () => {
    if (!user || !pair) return;
    try {
      const [pairConfig, userLimit] = await Promise.all([
        supabase
          .from('trading_pairs_config')
          .select('max_leverage')
          .eq('pair', pair)
          .maybeSingle(),
        supabase
          .from('user_leverage_limits')
          .select('max_allowed_leverage')
          .eq('user_id', user.id)
          .maybeSingle()
      ]);

      const pairMaxLeverage = pairConfig.data?.max_leverage || 40;
      const userMaxLeverage = userLimit.data?.max_allowed_leverage || 40;
      const effectiveMaxLeverage = Math.min(pairMaxLeverage, userMaxLeverage);
      setMaxLeverage(effectiveMaxLeverage);

      if (leverage > effectiveMaxLeverage) {
        setLeverage(effectiveMaxLeverage);
      }
    } catch (err) {
      console.error('Error fetching max leverage:', err);
      setMaxLeverage(40);
    }
  };

  const getSizeInBaseCurrency = (): number => {
    if (!size || !priceData) return 0;
    const sizeValue = parseFloat(size);
    if (sizeUnit === baseCurrency) {
      return sizeValue;
    } else {
      const currentPrice = parseFloat(priceData.price) || 0;
      return currentPrice > 0 ? sizeValue / currentPrice : 0;
    }
  };

  const getSizeInUSDT = (): number => {
    if (!size || !priceData) return 0;
    const sizeValue = parseFloat(size);
    if (sizeUnit === 'USDT') {
      return sizeValue;
    } else {
      const currentPrice = parseFloat(priceData.price) || 0;
      return sizeValue * currentPrice;
    }
  };

  const getRequiredMargin = (): number => {
    if (!priceData) return 0;
    const baseSize = getSizeInBaseCurrency();
    const currentPrice = parseFloat(priceData.price) || 0;
    const positionValue = baseSize * currentPrice;
    return positionValue / leverage;
  };

  const toggleSizeUnit = () => {
    if (!size || !priceData) {
      setSizeUnit(sizeUnit === baseCurrency ? 'USDT' : baseCurrency);
      return;
    }

    const sizeValue = parseFloat(size);
    const currentPrice = parseFloat(priceData.price);

    if (sizeUnit === baseCurrency) {
      const usdtValue = sizeValue * currentPrice;
      setSize(usdtValue.toFixed(2));
      setSizeUnit('USDT');
    } else {
      const baseValue = sizeValue / currentPrice;
      setSize(baseValue.toFixed(4));
      setSizeUnit(baseCurrency);
    }
  };

  const handlePercentage = (percent: number) => {
    if (!priceData) return;
    const maxAvailable = availableMargin * leverage;
    const targetValue = maxAvailable * (percent / 100);
    const currentPrice = parseFloat(priceData.price) || 1;

    if (sizeUnit === baseCurrency) {
      const baseSize = targetValue / currentPrice;
      setSize(baseSize.toFixed(4));
    } else {
      setSize(targetValue.toFixed(2));
    }
  };

  const convertToPrice = (value: string, mode: 'price' | 'pnl' | 'percent', isTP: boolean): number | null => {
    if (!value || !priceData) return null;

    const numValue = parseFloat(value);
    const currentPrice = parseFloat(priceData.price);
    const quantity = parseFloat(size);

    if (mode === 'price') return numValue;
    if (mode === 'pnl') {
      const priceChange = numValue / (quantity * leverage);
      return isTP ? currentPrice + priceChange : currentPrice - priceChange;
    }
    if (mode === 'percent') {
      const percentChange = numValue / 100;
      return isTP ? currentPrice * (1 + percentChange) : currentPrice * (1 - percentChange);
    }
    return null;
  };

  const handlePlaceOrder = async (orderSide: 'long' | 'short') => {
    if (!user || !isAuthenticated) return;
    if (!size || parseFloat(size) <= 0) {
      showError('Please enter a valid quantity');
      return;
    }

    const requiredMargin = getRequiredMargin();
    if (requiredMargin > availableMargin) {
      showError(`Insufficient margin. Required: ${requiredMargin.toFixed(2)} USDT`);
      return;
    }

    setIsPlacingOrder(true);

    try {
      const quantity = getSizeInBaseCurrency();
      const slPrice = convertToPrice(stopLoss, slMode, false);
      const tpPrice = convertToPrice(takeProfit, tpMode, true);

      const currentMarketPrice = priceData ? parseFloat(priceData.price) : null;

      const { data, error } = await supabase.rpc('place_futures_order', {
        p_user_id: user.id,
        p_pair: pair,
        p_side: orderSide,
        p_order_type: 'market',
        p_leverage: leverage,
        p_margin: requiredMargin,
        p_quantity: quantity,
        p_limit_price: null,
        p_take_profit: tpPrice,
        p_stop_loss: slPrice,
        p_current_price: currentMarketPrice
      });

      if (error) {
        showError(error.message || 'Failed to place order');
        return;
      }

      if (data && !data.success) {
        showError(data.error || 'Failed to place order');
        return;
      }

      showSuccess(`${orderSide === 'long' ? 'Long' : 'Short'} order placed successfully!`);
      setSize('');
      setStopLoss('');
      setTakeProfit('');
    } catch (err) {
      showError('An error occurred while placing the order');
    } finally {
      setIsPlacingOrder(false);
    }
  };

  return (
    <div className="bg-[#0b0e11]">
      <div className="border-t border-gray-800">
        <div className="flex flex-wrap items-center gap-4 px-6 py-3 bg-[#0b0e11]">
          <div className="flex-1 min-w-[180px]">
            <div className="text-xs text-gray-500 mb-1">Futures Wallet</div>
            <div className="text-2xl font-bold text-white">{futuresBalance.toFixed(2)} <span className="text-base text-gray-400">USDT</span></div>
            <div className="flex gap-4 mt-1 text-xs">
              <div>
                <span className="text-gray-500">Available </span>
                <span className="text-[#0ecb81] font-semibold">{availableMargin.toFixed(2)}</span>
              </div>
              <div>
                <span className="text-gray-500">In Use </span>
                <span className="text-gray-400 font-semibold">{usedMargin.toFixed(2)}</span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2">
              <span className="text-xs text-gray-500">Margin</span>
              <button
                onClick={() => setMarginMode('Cross')}
                className={`px-3 py-1.5 text-xs font-medium rounded transition-colors ${
                  marginMode === 'Cross' ? 'bg-[#f0b90b] text-black' : 'bg-[#1e2329] text-gray-400 hover:text-white'
                }`}
              >
                Cross
              </button>
              <button
                onClick={() => setMarginMode('Isolated')}
                className={`px-3 py-1.5 text-xs font-medium rounded transition-colors ${
                  marginMode === 'Isolated' ? 'bg-[#f0b90b] text-black' : 'bg-[#1e2329] text-gray-400 hover:text-white'
                }`}
              >
                Isolated
              </button>
            </div>

          </div>
        </div>

        <div className="border-t border-gray-800">
          <div className="px-6 py-4">
            <div className="flex items-center justify-between mb-4">
              <span className="text-sm text-gray-500">Order Type:</span>
              <span className="text-sm text-[#f0b90b] font-semibold">Market</span>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
              <div className="space-y-3">
                <div>
                  <label className="block text-xs text-gray-500 mb-2">Market Price (USDT)</label>
                  <input
                    type="text"
                    value={priceData ? parseFloat(priceData.price).toFixed(2) : '---'}
                    readOnly
                    className="w-full bg-[#1e2329] border border-gray-700 rounded px-3 py-2.5 text-gray-400 cursor-not-allowed"
                    placeholder="0.00"
                  />
                </div>

                <div>
                  <label className="block text-xs text-gray-500 mb-2">Size</label>
                  <div className="relative">
                    <input
                      type="text"
                      value={size}
                      onChange={(e) => setSize(e.target.value)}
                      placeholder="0.0000"
                      className="w-full bg-[#1e2329] border border-gray-700 rounded px-3 py-2.5 pr-20 text-white focus:outline-none focus:border-[#f0b90b] transition-colors"
                    />
                    <button
                      onClick={toggleSizeUnit}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-[#f0b90b] font-medium transition-colors"
                    >
                      {sizeUnit}
                    </button>
                  </div>
                </div>

                <div className="grid grid-cols-4 gap-2">
                  {[25, 50, 75, 100].map((percent) => (
                    <button
                      key={percent}
                      onClick={() => handlePercentage(percent)}
                      className="px-2 py-1.5 text-xs bg-[#1e2329] hover:bg-[#2b3139] border border-gray-700 rounded text-gray-400 hover:text-white font-medium transition-colors"
                    >
                      {percent}%
                    </button>
                  ))}
                </div>

                <div className="bg-[#1e2329] rounded p-3 border border-gray-700">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs text-gray-500">Leverage</span>
                    <span className="text-base text-[#f0b90b] font-semibold">{leverage}x</span>
                  </div>
                  <input
                    type="range"
                    min="1"
                    max={maxLeverage}
                    value={leverage}
                    onChange={(e) => setLeverage(parseInt(e.target.value))}
                    className="w-full h-1 bg-[#2b3139] rounded-lg appearance-none cursor-pointer accent-[#f0b90b]"
                  />
                  <div className="flex justify-between text-xs text-gray-500 mt-1">
                    <span>1x</span>
                    <span>{maxLeverage}x</span>
                  </div>
                </div>

                {size && parseFloat(size) > 0 && (
                  <div className="bg-[#1e2329] rounded p-3 border border-gray-700">
                    <div className="flex justify-between text-xs mb-1">
                      <span className="text-gray-500">Value</span>
                      <span className="text-white">{getSizeInUSDT().toFixed(2)} USDT</span>
                    </div>
                    <div className="flex justify-between text-xs">
                      <span className="text-gray-500">Required Margin</span>
                      <span className={getRequiredMargin() > availableMargin ? 'text-red-500' : 'text-[#f0b90b]'}>
                        {getRequiredMargin().toFixed(2)} USDT
                      </span>
                    </div>
                  </div>
                )}

                {isAuthenticated ? (
                  <button
                    onClick={() => handlePlaceOrder('long')}
                    disabled={isPlacingOrder}
                    className="w-full py-3 bg-[#0ecb81] hover:bg-[#0bb36a] disabled:bg-gray-700 disabled:cursor-not-allowed text-white text-sm font-medium rounded transition-colors"
                  >
                    Buy / Long
                  </button>
                ) : (
                  <button
                    onClick={() => navigateTo('signin')}
                    className="w-full py-3 bg-[#0ecb81] hover:bg-[#0bb36a] text-white text-sm font-medium rounded transition-colors"
                  >
                    Sign In to Trade
                  </button>
                )}
              </div>

              <div className="space-y-3">
                <div>
                  <label className="block text-xs text-gray-500 mb-2">Price (USDT)</label>
                  <input
                    type="text"
                    value={price}
                    onChange={(e) => setPrice(e.target.value)}
                    disabled={orderType === 'Market'}
                    className="w-full bg-[#1e2329] border border-gray-700 rounded px-3 py-2.5 text-white focus:outline-none focus:border-[#f0b90b] disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    placeholder="0.00"
                  />
                </div>

                <div>
                  <label className="block text-xs text-gray-500 mb-2">Size</label>
                  <div className="relative">
                    <input
                      type="text"
                      value={size}
                      onChange={(e) => setSize(e.target.value)}
                      placeholder="0.0000"
                      className="w-full bg-[#1e2329] border border-gray-700 rounded px-3 py-2.5 pr-20 text-white focus:outline-none focus:border-[#f0b90b] transition-colors"
                    />
                    <button
                      onClick={toggleSizeUnit}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-[#f0b90b] font-medium transition-colors"
                    >
                      {sizeUnit}
                    </button>
                  </div>
                </div>

                <div className="grid grid-cols-4 gap-2">
                  {[25, 50, 75, 100].map((percent) => (
                    <button
                      key={percent}
                      onClick={() => handlePercentage(percent)}
                      className="px-2 py-1.5 text-xs bg-[#1e2329] hover:bg-[#2b3139] border border-gray-700 rounded text-gray-400 hover:text-white font-medium transition-colors"
                    >
                      {percent}%
                    </button>
                  ))}
                </div>

                <div className="bg-[#1e2329] rounded p-3 border border-gray-700">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs text-gray-500">Leverage</span>
                    <span className="text-base text-[#f0b90b] font-semibold">{leverage}x</span>
                  </div>
                  <input
                    type="range"
                    min="1"
                    max={maxLeverage}
                    value={leverage}
                    onChange={(e) => setLeverage(parseInt(e.target.value))}
                    className="w-full h-1 bg-[#2b3139] rounded-lg appearance-none cursor-pointer accent-[#f0b90b]"
                  />
                  <div className="flex justify-between text-xs text-gray-500 mt-1">
                    <span>1x</span>
                    <span>{maxLeverage}x</span>
                  </div>
                </div>

                {size && parseFloat(size) > 0 && (
                  <div className="bg-[#1e2329] rounded p-3 border border-gray-700">
                    <div className="flex justify-between text-xs mb-1">
                      <span className="text-gray-500">Value</span>
                      <span className="text-white">{getSizeInUSDT().toFixed(2)} USDT</span>
                    </div>
                    <div className="flex justify-between text-xs">
                      <span className="text-gray-500">Required Margin</span>
                      <span className={getRequiredMargin() > availableMargin ? 'text-red-500' : 'text-[#f0b90b]'}>
                        {getRequiredMargin().toFixed(2)} USDT
                      </span>
                    </div>
                  </div>
                )}

                {isAuthenticated ? (
                  <button
                    onClick={() => handlePlaceOrder('short')}
                    disabled={isPlacingOrder}
                    className="w-full py-3 bg-[#f6465d] hover:bg-[#d93a4f] disabled:bg-gray-700 disabled:cursor-not-allowed text-white text-sm font-medium rounded transition-colors"
                  >
                    Sell / Short
                  </button>
                ) : (
                  <button
                    onClick={() => navigateTo('signin')}
                    className="w-full py-3 bg-[#f6465d] hover:bg-[#d93a4f] text-white text-sm font-medium rounded transition-colors"
                  >
                    Sign In to Trade
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      <ToastContainer toasts={toasts} removeToast={removeToast} />
    </div>
  );
}

export default HorizontalTradingPanel;

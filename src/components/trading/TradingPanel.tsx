import { useState, useEffect } from 'react';
import { Info, ChevronDown, ArrowRightLeft } from 'lucide-react';
import { usePrice } from '../../hooks/usePrices';
import { useAuth } from '../../context/AuthContext';
import { useNavigation } from '../../App';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';
import { ToastContainer } from '../Toast';
import TransferModal from '../TransferModal';

interface TradingPanelProps {
  pair: string;
}

function TradingPanel({ pair }: TradingPanelProps) {
  const { isAuthenticated, user } = useAuth();
  const { navigateTo } = useNavigation();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const [side, setSide] = useState<'Buy' | 'Sell'>('Buy');
  const [size, setSize] = useState('');
  const [marginMode, setMarginMode] = useState<'Cross' | 'Isolated'>('Cross');
  const [leverage, setLeverage] = useState(20);
  const [showLeverageModal, setShowLeverageModal] = useState(false);
  const [tpslEnabled, setTpslEnabled] = useState(false);
  const [reduceOnly, setReduceOnly] = useState(false);
  const [stopLoss, setStopLoss] = useState('');
  const [takeProfit, setTakeProfit] = useState('');
  const [tpMode, setTpMode] = useState<'price' | 'pnl' | 'percent'>('price');
  const [slMode, setSlMode] = useState<'price' | 'pnl' | 'percent'>('price');
  const [isPlacingOrder, setIsPlacingOrder] = useState(false);
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [futuresBalance, setFuturesBalance] = useState(0);
  const [availableMargin, setAvailableMargin] = useState(0);
  const [usedMargin, setUsedMargin] = useState(0);
  const [sizeUnit, setSizeUnit] = useState<'BTC' | 'USDT'>('BTC');
  const [maxLeverage, setMaxLeverage] = useState(125);

  const symbolWithSlash = pair.replace('USDT', '/USDT');
  const priceData = usePrice(symbolWithSlash);

  const baseCurrency = pair.replace('USDT', '');

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

  const getSizeInBTC = (): number => {
    if (!size || !priceData) return 0;
    const sizeValue = parseFloat(size);
    if (sizeUnit === 'BTC') {
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
    const btcSize = getSizeInBTC();
    const currentPrice = parseFloat(priceData.price) || 0;
    const positionValue = btcSize * currentPrice;
    return positionValue / leverage;
  };

  const toggleSizeUnit = () => {
    if (!size || !priceData) {
      setSizeUnit(sizeUnit === 'BTC' ? 'USDT' : 'BTC');
      return;
    }

    const sizeValue = parseFloat(size);
    const currentPrice = parseFloat(priceData.price);

    if (sizeUnit === 'BTC') {
      const usdtValue = sizeValue * currentPrice;
      setSize(usdtValue.toFixed(2));
      setSizeUnit('USDT');
    } else {
      const btcValue = sizeValue / currentPrice;
      setSize(btcValue.toFixed(4));
      setSizeUnit('BTC');
    }
  };

  const handlePercentage = (percent: number) => {
    if (!priceData) return;
    const maxAvailable = availableMargin * leverage;
    const targetValue = maxAvailable * (percent / 100);
    const currentPrice = parseFloat(priceData.price) || 1;

    if (sizeUnit === 'BTC') {
      const btcSize = targetValue / currentPrice;
      setSize(btcSize.toFixed(4));
    } else {
      setSize(targetValue.toFixed(2));
    }
  };

  const convertToPrice = (value: string, mode: 'price' | 'pnl' | 'percent', isTP: boolean): number | null => {
    if (!value || !priceData) return null;

    const numValue = parseFloat(value);
    const currentPrice = parseFloat(priceData.price);
    const quantity = parseFloat(size);

    if (mode === 'price') {
      return numValue;
    }

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

  const calculateDisplayValues = (value: string, mode: 'price' | 'pnl' | 'percent', isTP: boolean) => {
    if (!value || !priceData || !size) return { price: '', pnl: '', percent: '' };

    const numValue = parseFloat(value);
    const currentPrice = parseFloat(priceData.price);
    const quantity = parseFloat(size);

    let targetPrice = 0;

    if (mode === 'price') {
      targetPrice = numValue;
    } else if (mode === 'pnl') {
      const priceChange = numValue / (quantity * leverage);
      targetPrice = isTP ? currentPrice + priceChange : currentPrice - priceChange;
    } else if (mode === 'percent') {
      const percentChange = numValue / 100;
      targetPrice = isTP ? currentPrice * (1 + percentChange) : currentPrice * (1 - percentChange);
    }

    const priceDiff = targetPrice - currentPrice;
    const pnl = priceDiff * quantity * leverage;
    const percentChange = ((targetPrice - currentPrice) / currentPrice) * 100;

    return {
      price: targetPrice.toFixed(2),
      pnl: pnl.toFixed(2),
      percent: percentChange.toFixed(2)
    };
  };

  const tpDisplayValues = calculateDisplayValues(takeProfit, tpMode, true);
  const slDisplayValues = calculateDisplayValues(stopLoss, slMode, false);

  const handlePlaceOrder = async (orderSide: 'long' | 'short') => {
    if (!user || !isAuthenticated) return;
    if (!size || parseFloat(size) <= 0) {
      showError('Please enter a valid quantity');
      return;
    }

    const requiredMargin = getRequiredMargin();
    if (requiredMargin > availableMargin) {
      showError(`Insufficient margin. Required: ${requiredMargin.toFixed(2)} USDT, Available: ${availableMargin.toFixed(2)} USDT`);
      return;
    }

    setIsPlacingOrder(true);

    try {
      const quantity = getSizeInBTC();
      const slPrice = convertToPrice(stopLoss, slMode, false);
      const tpPrice = convertToPrice(takeProfit, tpMode, true);

      const currentMarketPrice = priceData ? parseFloat(priceData.price) : null;

      const { data, error } = await supabase.rpc('place_futures_order', {
        p_user_id: user.id,
        p_pair: pair,
        p_side: orderSide,
        p_order_type: 'market',
        p_quantity: quantity,
        p_leverage: leverage,
        p_margin_mode: marginMode.toLowerCase(),
        p_price: null,
        p_stop_loss: slPrice,
        p_take_profit: tpPrice,
        p_reduce_only: reduceOnly,
        p_market_price: currentMarketPrice
      });

      if (error) {
        console.error('Order error:', error);
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
      console.error('Order placement error:', err);
      showError('An error occurred while placing the order');
    } finally {
      setIsPlacingOrder(false);
    }
  };

  return (
    <div className="flex-1 flex flex-col bg-[#0b0e11] overflow-hidden">
      <div className="px-4 py-3 border-b border-gray-800">
        <div className="flex items-center justify-between mb-2">
          <div className="text-sm text-gray-400">
            Futures Wallet: <span className="text-white font-medium">{futuresBalance.toFixed(2)} USDT</span>
          </div>
          <button
            onClick={() => setShowTransferModal(true)}
            className="flex items-center gap-1 px-3 py-1.5 bg-[#f0b90b]/10 hover:bg-[#f0b90b]/20 text-[#f0b90b] text-xs rounded transition-colors"
          >
            <ArrowRightLeft className="w-3 h-3" />
            Transfer
          </button>
        </div>
        <div className="flex items-center gap-4 text-xs text-gray-500 mb-3">
          <div>
            Available: <span className="text-green-400 font-medium">{availableMargin.toFixed(2)} USDT</span>
          </div>
          <div>
            Used: <span className="text-[#f0b90b] font-medium">{usedMargin.toFixed(2)} USDT</span>
          </div>
        </div>
        <div className="flex gap-1 mb-4">
          <button
            onClick={() => setMarginMode('Cross')}
            className={`flex-1 px-3 py-2 text-xs rounded transition-colors ${
              marginMode === 'Cross'
                ? 'bg-[#f0b90b] text-black font-semibold'
                : 'bg-gray-900 border border-gray-800 text-gray-300 hover:bg-gray-800'
            }`}
          >
            Cross
          </button>
          <button
            onClick={() => setMarginMode('Isolated')}
            className={`flex-1 px-3 py-2 text-xs rounded transition-colors ${
              marginMode === 'Isolated'
                ? 'bg-[#f0b90b] text-black font-semibold'
                : 'bg-gray-900 border border-gray-800 text-gray-300 hover:bg-gray-800'
            }`}
          >
            Isolated
          </button>
          <button
            onClick={() => setShowLeverageModal(!showLeverageModal)}
            className="flex-1 px-3 py-2 text-xs bg-gray-900 border border-gray-800 rounded hover:bg-gray-800 transition-colors text-gray-300 font-semibold"
          >
            {leverage}x
          </button>
        </div>

        {showLeverageModal && (
          <div className="mb-4 p-3 bg-gray-900 rounded border border-gray-800">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs text-gray-400">Leverage</span>
              <span className="text-sm text-white font-semibold">{leverage}x</span>
            </div>
            <input
              type="range"
              min="1"
              max={maxLeverage}
              value={leverage}
              onChange={(e) => setLeverage(parseInt(e.target.value))}
              className="w-full h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-[#f0b90b]"
            />
            <div className="flex justify-between text-xs text-gray-500 mt-1">
              <span>1x</span>
              <span>{maxLeverage}x</span>
            </div>
            {maxLeverage < 125 && (
              <div className="mt-2 text-xs text-yellow-500 flex items-center gap-1">
                <Info size={12} />
                <span>Max {maxLeverage}x for this pair</span>
              </div>
            )}
          </div>
        )}

        <div className="space-y-3">
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-xs text-gray-500">Order Type</label>
              <span className="text-xs text-[#f0b90b] font-semibold">Market</span>
            </div>
          </div>

          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-xs text-gray-500">Avbl</label>
              <span className="text-xs text-gray-400">
                <span className="text-[#f0b90b]">{availableMargin.toFixed(2)} USDT</span>
              </span>
            </div>
          </div>

          <div>
            <label className="text-xs text-gray-500 mb-1 block">Market Price</label>
            <div className="relative">
              <input
                type="text"
                value={priceData ? parseFloat(priceData.price).toFixed(2) : '---'}
                readOnly
                className="w-full bg-gray-900 border border-gray-800 rounded px-3 py-2 text-sm text-gray-400 cursor-not-allowed"
              />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-500">
                USDT
              </span>
            </div>
          </div>

          <div>
            <label className="text-xs text-gray-500 mb-1 block">Size</label>
            <div className="relative">
              <input
                type="text"
                value={size}
                onChange={(e) => setSize(e.target.value)}
                placeholder={sizeUnit === 'BTC' ? '0.0000' : '0.00'}
                className="w-full bg-gray-900 border border-gray-800 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-[#f0b90b]/50"
              />
              <button
                onClick={toggleSizeUnit}
                className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-1 text-xs text-gray-400 hover:text-[#f0b90b] transition-colors"
              >
                {sizeUnit}
                <ChevronDown className="w-3 h-3" />
              </button>
            </div>
            {size && parseFloat(size) > 0 && (
              <>
                <div className="mt-1 flex justify-between text-xs">
                  <span className="text-gray-500">
                    ≈ {sizeUnit === 'BTC' ? `${getSizeInUSDT().toFixed(2)} USDT` : `${getSizeInBTC().toFixed(4)} ${baseCurrency}`}
                  </span>
                  <span className="text-gray-500">
                    Margin: <span className={getRequiredMargin() > availableMargin ? 'text-red-500' : 'text-[#f0b90b]'}>{getRequiredMargin().toFixed(2)} USDT</span>
                  </span>
                </div>
                {getRequiredMargin() > availableMargin && (
                  <div className="mt-2 text-xs text-red-500 bg-red-500/10 border border-red-500/30 rounded px-2 py-1.5">
                    Insufficient margin. You need {getRequiredMargin().toFixed(2)} USDT but only have {availableMargin.toFixed(2)} USDT available.
                  </div>
                )}
              </>
            )}
          </div>

          <div className="flex gap-2">
            {[25, 50, 75, 100].map((percent) => (
              <button
                key={percent}
                onClick={() => handlePercentage(percent)}
                className="flex-1 px-2 py-1 text-xs bg-gray-900 border border-gray-800 rounded hover:bg-gray-800 hover:border-[#f0b90b]/50 transition-colors text-gray-400 hover:text-white"
              >
                {percent}%
              </button>
            ))}
          </div>

          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="tpsl"
              checked={tpslEnabled}
              onChange={(e) => setTpslEnabled(e.target.checked)}
              className="w-4 h-4 accent-[#f0b90b] cursor-pointer"
            />
            <label htmlFor="tpsl" className="text-xs text-gray-400 cursor-pointer">
              TP/SL
            </label>
          </div>

          {tpslEnabled && (
            <div className="space-y-3">
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs text-gray-500">Take Profit</label>
                  <div className="flex gap-1">
                    <button
                      onClick={() => setTpMode('price')}
                      className={`px-2 py-0.5 text-xs rounded transition-colors ${
                        tpMode === 'price'
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                          : 'bg-gray-800 text-gray-500 hover:text-gray-300'
                      }`}
                    >
                      Price
                    </button>
                    <button
                      onClick={() => setTpMode('pnl')}
                      className={`px-2 py-0.5 text-xs rounded transition-colors ${
                        tpMode === 'pnl'
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                          : 'bg-gray-800 text-gray-500 hover:text-gray-300'
                      }`}
                    >
                      PnL
                    </button>
                    <button
                      onClick={() => setTpMode('percent')}
                      className={`px-2 py-0.5 text-xs rounded transition-colors ${
                        tpMode === 'percent'
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                          : 'bg-gray-800 text-gray-500 hover:text-gray-300'
                      }`}
                    >
                      %
                    </button>
                  </div>
                </div>
                <div className="relative">
                  <input
                    type="text"
                    value={takeProfit}
                    onChange={(e) => setTakeProfit(e.target.value)}
                    placeholder={tpMode === 'price' ? 'Price' : tpMode === 'pnl' ? 'PnL (USDT)' : 'Percent (%)'}
                    className="w-full bg-gray-900 border border-gray-800 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-[#f0b90b]/50"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-500">
                    {tpMode === 'price' ? 'USDT' : tpMode === 'pnl' ? 'USDT' : '%'}
                  </span>
                </div>
                {takeProfit && tpDisplayValues.price && (
                  <div className="mt-1 flex gap-2 text-xs">
                    {tpMode !== 'price' && (
                      <span className="text-gray-400">
                        Price: <span className="text-green-400">{tpDisplayValues.price} USDT</span>
                      </span>
                    )}
                    {tpMode !== 'pnl' && (
                      <span className="text-gray-400">
                        PnL: <span className="text-green-400">+{tpDisplayValues.pnl} USDT</span>
                      </span>
                    )}
                    {tpMode !== 'percent' && (
                      <span className="text-gray-400">
                        <span className="text-green-400">+{tpDisplayValues.percent}%</span>
                      </span>
                    )}
                  </div>
                )}
              </div>
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs text-gray-500">Stop Loss</label>
                  <div className="flex gap-1">
                    <button
                      onClick={() => setSlMode('price')}
                      className={`px-2 py-0.5 text-xs rounded transition-colors ${
                        slMode === 'price'
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                          : 'bg-gray-800 text-gray-500 hover:text-gray-300'
                      }`}
                    >
                      Price
                    </button>
                    <button
                      onClick={() => setSlMode('pnl')}
                      className={`px-2 py-0.5 text-xs rounded transition-colors ${
                        slMode === 'pnl'
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                          : 'bg-gray-800 text-gray-500 hover:text-gray-300'
                      }`}
                    >
                      PnL
                    </button>
                    <button
                      onClick={() => setSlMode('percent')}
                      className={`px-2 py-0.5 text-xs rounded transition-colors ${
                        slMode === 'percent'
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                          : 'bg-gray-800 text-gray-500 hover:text-gray-300'
                      }`}
                    >
                      %
                    </button>
                  </div>
                </div>
                <div className="relative">
                  <input
                    type="text"
                    value={stopLoss}
                    onChange={(e) => setStopLoss(e.target.value)}
                    placeholder={slMode === 'price' ? 'Price' : slMode === 'pnl' ? 'PnL (USDT)' : 'Percent (%)'}
                    className="w-full bg-gray-900 border border-gray-800 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-[#f0b90b]/50"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-500">
                    {slMode === 'price' ? 'USDT' : slMode === 'pnl' ? 'USDT' : '%'}
                  </span>
                </div>
                {stopLoss && slDisplayValues.price && (
                  <div className="mt-1 flex gap-2 text-xs">
                    {slMode !== 'price' && (
                      <span className="text-gray-400">
                        Price: <span className="text-red-400">{slDisplayValues.price} USDT</span>
                      </span>
                    )}
                    {slMode !== 'pnl' && (
                      <span className="text-gray-400">
                        PnL: <span className="text-red-400">{slDisplayValues.pnl} USDT</span>
                      </span>
                    )}
                    {slMode !== 'percent' && (
                      <span className="text-gray-400">
                        <span className="text-red-400">{slDisplayValues.percent}%</span>
                      </span>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}

          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="reduce"
              checked={reduceOnly}
              onChange={(e) => setReduceOnly(e.target.checked)}
              className="w-4 h-4 accent-[#f0b90b] cursor-pointer"
            />
            <label htmlFor="reduce" className="text-xs text-gray-400 cursor-pointer">
              Reduce-Only
            </label>
            <Info className="w-3 h-3 text-gray-500" />
          </div>

          <div className="pt-2 space-y-2">
            {isAuthenticated ? (
              <>
                <button
                  onClick={() => handlePlaceOrder('long')}
                  disabled={isPlacingOrder}
                  className="w-full bg-green-500 hover:bg-green-600 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-semibold py-3 rounded transition-colors"
                >
                  {isPlacingOrder ? 'Placing...' : 'Buy/Long'}
                </button>
                <button
                  onClick={() => handlePlaceOrder('short')}
                  disabled={isPlacingOrder}
                  className="w-full bg-red-500 hover:bg-red-600 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-semibold py-3 rounded transition-colors"
                >
                  {isPlacingOrder ? 'Placing...' : 'Sell/Short'}
                </button>
              </>
            ) : (
              <>
                <button
                  onClick={() => navigateTo('signin')}
                  className="w-full bg-[#f0b90b] hover:bg-[#d9a506] text-black font-semibold py-3 rounded transition-colors"
                >
                  Sign In to Trade
                </button>
                <button
                  onClick={() => navigateTo('signup')}
                  className="w-full bg-gray-700 hover:bg-gray-600 text-white font-semibold py-3 rounded transition-colors"
                >
                  Create Account
                </button>
              </>
            )}
          </div>

          <div className="pt-2 space-y-1 text-xs text-gray-500">
            <div className="flex justify-between">
              <span>Liq Price -- USDT</span>
            </div>
            <div className="flex justify-between">
              <span>Cost</span>
              <span className="text-gray-400">0.00 USDT</span>
            </div>
            <div className="flex justify-between">
              <span>Max</span>
              <span className="text-gray-400">0.000 BTC</span>
            </div>
          </div>
        </div>
      </div>

      <div className="px-4 py-3 border-t border-gray-800">
        <div className="flex justify-between items-center mb-2">
          <h4 className="text-sm font-semibold text-white">Trades</h4>
          <button className="text-xs text-gray-400 hover:text-gray-300">
            Top Movers
          </button>
        </div>

        <div className="space-y-1">
          <div className="grid grid-cols-3 gap-2 text-xs text-gray-500">
            <div>Price (USDT)</div>
            <div className="text-right">Amount (BTC)</div>
            <div className="text-right">Time</div>
          </div>

          {Array.from({ length: 8 }).map((_, idx) => {
            const isGreen = Math.random() > 0.5;
            const currentPrice = priceData ? parseFloat(priceData.price).toFixed(1) : '---';
            return (
              <div key={idx} className="grid grid-cols-3 gap-2 text-xs">
                <div className={isGreen ? 'text-green-500' : 'text-red-500'}>
                  {currentPrice}
                </div>
                <div className="text-right text-gray-400">
                  {(Math.random() * 0.1).toFixed(3)}
                </div>
                <div className="text-right text-gray-500">
                  {new Date().toLocaleTimeString('en-US', { hour12: false })}
                </div>
              </div>
            );
          })}
        </div>
      </div>
      <ToastContainer toasts={toasts} removeToast={removeToast} />
      <TransferModal
        isOpen={showTransferModal}
        onClose={() => setShowTransferModal(false)}
        onSuccess={() => {
          fetchFuturesBalance();
          showSuccess('Transfer completed successfully');
        }}
      />
    </div>
  );
}

export default TradingPanel;

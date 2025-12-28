import { useState, useEffect } from 'react';
import { Info, ChevronDown, ArrowRightLeft, Calculator } from 'lucide-react';
import { usePrice } from '../../hooks/usePrices';
import { useAuth } from '../../context/AuthContext';
import { useNavigation } from '../../App';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';
import { ToastContainer } from '../Toast';
import TransferModal from '../TransferModal';
import TradingCalculator from './TradingCalculator';
import TradeConfirmationModal from './TradeConfirmationModal';

interface VerticalTradingPanelProps {
  pair: string;
  initialSide?: 'long' | 'short';
}

function VerticalTradingPanel({ pair, initialSide }: VerticalTradingPanelProps) {
  const { isAuthenticated, user } = useAuth();
  const { navigateTo } = useNavigation();
  const { toasts, removeToast, showSuccess, showError } = useToast();
  const [selectedSide, setSelectedSide] = useState<'long' | 'short'>(initialSide || 'long');
  const [size, setSize] = useState('');
  const [leverage, setLeverage] = useState(20);
  const [showLeverageModal, setShowLeverageModal] = useState(false);
  const [isPlacingOrder, setIsPlacingOrder] = useState(false);
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [showCalculator, setShowCalculator] = useState(false);
  const [futuresBalance, setFuturesBalance] = useState(0);
  const [availableMargin, setAvailableMargin] = useState(0);
  const [sizeUnit, setSizeUnit] = useState<string>('BTC');
  const [maxLeverage, setMaxLeverage] = useState(125);
  const [balancePercentage, setBalancePercentage] = useState(0);
  const [showConditional, setShowConditional] = useState(false);
  const [takeProfitPrice, setTakeProfitPrice] = useState('');
  const [stopLossPrice, setStopLossPrice] = useState('');
  const [enableTPSL, setEnableTPSL] = useState(false);
  const [tpInputMode, setTpInputMode] = useState<'price' | 'pnl' | 'percent'>('price');
  const [slInputMode, setSlInputMode] = useState<'price' | 'pnl' | 'percent'>('price');
  const [tpROI, setTpROI] = useState<number | string>(0);
  const [slROI, setSlROI] = useState<number | string>(0);
  const [tpPnL, setTpPnL] = useState('');
  const [slPnL, setSlPnL] = useState('');
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [pendingOrder, setPendingOrder] = useState<{
    side: 'Long' | 'Short';
    orderCost: number;
    orderValue: number;
    estimatedLiqPrice: string;
    initialMarginRate: string;
    maintenanceMarginRate: string;
  } | null>(null);

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

  useEffect(() => {
    if (takeProfitPrice && priceData) {
      const entryPrice = parseFloat(priceData.price) || 0;
      const tp = parseFloat(takeProfitPrice) || 0;
      if (entryPrice && tp && tpInputMode === 'price') {
        const roi = ((tp - entryPrice) / entryPrice) * 100 * leverage;
        setTpROI(roi);
        const margin = getSizeInUSDT() / leverage;
        if (margin > 0) {
          setTpPnL(((roi / 100) * margin).toFixed(2));
        }
      } else if (tpInputMode === 'percent' && tpROI) {
        const margin = getSizeInUSDT() / leverage;
        if (margin > 0) {
          setTpPnL(((tpROI / 100) * margin).toFixed(2));
        }
      } else if (tpInputMode === 'pnl' && tpPnL) {
        const margin = getSizeInUSDT() / leverage;
        if (margin > 0) {
          const roi = (parseFloat(tpPnL) / margin) * 100;
          setTpROI(roi);
        }
      }
    }
  }, [size, leverage, priceData, takeProfitPrice, tpInputMode, tpROI, tpPnL]);

  useEffect(() => {
    if (stopLossPrice && priceData) {
      const entryPrice = parseFloat(priceData.price) || 0;
      const sl = parseFloat(stopLossPrice) || 0;
      if (entryPrice && sl && slInputMode === 'price') {
        const roi = ((sl - entryPrice) / entryPrice) * 100 * leverage;
        setSlROI(roi);
        const margin = getSizeInUSDT() / leverage;
        if (margin > 0) {
          setSlPnL((Math.abs(roi) / 100 * margin).toFixed(2));
        }
      } else if (slInputMode === 'percent' && slROI) {
        const margin = getSizeInUSDT() / leverage;
        if (margin > 0) {
          setSlPnL((Math.abs(slROI) / 100 * margin).toFixed(2));
        }
      } else if (slInputMode === 'pnl' && slPnL) {
        const margin = getSizeInUSDT() / leverage;
        if (margin > 0) {
          const roi = (parseFloat(slPnL) / margin) * 100;
          setSlROI(-Math.abs(roi));
        }
      }
    }
  }, [size, leverage, priceData, stopLossPrice, slInputMode, slROI, slPnL]);

  const fetchFuturesBalance = async () => {
    if (!user) return;
    try {
      const { data, error } = await supabase.rpc('get_wallet_balances', {
        p_user_id: user.id
      });
      console.log('Balance Data:', data);
      if (!error && data) {
        // Updated to match new data structure from get_wallet_balances
        const available = parseFloat(data.futures?.available_balance || 0);
        const lockedBonus = parseFloat(data.locked_bonus?.balance || 0);
        const totalAvailable = parseFloat(data.total_trading_available || 0);
        const totalEquity = parseFloat(data.futures?.total_equity || 0);

        console.log('Setting balances - Available:', available, 'Locked Bonus:', lockedBonus, 'Total:', totalAvailable);
        setFuturesBalance(totalEquity);
        setAvailableMargin(totalAvailable); // Use total_trading_available which includes locked bonus
      } else {
        console.error('Balance fetch error:', error);
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

      const pairMax = pairConfig.data?.max_leverage || 125;
      const userMax = userLimit.data?.max_allowed_leverage || 125;
      const effectiveMax = Math.min(pairMax, userMax);
      setMaxLeverage(effectiveMax);

      if (leverage > effectiveMax) {
        setLeverage(effectiveMax);
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
    setBalancePercentage(percent);
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

  const calculateOrderDetails = (orderSide: 'long' | 'short') => {
    if (!priceData) return null;
    const currentPrice = parseFloat(priceData.price) || 0;
    const quantity = getSizeInBaseCurrency();
    const orderValue = quantity * currentPrice;
    const orderCost = orderValue / leverage;

    const maintenanceMarginRate = leverage >= 100 ? 0.5 : leverage >= 50 ? 1.0 : leverage >= 20 ? 2.5 : 5.0;
    const initialMarginRate = (1 / leverage) * 100;

    let estimatedLiqPrice;
    if (orderSide === 'long') {
      const maintenanceMargin = orderValue * (maintenanceMarginRate / 100);
      estimatedLiqPrice = currentPrice - ((orderCost - maintenanceMargin) / quantity);
    } else {
      const maintenanceMargin = orderValue * (maintenanceMarginRate / 100);
      estimatedLiqPrice = currentPrice + ((orderCost - maintenanceMargin) / quantity);
    }

    return {
      orderCost,
      orderValue,
      estimatedLiqPrice: estimatedLiqPrice.toFixed(2),
      initialMarginRate: `0.00% >> ${initialMarginRate.toFixed(2)}%`,
      maintenanceMarginRate: `0.00% >> ${maintenanceMarginRate.toFixed(2)}%`
    };
  };

  const placeOrder = async (orderSide: 'long' | 'short') => {
    if (!isAuthenticated) {
      navigateTo?.('signin');
      return;
    }

    if (!size || parseFloat(size) <= 0) {
      showError('Please enter a valid size');
      return;
    }

    const requiredMargin = getRequiredMargin();
    if (requiredMargin > availableMargin) {
      showError('Insufficient margin available');
      return;
    }

    const hideConfirmation = localStorage.getItem('hideTradeConfirmation') === 'true';

    if (!hideConfirmation) {
      const orderDetails = calculateOrderDetails(orderSide);
      if (orderDetails) {
        setPendingOrder({
          side: orderSide === 'long' ? 'Long' : 'Short',
          ...orderDetails
        });
        setShowConfirmation(true);
        return;
      }
    }

    await executeOrder(orderSide);
  };

  const executeOrder = async (orderSide: 'long' | 'short') => {
    setIsPlacingOrder(true);
    setShowConfirmation(false);

    try {
      const quantity = getSizeInBaseCurrency();

      const tpValue = enableTPSL && takeProfitPrice ? parseFloat(takeProfitPrice) : null;
      const slValue = enableTPSL && stopLossPrice ? parseFloat(stopLossPrice) : null;

      const { data, error } = await supabase.rpc('place_futures_order', {
        p_user_id: user!.id,
        p_pair: pair,
        p_side: orderSide,
        p_order_type: 'market',
        p_quantity: quantity,
        p_leverage: leverage,
        p_margin_mode: 'cross',
        p_price: null,
        p_trigger_price: null,
        p_stop_loss: slValue,
        p_take_profit: tpValue,
        p_reduce_only: false
      });

      if (error) throw error;

      showSuccess(`${orderSide === 'long' ? 'Long' : 'Short'} order placed successfully!`);
      setSize('');
      setTakeProfitPrice('');
      setStopLossPrice('');
      setPendingOrder(null);
      await fetchFuturesBalance();
    } catch (err) {
      console.error('Order error:', err);
      showError(err instanceof Error ? err.message : 'Failed to place order');
    } finally {
      setIsPlacingOrder(false);
    }
  };

  if (!isAuthenticated) {
    return (
      <div className="h-full flex items-center justify-center p-6">
        <div className="text-center">
          <p className="text-gray-400 mb-4">Sign in to start trading</p>
          <button
            onClick={() => navigateTo?.('signin')}
            className="px-6 py-2 bg-[#f0b90b] text-black rounded font-semibold hover:bg-[#f0b90b]/90 transition-colors"
          >
            Sign In
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col bg-[#0b0e11]">
      <ToastContainer toasts={toasts} removeToast={removeToast} />

      <div className="px-4 py-3 border-b border-[#2b2e35]">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <h3 className="text-white font-semibold text-sm">Trade</h3>
          </div>
          <div className="flex items-center gap-2.5">
            <button
              onClick={() => setShowTransferModal(true)}
              className="flex items-center gap-1 px-2 py-1 bg-[#f0b90b]/10 hover:bg-[#f0b90b]/20 text-[#f0b90b] text-[10px] rounded transition-colors"
            >
              <ArrowRightLeft className="w-3 h-3" />
              Transfer
            </button>
          </div>
        </div>
        <div className="flex items-center justify-between text-[10px]">
          <span className="text-gray-500">Avbl Margin</span>
          <span className="text-[#f0b90b] font-medium">{availableMargin.toFixed(2)} USDT</span>
        </div>
        {availableMargin === 0 && (
          <div className="mt-2 text-[10px] text-yellow-500 bg-yellow-500/10 border border-yellow-500/30 rounded px-2 py-1.5">
            No funds in Futures Wallet. Click Transfer to add funds.
          </div>
        )}
      </div>

      <div className="px-4 py-3">
        <div className="grid grid-cols-2 gap-2 mb-3">
          <select className="bg-[#1a1d23] text-white text-xs px-3 py-2 rounded-md border-none focus:outline-none focus:ring-1 focus:ring-[#f0b90b] cursor-pointer appearance-none">
            <option>Cross</option>
            <option>Isolated</option>
          </select>
          <button
            onClick={() => setShowLeverageModal(!showLeverageModal)}
            className="bg-[#1a1d23] text-[#f0b90b] text-xs px-3 py-2 rounded-md border-none flex items-center justify-between hover:bg-[#23262b] transition-colors"
          >
            <span className="font-medium">{leverage}.00x</span>
            <ChevronDown className="w-3 h-3" />
          </button>
        </div>

        {showLeverageModal && (
          <div className="bg-[#1a1d23] rounded-md p-3 mb-3">
            <input
              type="range"
              min="1"
              max={maxLeverage}
              value={leverage}
              onChange={(e) => setLeverage(parseInt(e.target.value))}
              className="w-full mb-2 accent-[#f0b90b]"
            />
            <div className="flex justify-between text-[10px] text-gray-500">
              <span>1x</span>
              <span>{maxLeverage}x</span>
            </div>
          </div>
        )}

        <div className="flex items-center justify-between mb-4">
          <span className="text-gray-400 text-xs">Order Type</span>
          <span className="text-[#f0b90b] text-xs font-medium">Market</span>
        </div>

        <div className="space-y-3">
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-gray-400 text-[10px]">Market Price</label>
              <span className="text-gray-500 text-[10px]">USDT</span>
            </div>
            <input
              type="text"
              value={priceData ? parseFloat(priceData.price).toFixed(2) : '---'}
              readOnly
              className="w-full bg-[#1a1d23] text-gray-400 text-sm px-3 py-2.5 rounded-md border-none cursor-not-allowed"
            />
          </div>

          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-gray-400 text-[10px]">Quantity</label>
              <button
                onClick={toggleSizeUnit}
                className="flex items-center gap-1 text-white text-xs hover:text-[#f0b90b]"
              >
                <span>{sizeUnit}</span>
                <ChevronDown className="w-3 h-3" />
              </button>
            </div>
            <input
              type="text"
              value={size}
              onChange={(e) => setSize(e.target.value)}
              placeholder="1.412"
              className="w-full bg-[#1a1d23] text-white text-sm px-3 py-2.5 rounded-md border-none focus:outline-none focus:ring-1 focus:ring-[#f0b90b]"
            />
          </div>

          <div className="relative py-2">
            <input
              type="range"
              min="0"
              max="100"
              value={balancePercentage}
              onChange={(e) => handlePercentage(parseInt(e.target.value))}
              className="w-full h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer slider accent-[#f0b90b]"
              style={{
                background: `linear-gradient(to right, #f0b90b 0%, #f0b90b ${balancePercentage}%, #1a1d23 ${balancePercentage}%, #1a1d23 100%)`
              }}
            />
            <div className="flex justify-end mt-1.5">
              <span className="text-[10px] text-gray-500">{balancePercentage}%</span>
            </div>
          </div>

          <div className="space-y-1">
            <div className="flex items-center justify-between">
              <span className="text-gray-500 text-[10px]">Value</span>
              <span className="text-[11px] font-medium">
                <span className="text-[#0ecb81]">{getSizeInUSDT().toFixed(2)}</span>
                <span className="text-gray-600"> / </span>
                <span className="text-[#f6465d]">{getSizeInUSDT().toFixed(2)}</span>
                <span className="text-gray-500 font-normal"> USDT</span>
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-500 text-[10px]">Cost</span>
              <span className="text-[11px] font-medium">
                <span className="text-[#0ecb81]">{(getSizeInUSDT() / leverage).toFixed(2)}</span>
                <span className="text-gray-600"> / </span>
                <span className="text-[#f6465d]">{(getSizeInUSDT() / leverage).toFixed(2)}</span>
                <span className="text-gray-500 font-normal"> USDT</span>
              </span>
            </div>
          </div>

          <div className="space-y-2 pt-3">
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="enable-tpsl"
                checked={enableTPSL}
                onChange={(e) => setEnableTPSL(e.target.checked)}
                className="w-3.5 h-3.5 accent-[#f0b90b] cursor-pointer"
              />
              <label htmlFor="enable-tpsl" className="text-xs text-white cursor-pointer">TP/SL</label>
            </div>

            {enableTPSL && (
              <div className="space-y-3">
                {/* Take Profit */}
                <div>
                  <label className="text-gray-400 text-[10px] mb-2 block">Take Profit</label>

                  {/* TP Tabs */}
                  <div className="flex gap-1 mb-2">
                    <button
                      onClick={() => setTpInputMode('price')}
                      className={`flex-1 text-[10px] py-1 px-2 rounded transition-colors ${
                        tpInputMode === 'price'
                          ? 'bg-[#0ecb81] text-white'
                          : 'bg-[#1a1d23] text-gray-400 hover:bg-[#2b2e35]'
                      }`}
                    >
                      $ Price
                    </button>
                    <button
                      onClick={() => setTpInputMode('pnl')}
                      className={`flex-1 text-[10px] py-1 px-2 rounded transition-colors ${
                        tpInputMode === 'pnl'
                          ? 'bg-[#0ecb81] text-white'
                          : 'bg-[#1a1d23] text-gray-400 hover:bg-[#2b2e35]'
                      }`}
                    >
                      PnL
                    </button>
                    <button
                      onClick={() => setTpInputMode('percent')}
                      className={`flex-1 text-[10px] py-1 px-2 rounded transition-colors ${
                        tpInputMode === 'percent'
                          ? 'bg-[#0ecb81] text-white'
                          : 'bg-[#1a1d23] text-gray-400 hover:bg-[#2b2e35]'
                      }`}
                    >
                      % %
                    </button>
                  </div>

                  {/* TP Input based on mode */}
                  {tpInputMode === 'price' && (
                    <input
                      type="number"
                      value={takeProfitPrice}
                      onChange={(e) => {
                        setTakeProfitPrice(e.target.value);
                        const entryPrice = parseFloat(price) || 0;
                        const tp = parseFloat(e.target.value) || 0;
                        if (entryPrice && tp) {
                          const roi = ((tp - entryPrice) / entryPrice) * 100 * leverage;
                          setTpROI(roi);
                        }
                      }}
                      placeholder="Enter TP Price"
                      step="0.01"
                      className="w-full bg-[#1a1d23] text-white text-xs px-3 py-2 rounded border border-[#2b2e35] focus:outline-none focus:border-[#0ecb81]"
                    />
                  )}

                  {tpInputMode === 'pnl' && (
                    <input
                      type="number"
                      value={tpPnL}
                      onChange={(e) => {
                        setTpPnL(e.target.value);
                        const pnl = parseFloat(e.target.value) || 0;
                        const margin = getSizeInUSDT() / leverage;
                        if (margin) {
                          const roi = (pnl / margin) * 100;
                          setTpROI(roi);
                          const entryPrice = parseFloat(price) || 0;
                          const priceChange = (roi / leverage) / 100;
                          setTakeProfitPrice((entryPrice * (1 + priceChange)).toFixed(2));
                        }
                      }}
                      placeholder="Target PnL (USDT)"
                      step="0.01"
                      className="w-full bg-[#1a1d23] text-white text-xs px-3 py-2 rounded border border-[#2b2e35] focus:outline-none focus:border-[#0ecb81]"
                    />
                  )}

                  {tpInputMode === 'percent' && (
                    <>
                      <input
                        type="text"
                        value={tpROI}
                        onFocus={(e) => {
                          if (tpROI === 0 || tpROI === '0') {
                            setTpROI('');
                          }
                        }}
                        onChange={(e) => {
                          const value = e.target.value;
                          if (value === '' || /^-?\d*\.?\d*$/.test(value)) {
                            setTpROI(value);
                            const roi = parseFloat(value) || 0;
                            const entryPrice = parseFloat(price) || 0;
                            const priceChange = (roi / leverage) / 100;
                            const tp = entryPrice * (1 + priceChange);
                            setTakeProfitPrice(tp.toFixed(2));
                            const margin = getSizeInUSDT() / leverage;
                            setTpPnL(((roi / 100) * margin).toFixed(2));
                          }
                        }}
                        onBlur={() => {
                          if (tpROI === '' || tpROI === '-') {
                            setTpROI(0);
                          }
                        }}
                        placeholder="Target ROI (%)"
                        className="w-full bg-[#1a1d23] text-white text-xs px-3 py-2 rounded border border-[#2b2e35] focus:outline-none focus:border-[#0ecb81] mb-2"
                      />
                      <div className="text-[10px] text-gray-500 mb-1">Quick Select ROI: 0% ~ 100%</div>
                      <input
                        type="range"
                        min="0"
                        max="100"
                        step="1"
                        value={tpROI}
                        onChange={(e) => {
                          const roi = parseFloat(e.target.value);
                          setTpROI(roi);
                          const entryPrice = parseFloat(price) || 0;
                          const priceChange = (roi / leverage) / 100;
                          const tp = entryPrice * (1 + priceChange);
                          setTakeProfitPrice(tp.toFixed(2));
                          const margin = getSizeInUSDT() / leverage;
                          setTpPnL(((roi / 100) * margin).toFixed(2));
                        }}
                        className="w-full h-1 bg-[#2b2e35] rounded-lg appearance-none cursor-pointer accent-[#0ecb81]"
                      />
                      <div className="flex justify-between text-[9px] text-gray-600 mt-1">
                        <span>0%</span>
                        <span>50%</span>
                        <span>100%</span>
                      </div>
                    </>
                  )}

                  {/* TP Info Display */}
                  {takeProfitPrice && (
                    <div className="mt-2 p-2 bg-[#0c0d0f] rounded space-y-1 text-[10px]">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Trigger Price:</span>
                        <span className="text-white">${takeProfitPrice}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Est. PnL:</span>
                        <span className="text-[#0ecb81]">+${tpPnL || ((parseFloat(String(tpROI)) / 100) * (getSizeInUSDT() / leverage)).toFixed(2)}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">ROI:</span>
                        <span className="text-[#0ecb81]">+{(typeof tpROI === 'number' ? tpROI.toFixed(2) : parseFloat(tpROI || '0').toFixed(2))}%</span>
                      </div>
                    </div>
                  )}
                </div>

                {/* Stop Loss */}
                <div>
                  <label className="text-gray-400 text-[10px] mb-2 block">Stop Loss</label>

                  {/* SL Tabs */}
                  <div className="flex gap-1 mb-2">
                    <button
                      onClick={() => setSlInputMode('price')}
                      className={`flex-1 text-[10px] py-1 px-2 rounded transition-colors ${
                        slInputMode === 'price'
                          ? 'bg-[#f6465d] text-white'
                          : 'bg-[#1a1d23] text-gray-400 hover:bg-[#2b2e35]'
                      }`}
                    >
                      $ Price
                    </button>
                    <button
                      onClick={() => setSlInputMode('pnl')}
                      className={`flex-1 text-[10px] py-1 px-2 rounded transition-colors ${
                        slInputMode === 'pnl'
                          ? 'bg-[#f6465d] text-white'
                          : 'bg-[#1a1d23] text-gray-400 hover:bg-[#2b2e35]'
                      }`}
                    >
                      PnL
                    </button>
                    <button
                      onClick={() => setSlInputMode('percent')}
                      className={`flex-1 text-[10px] py-1 px-2 rounded transition-colors ${
                        slInputMode === 'percent'
                          ? 'bg-[#f6465d] text-white'
                          : 'bg-[#1a1d23] text-gray-400 hover:bg-[#2b2e35]'
                      }`}
                    >
                      % %
                    </button>
                  </div>

                  {/* SL Input based on mode */}
                  {slInputMode === 'price' && (
                    <input
                      type="number"
                      value={stopLossPrice}
                      onChange={(e) => {
                        setStopLossPrice(e.target.value);
                        const entryPrice = parseFloat(price) || 0;
                        const sl = parseFloat(e.target.value) || 0;
                        if (entryPrice && sl) {
                          const roi = ((sl - entryPrice) / entryPrice) * 100 * leverage;
                          setSlROI(roi);
                        }
                      }}
                      placeholder="Enter SL Price"
                      step="0.01"
                      className="w-full bg-[#1a1d23] text-white text-xs px-3 py-2 rounded border border-[#2b2e35] focus:outline-none focus:border-[#f6465d]"
                    />
                  )}

                  {slInputMode === 'pnl' && (
                    <input
                      type="number"
                      value={slPnL}
                      onChange={(e) => {
                        setSlPnL(e.target.value);
                        const pnl = parseFloat(e.target.value) || 0;
                        const margin = getSizeInUSDT() / leverage;
                        if (margin) {
                          const roi = (pnl / margin) * 100;
                          setSlROI(roi);
                          const entryPrice = parseFloat(price) || 0;
                          const priceChange = (roi / leverage) / 100;
                          setStopLossPrice((entryPrice * (1 + priceChange)).toFixed(2));
                        }
                      }}
                      placeholder="Max Loss (USDT)"
                      step="0.01"
                      className="w-full bg-[#1a1d23] text-white text-xs px-3 py-2 rounded border border-[#2b2e35] focus:outline-none focus:border-[#f6465d]"
                    />
                  )}

                  {slInputMode === 'percent' && (
                    <>
                      <input
                        type="text"
                        value={Math.abs(parseFloat(String(slROI)))}
                        onFocus={(e) => {
                          const absValue = Math.abs(parseFloat(String(slROI)));
                          if (absValue === 0) {
                            setSlROI('');
                          }
                        }}
                        onChange={(e) => {
                          const value = e.target.value;
                          if (value === '' || /^\d*\.?\d*$/.test(value)) {
                            if (value === '') {
                              setSlROI('');
                            } else {
                              const absValue = parseFloat(value) || 0;
                              const roi = -Math.abs(absValue);
                              setSlROI(roi);
                              const entryPrice = parseFloat(price) || 0;
                              const priceChange = (roi / leverage) / 100;
                              const sl = entryPrice * (1 + priceChange);
                              setStopLossPrice(sl.toFixed(2));
                              const margin = getSizeInUSDT() / leverage;
                              setSlPnL((Math.abs(roi) / 100 * margin).toFixed(2));
                            }
                          }
                        }}
                        onBlur={() => {
                          if (slROI === '' || slROI === '-') {
                            setSlROI(0);
                          }
                        }}
                        placeholder="Max Loss ROI (%)"
                        className="w-full bg-[#1a1d23] text-white text-xs px-3 py-2 rounded border border-[#2b2e35] focus:outline-none focus:border-[#f6465d] mb-2"
                      />
                      <div className="text-[10px] text-gray-500 mb-1">Quick Select ROI: 0% ~ 100%</div>
                      <input
                        type="range"
                        min="0"
                        max="100"
                        step="1"
                        value={Math.abs(parseFloat(String(slROI)))}
                        onChange={(e) => {
                          const roi = -parseFloat(e.target.value);
                          setSlROI(roi);
                          const entryPrice = parseFloat(price) || 0;
                          const priceChange = (roi / leverage) / 100;
                          const sl = entryPrice * (1 + priceChange);
                          setStopLossPrice(sl.toFixed(2));
                          const margin = getSizeInUSDT() / leverage;
                          setSlPnL((Math.abs(roi) / 100 * margin).toFixed(2));
                        }}
                        className="w-full h-1 bg-[#2b2e35] rounded-lg appearance-none cursor-pointer accent-[#f6465d]"
                      />
                      <div className="flex justify-between text-[9px] text-gray-600 mt-1">
                        <span>0%</span>
                        <span>50%</span>
                        <span>100%</span>
                      </div>
                    </>
                  )}

                  {/* SL Info Display */}
                  {stopLossPrice && (
                    <div className="mt-2 p-2 bg-[#0c0d0f] rounded space-y-1 text-[10px]">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Trigger Price:</span>
                        <span className="text-white">${stopLossPrice}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Est. PnL:</span>
                        <span className="text-[#f6465d]">-${slPnL || (Math.abs(parseFloat(String(slROI))) / 100 * (getSizeInUSDT() / leverage)).toFixed(2)}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">ROI:</span>
                        <span className="text-[#f6465d]">{(typeof slROI === 'number' ? slROI.toFixed(2) : parseFloat(slROI || '0').toFixed(2))}%</span>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {initialSide && (
            <div className="flex rounded-md overflow-hidden mb-3 mt-2">
              <button
                onClick={() => setSelectedSide('long')}
                className={`flex-1 py-2 text-sm font-semibold transition-all ${
                  selectedSide === 'long'
                    ? 'bg-[#0ecb81] text-white'
                    : 'bg-[#1e2329] text-gray-400 hover:text-white'
                }`}
              >
                Buy/Long
              </button>
              <button
                onClick={() => setSelectedSide('short')}
                className={`flex-1 py-2 text-sm font-semibold transition-all ${
                  selectedSide === 'short'
                    ? 'bg-[#f6465d] text-white'
                    : 'bg-[#1e2329] text-gray-400 hover:text-white'
                }`}
              >
                Sell/Short
              </button>
            </div>
          )}

          <div className={`pt-4 ${initialSide ? 'pt-2' : 'pt-4'}`}>
            {initialSide ? (
              <button
                onClick={() => placeOrder(selectedSide)}
                disabled={isPlacingOrder}
                className={`w-full py-3 px-4 text-white rounded-md transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm font-semibold ${
                  selectedSide === 'long'
                    ? 'bg-[#0ecb81] hover:bg-[#0bb870]'
                    : 'bg-[#f6465d] hover:bg-[#e63950]'
                }`}
              >
                {selectedSide === 'long' ? 'Buy/Long' : 'Sell/Short'}
              </button>
            ) : (
              <div className="grid grid-cols-2 gap-3">
                <button
                  onClick={() => placeOrder('long')}
                  disabled={isPlacingOrder}
                  className="py-3 px-4 bg-[#0ecb81] hover:bg-[#0bb870] text-white rounded-md transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm font-semibold"
                >
                  Long
                </button>
                <button
                  onClick={() => placeOrder('short')}
                  disabled={isPlacingOrder}
                  className="py-3 px-4 bg-[#f6465d] hover:bg-[#e63950] text-white rounded-md transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm font-semibold"
                >
                  Short
                </button>
              </div>
            )}
          </div>

          <button
            onClick={() => setShowCalculator(true)}
            className="w-full flex items-center gap-2 text-gray-500 hover:text-gray-400 text-xs py-2.5 transition-colors"
          >
            <Calculator className="w-3.5 h-3.5" />
            <span>Calculator</span>
          </button>
        </div>
      </div>

      <TransferModal
        isOpen={showTransferModal}
        onClose={() => setShowTransferModal(false)}
        onSuccess={() => {
          fetchFuturesBalance();
          showSuccess('Transfer completed successfully');
        }}
      />

      {showCalculator && (
        <TradingCalculator pair={pair} onClose={() => setShowCalculator(false)} />
      )}

      {showConfirmation && pendingOrder && (
        <TradeConfirmationModal
          isOpen={showConfirmation}
          onClose={() => {
            setShowConfirmation(false);
            setPendingOrder(null);
          }}
          onConfirm={() => {
            const orderSide = pendingOrder.side.toLowerCase() as 'long' | 'short';
            executeOrder(orderSide);
          }}
          orderType={orderType}
          side={pendingOrder.side}
          pair={pair}
          price={price}
          lastPrice={priceData?.price || price}
          quantity={size}
          leverage={leverage}
          orderCost={pendingOrder.orderCost}
          orderValue={pendingOrder.orderValue}
          estimatedLiqPrice={pendingOrder.estimatedLiqPrice}
          marginMode="Cross"
          initialMarginRate={pendingOrder.initialMarginRate}
          maintenanceMarginRate={pendingOrder.maintenanceMarginRate}
        />
      )}
    </div>
  );
}

export default VerticalTradingPanel;

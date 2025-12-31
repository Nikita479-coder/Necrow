import { useState, useEffect } from 'react';
import { X, AlertCircle, Wallet, ArrowDown, TrendingUp } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';

interface CopyTradingModalProps {
  isOpen: boolean;
  onClose: () => void;
  traderId: string;
  traderName: string;
  isMock?: boolean;
}

export default function CopyTradingModal({
  isOpen,
  onClose,
  traderId,
  traderName,
  isMock = false
}: CopyTradingModalProps) {
  const { user } = useAuth();
  const { navigateTo } = useNavigation();
  const [allocationPercentage, setAllocationPercentage] = useState('20');
  const [leverage, setLeverage] = useState(1);
  const [stopLoss, setStopLoss] = useState('');
  const [takeProfit, setTakeProfit] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [availableBalance, setAvailableBalance] = useState<number | null>(null);
  const [mainWalletBalance, setMainWalletBalance] = useState<number>(0);
  const [loadingBalance, setLoadingBalance] = useState(true);
  const [transferAmount, setTransferAmount] = useState('');
  const [transferring, setTransferring] = useState(false);
  const [transferError, setTransferError] = useState('');
  const [totalCopyBalance, setTotalCopyBalance] = useState(0);
  const [allocatedBalance, setAllocatedBalance] = useState(0);
  const [traderROI, setTraderROI] = useState<number | null>(null);
  const [loadingTrader, setLoadingTrader] = useState(true);

  useEffect(() => {
    const fetchTraderData = async () => {
      if (!isOpen) return;

      setLoadingTrader(true);
      try {
        const { data: traderData } = await supabase
          .from('traders')
          .select('target_monthly_roi, roi_30d, name')
          .eq('id', traderId)
          .maybeSingle();

        if (traderData) {
          // Use target_monthly_roi if available (for automated traders), otherwise use actual roi_30d
          const monthlyROI = traderData.target_monthly_roi || traderData.roi_30d || 0;
          // Convert monthly ROI to daily average
          const dailyROI = monthlyROI / 30;
          setTraderROI(dailyROI);
        }
      } catch (err) {
        console.error('Error fetching trader data:', err);
      } finally {
        setLoadingTrader(false);
      }
    };

    fetchTraderData();
  }, [traderId, isOpen]);

  useEffect(() => {
    const fetchBalance = async () => {
      if (!user || !isOpen) return;

      setLoadingBalance(true);
      try {
        if (isMock) {
          // Mock trading always has 10,000 USDT demo balance
          setAvailableBalance(10000);
          setMainWalletBalance(0);
        } else {
          // Fetch main wallet balance
          const { data: mainWallet } = await supabase
            .from('wallets')
            .select('balance')
            .eq('user_id', user.id)
            .eq('wallet_type', 'main')
            .eq('currency', 'USDT')
            .maybeSingle();

          const mainBalance = parseFloat(mainWallet?.balance || '0');
          setMainWalletBalance(mainBalance);

          // Fetch real copy wallet balance
          const { data: walletData, error: walletError } = await supabase
            .from('wallets')
            .select('balance')
            .eq('user_id', user.id)
            .eq('wallet_type', 'copy')
            .eq('currency', 'USDT')
            .maybeSingle();

          if (walletError && walletError.code !== 'PGRST116') {
            console.error('Error fetching balance:', walletError);
            setAvailableBalance(0);
            return;
          }

          const totalBalance = parseFloat(walletData?.balance || '0');
          setTotalCopyBalance(totalBalance);

          // Fetch all active copy relationships to calculate allocated amounts
          const { data: activeRelationships, error: relError } = await supabase
            .from('copy_relationships')
            .select('initial_balance')
            .eq('follower_id', user.id)
            .eq('is_active', true)
            .eq('is_mock', false);

          if (relError) {
            console.error('Error fetching active relationships:', relError);
            setAvailableBalance(totalBalance);
            setAllocatedBalance(0);
            return;
          }

          // Calculate total allocated amount
          const totalAllocated = activeRelationships?.reduce(
            (sum, rel) => sum + parseFloat(rel.initial_balance || '0'),
            0
          ) || 0;

          setAllocatedBalance(totalAllocated);

          // Available balance = total balance - already allocated amounts
          const available = Math.max(0, totalBalance - totalAllocated);
          setAvailableBalance(available);
        }
      } catch (err) {
        console.error('Error fetching balance:', err);
        setAvailableBalance(0);
      } finally {
        setLoadingBalance(false);
      }
    };

    fetchBalance();
  }, [user, isOpen, isMock]);

  const handleQuickTransfer = async () => {
    if (!user) return;

    const amount = parseFloat(transferAmount);
    if (isNaN(amount) || amount <= 0) {
      setTransferError('Please enter a valid amount');
      return;
    }

    if (amount > mainWalletBalance) {
      setTransferError('Insufficient balance in main wallet');
      return;
    }

    setTransferring(true);
    setTransferError('');

    try {
      const { data, error: rpcError } = await supabase.rpc('transfer_between_wallets', {
        user_id_param: user.id,
        currency_param: 'USDT',
        amount_param: amount,
        from_wallet_type_param: 'main',
        to_wallet_type_param: 'copy'
      });

      if (rpcError) throw rpcError;

      if (data && !data.success) {
        setTransferError(data.error || 'Transfer failed');
        return;
      }

      // Refresh balances
      setTransferAmount('');
      const fetchBalance = async () => {
        const { data: mainWallet } = await supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', user.id)
          .eq('wallet_type', 'main')
          .eq('currency', 'USDT')
          .maybeSingle();

        const mainBalance = parseFloat(mainWallet?.balance || '0');
        setMainWalletBalance(mainBalance);

        const { data: walletData } = await supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', user.id)
          .eq('wallet_type', 'copy')
          .eq('currency', 'USDT')
          .maybeSingle();

        const totalBalance = parseFloat(walletData?.balance || '0');
        setTotalCopyBalance(totalBalance);

        const { data: activeRelationships } = await supabase
          .from('copy_relationships')
          .select('initial_balance')
          .eq('follower_id', user.id)
          .eq('is_active', true)
          .eq('is_mock', false);

        const totalAllocated = activeRelationships?.reduce(
          (sum, rel) => sum + parseFloat(rel.initial_balance || '0'),
          0
        ) || 0;

        setAllocatedBalance(totalAllocated);

        const available = Math.max(0, totalBalance - totalAllocated);
        setAvailableBalance(available);
      };

      await fetchBalance();
    } catch (err: any) {
      console.error('Transfer error:', err);
      setTransferError(err.message || 'Failed to transfer funds');
    } finally {
      setTransferring(false);
    }
  };

  const handleStartCopy = async () => {
    if (!user) return;

    const calculatedAmount = availableBalance !== null
      ? (availableBalance * parseInt(allocationPercentage || '0')) / 100
      : 0;

    if (!isMock && calculatedAmount < 100) {
      setError('Minimum copy amount is 100 USDT. Please increase your allocation percentage or add funds to your wallet.');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const { data, error: rpcError } = await supabase.rpc('start_copy_trading', {
        p_trader_id: traderId,
        p_allocation_percentage: parseInt(allocationPercentage),
        p_leverage: leverage,
        p_is_mock: isMock,
        p_stop_loss_percent: stopLoss ? parseFloat(stopLoss) : null,
        p_take_profit_percent: takeProfit ? parseFloat(takeProfit) : null
      });

      if (rpcError) throw rpcError;

      const result = data as { success: boolean; error?: string; message?: string; relationship_id?: string };

      if (!result.success) {
        setError(result.error || 'Failed to start copy trading');
        return;
      }

      // Navigate to the active copy trading page with the new relationship ID
      if (result.relationship_id) {
        onClose();
        window.history.pushState({}, '', `?page=activecopying&id=${result.relationship_id}`);
        navigateTo('activecopying');
      } else {
        // Fallback: reload if no relationship ID returned
        onClose();
        window.location.reload();
      }
    } catch (err: any) {
      console.error('Error starting copy trading:', err);
      setError(err.message || 'Failed to start copy trading');
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70">
      <div className="bg-[#1e2329] rounded-lg w-full max-w-md p-6 relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-[#848e9c] hover:text-white"
        >
          <X className="w-5 h-5" />
        </button>

        <h2 className="text-2xl font-bold text-white mb-2">
          {isMock ? 'Start Mock Copy Trading' : 'Start Copy Trading'}
        </h2>
        <p className="text-[#848e9c] text-sm mb-4">
          Copy {traderName}'s trades {isMock && 'with virtual funds'}
        </p>

        {/* Projected Daily Return */}
        {!loadingTrader && traderROI !== null && traderROI > 0 && (() => {
          // Calculate range: ±50% variation from the daily average
          const minDaily = traderROI * 0.5;
          const maxDaily = traderROI * 1.5;

          return (
            <div className="bg-gradient-to-r from-[#0ecb81]/10 to-[#0ecb81]/5 border border-[#0ecb81]/30 rounded-lg p-4 mb-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-5 h-5 text-[#0ecb81]" />
                  <div>
                    <p className="text-white text-sm font-semibold">Projected Daily Return</p>
                    <p className="text-[#848e9c] text-xs">Based on trader's performance range</p>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-[#0ecb81] text-xl font-bold">
                    {minDaily.toFixed(2)}% - {maxDaily.toFixed(2)}%
                  </div>
                  <div className="text-[#848e9c] text-xs">per day</div>
                </div>
              </div>
              {availableBalance !== null && availableBalance > 0 && (() => {
                const investment = (availableBalance * parseInt(allocationPercentage || '0')) / 100 * leverage;

                // Daily returns
                const dailyMin = investment * (minDaily / 100);
                const dailyMax = investment * (maxDaily / 100);

                // Monthly returns with compound interest: investment * (1 + daily_rate)^30 - investment
                const monthlyMinCompound = investment * (Math.pow(1 + (minDaily / 100), 30) - 1);
                const monthlyMaxCompound = investment * (Math.pow(1 + (maxDaily / 100), 30) - 1);

                return (
                  <div className="mt-3 pt-3 border-t border-[#0ecb81]/20">
                    <p className="text-[#848e9c] text-xs mb-1">With your investment:</p>
                    <div className="flex items-center justify-between">
                      <span className="text-white text-sm">Daily estimate</span>
                      <span className="text-[#0ecb81] font-semibold">
                        +${dailyMin.toFixed(2)} - ${dailyMax.toFixed(2)} USDT
                      </span>
                    </div>
                    <div className="flex items-center justify-between mt-1">
                      <span className="text-white text-sm">Monthly estimate</span>
                      <span className="text-[#0ecb81] font-semibold">
                        +${monthlyMinCompound.toFixed(2)} - ${monthlyMaxCompound.toFixed(2)} USDT
                      </span>
                    </div>
                    <p className="text-[#848e9c] text-[10px] mt-1 italic">Monthly estimate includes compound returns</p>
                  </div>
                );
              })()}
            </div>
          );
        })()}

        {/* Available Balance Display */}
        <div className="bg-[#0b0e11] border border-[#2b3139] rounded-lg p-3 mb-4">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              <Wallet className="w-4 h-4 text-[#848e9c]" />
              <span className="text-[#848e9c] text-sm">
                {isMock ? 'Demo Balance' : 'Available for New Traders'}
              </span>
            </div>
            <div className="text-right">
              {loadingBalance ? (
                <span className="text-[#848e9c] text-sm">Loading...</span>
              ) : (
                <>
                  <div className="text-white font-semibold">
                    {availableBalance?.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USDT
                  </div>
                  {isMock && (
                    <div className="text-[#fcd535] text-xs">Virtual Funds</div>
                  )}
                </>
              )}
            </div>
          </div>
          {!isMock && !loadingBalance && (
            <>
              {totalCopyBalance > 0 && (
                <div className="flex items-center justify-between pt-2 border-t border-[#2b3139]">
                  <span className="text-[#848e9c] text-xs">Total Copy Wallet</span>
                  <span className="text-[#848e9c] text-xs font-medium">
                    {totalCopyBalance.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USDT
                  </span>
                </div>
              )}
              {allocatedBalance > 0 && (
                <div className="flex items-center justify-between pt-2 border-t border-[#2b3139]">
                  <span className="text-[#848e9c] text-xs">Already Allocated</span>
                  <span className="text-[#f6465d] text-xs font-medium">
                    -{allocatedBalance.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USDT
                  </span>
                </div>
              )}
              {mainWalletBalance > 0 && (
                <div className="flex items-center justify-between pt-2 border-t border-[#2b3139]">
                  <span className="text-[#848e9c] text-xs">Main Wallet</span>
                  <span className="text-[#0ecb81] text-xs font-medium">
                    {mainWalletBalance.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USDT
                  </span>
                </div>
              )}
            </>
          )}
        </div>

        {!isMock && !loadingBalance && availableBalance === 0 && (totalCopyBalance > 0 || mainWalletBalance > 0) && (
          <div className="bg-[#fcd535]/10 border border-[#fcd535]/30 rounded-lg p-4 mb-4">
            <div className="flex items-start gap-2 mb-3">
              <AlertCircle className="w-4 h-4 text-[#fcd535] flex-shrink-0 mt-0.5" />
              <div className="flex-1">
                <p className="text-[#fcd535] text-sm font-medium">
                  {totalCopyBalance > 0 ? 'All Funds Already Allocated' : 'Transfer Funds Required'}
                </p>
                <p className="text-[#fcd535]/80 text-xs mt-1">
                  {totalCopyBalance > 0
                    ? 'Your copy wallet funds are allocated to other traders. Transfer more from your main wallet to copy additional traders.'
                    : 'Transfer funds from your main wallet to start copy trading'
                  }
                </p>
              </div>
            </div>

            <div className="space-y-3">
              <div className="bg-[#0b0e11] rounded-lg p-3 space-y-2">
                <div className="flex items-center justify-center gap-2 text-sm">
                  <div className="text-center">
                    <div className="text-[#848e9c] text-xs">Main Wallet</div>
                    <div className="text-white font-medium">{mainWalletBalance.toFixed(2)} USDT</div>
                  </div>
                  <ArrowDown className="w-4 h-4 text-[#fcd535]" />
                  <div className="text-center">
                    <div className="text-[#848e9c] text-xs">Copy Wallet</div>
                    <div className="text-white font-medium">{totalCopyBalance.toFixed(2)} USDT</div>
                    {allocatedBalance > 0 && (
                      <div className="text-[#f6465d] text-[10px]">
                        ({allocatedBalance.toFixed(2)} allocated)
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div>
                <div className="relative">
                  <input
                    type="number"
                    value={transferAmount}
                    onChange={(e) => setTransferAmount(e.target.value)}
                    placeholder="Enter amount to transfer"
                    className="w-full bg-[#0b0e11] border border-[#2b3139] rounded-lg px-4 py-2.5 text-white text-sm outline-none focus:border-[#fcd535] transition-colors"
                  />
                  <button
                    onClick={() => setTransferAmount(mainWalletBalance.toString())}
                    className="absolute right-2 top-1/2 -translate-y-1/2 bg-[#2b3139] hover:bg-[#3b4149] text-[#fcd535] text-xs font-medium px-3 py-1 rounded transition-colors"
                  >
                    MAX
                  </button>
                </div>
                {transferError && (
                  <p className="text-[#f6465d] text-xs mt-1">{transferError}</p>
                )}
              </div>

              <button
                onClick={handleQuickTransfer}
                disabled={transferring || !transferAmount || parseFloat(transferAmount) <= 0}
                className="w-full bg-[#fcd535] hover:bg-[#f0b90b] text-black font-medium py-2.5 rounded text-sm transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {transferring ? 'Transferring...' : 'Transfer to Copy Wallet'}
              </button>
            </div>
          </div>
        )}

        {!isMock && !loadingBalance && availableBalance === 0 && mainWalletBalance === 0 && (
          <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-lg p-3 mb-4">
            <div className="flex items-start gap-2 mb-2">
              <AlertCircle className="w-4 h-4 text-[#f6465d] flex-shrink-0 mt-0.5" />
              <div className="flex-1">
                <p className="text-[#f6465d] text-sm font-medium">No Funds Available</p>
                <p className="text-[#f6465d]/80 text-xs mt-1">
                  You need to deposit funds to your account before you can start copy trading. Minimum 100 USDT required.
                </p>
              </div>
            </div>
            <button
              onClick={() => {
                onClose();
                navigateTo('deposit');
              }}
              className="w-full bg-[#f6465d] hover:bg-[#f6465d]/80 text-white font-medium py-2 rounded text-sm transition-colors"
            >
              Deposit Funds
            </button>
          </div>
        )}

        {!isMock && availableBalance !== null && availableBalance > 0 &&
         ((availableBalance * parseInt(allocationPercentage || '0')) / 100) < 100 && (
          <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-lg p-3 mb-4 flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#f6465d] flex-shrink-0 mt-0.5" />
            <span className="text-[#f6465d] text-sm">Minimum copy amount is 100 USDT. Increase your allocation percentage or transfer more funds.</span>
          </div>
        )}

        {error && (
          <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-lg p-3 mb-4 flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#f6465d] flex-shrink-0 mt-0.5" />
            <span className="text-[#f6465d] text-sm">{error}</span>
          </div>
        )}

        <div className="space-y-4">
          <div>
            <label className="block text-white text-sm font-medium mb-2">
              Allocation Percentage
            </label>
            <div className="relative">
              <input
                type="number"
                value={allocationPercentage}
                onChange={(e) => setAllocationPercentage(e.target.value)}
                className="w-full bg-[#0b0e11] border border-[#2b3139] rounded-lg px-4 py-3 text-white pr-12"
                placeholder="Enter percentage"
                min="1"
                max="100"
              />
              <span className="absolute right-4 top-1/2 -translate-y-1/2 text-[#848e9c]">%</span>
            </div>
            {!loadingBalance && availableBalance !== null && (
              <div className="text-xs mt-1 text-right">
                <span className="text-[#0ecb81]">
                  ≈ {((availableBalance * parseInt(allocationPercentage || '0')) / 100).toLocaleString(undefined, {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                  })} USDT
                </span>
              </div>
            )}
          </div>

          <div>
            <label className="block text-white text-sm font-medium mb-2">
              Leverage
            </label>
            <div className="flex gap-2">
              {[1, 5, 10, 20, 50].map((lev) => (
                <button
                  key={lev}
                  onClick={() => setLeverage(lev)}
                  className={`flex-1 py-2 rounded text-sm font-medium transition-colors ${
                    leverage === lev
                      ? 'bg-[#fcd535] text-black'
                      : 'bg-[#0b0e11] text-[#848e9c] hover:text-white border border-[#2b3139]'
                  }`}
                >
                  {lev}x
                </button>
              ))}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-white text-sm font-medium mb-2">
                Stop Loss (%)
              </label>
              <input
                type="number"
                value={stopLoss}
                onChange={(e) => setStopLoss(e.target.value)}
                className="w-full bg-[#0b0e11] border border-[#2b3139] rounded-lg px-4 py-3 text-white"
                placeholder="Optional"
                min="0"
                max="100"
              />
            </div>

            <div>
              <label className="block text-white text-sm font-medium mb-2">
                Take Profit (%)
              </label>
              <input
                type="number"
                value={takeProfit}
                onChange={(e) => setTakeProfit(e.target.value)}
                className="w-full bg-[#0b0e11] border border-[#2b3139] rounded-lg px-4 py-3 text-white"
                placeholder="Optional"
                min="0"
                max="1000"
              />
            </div>
          </div>

          <div className="bg-[#0b0e11] rounded-lg p-4 space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-[#848e9c]">Initial Investment</span>
              <span className="text-white">
                {availableBalance !== null
                  ? ((availableBalance * parseInt(allocationPercentage || '0')) / 100).toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })
                  : '0.00'} USDT
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-[#848e9c]">Leverage</span>
              <span className="text-white">{leverage}x</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-[#848e9c]">Total Buying Power</span>
              <span className="text-[#fcd535] font-medium">
                {availableBalance !== null
                  ? (((availableBalance * parseInt(allocationPercentage || '0')) / 100) * leverage).toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })
                  : '0.00'} USDT
              </span>
            </div>
          </div>

          <button
            onClick={handleStartCopy}
            disabled={loading || !allocationPercentage || parseInt(allocationPercentage) < 1 || parseInt(allocationPercentage) > 100}
            className="w-full bg-[#fcd535] hover:bg-[#f0b90b] text-black font-semibold py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Starting...' : isMock ? 'Start Mock Copy' : 'Start Copy Trading'}
          </button>

        </div>
      </div>
    </div>
  );
}

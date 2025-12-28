import { useState, useEffect } from 'react';
import { X, AlertCircle, Wallet } from 'lucide-react';
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
            return;
          }

          // Calculate total allocated amount
          const totalAllocated = activeRelationships?.reduce(
            (sum, rel) => sum + parseFloat(rel.initial_balance || '0'),
            0
          ) || 0;

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

        {/* Available Balance Display */}
        <div className="bg-[#0b0e11] border border-[#2b3139] rounded-lg p-3 mb-4">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              <Wallet className="w-4 h-4 text-[#848e9c]" />
              <span className="text-[#848e9c] text-sm">
                {isMock ? 'Demo Balance' : 'Copy Wallet Balance'}
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
          {!isMock && !loadingBalance && mainWalletBalance > 0 && (
            <div className="flex items-center justify-between pt-2 border-t border-[#2b3139]">
              <span className="text-[#848e9c] text-xs">Main Wallet</span>
              <span className="text-[#848e9c] text-xs font-medium">
                {mainWalletBalance.toLocaleString(undefined, {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })} USDT
              </span>
            </div>
          )}
        </div>

        {!isMock && !loadingBalance && availableBalance === 0 && mainWalletBalance > 0 && (
          <div className="bg-[#fcd535]/10 border border-[#fcd535]/30 rounded-lg p-3 mb-4">
            <div className="flex items-start gap-2 mb-2">
              <AlertCircle className="w-4 h-4 text-[#fcd535] flex-shrink-0 mt-0.5" />
              <div className="flex-1">
                <p className="text-[#fcd535] text-sm font-medium">Transfer Funds Required</p>
                <p className="text-[#fcd535]/80 text-xs mt-1">
                  You have {mainWalletBalance.toFixed(2)} USDT in your main wallet. Transfer funds to your copy wallet to start copy trading.
                </p>
              </div>
            </div>
            <button
              onClick={() => {
                onClose();
                navigateTo('wallet');
              }}
              className="w-full bg-[#fcd535] hover:bg-[#f0b90b] text-black font-medium py-2 rounded text-sm transition-colors"
            >
              Go to Wallet Transfer
            </button>
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

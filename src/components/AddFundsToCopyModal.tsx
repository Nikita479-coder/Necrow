import { useState, useEffect } from 'react';
import { X, AlertCircle, Wallet, ArrowDown, Plus, TrendingUp, Info } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface AddFundsToCopyModalProps {
  isOpen: boolean;
  onClose: () => void;
  relationshipId: string;
  traderName: string;
  currentInitialBalance: number;
  currentBalance: number;
  isMock: boolean;
  onSuccess: () => void;
}

export default function AddFundsToCopyModal({
  isOpen,
  onClose,
  relationshipId,
  traderName,
  currentInitialBalance,
  currentBalance,
  isMock,
  onSuccess
}: AddFundsToCopyModalProps) {
  const { user } = useAuth();
  const [amount, setAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [mainWalletBalance, setMainWalletBalance] = useState(0);
  const [copyWalletBalance, setCopyWalletBalance] = useState(0);
  const [availableBalance, setAvailableBalance] = useState(0);
  const [loadingBalance, setLoadingBalance] = useState(true);
  const [transferAmount, setTransferAmount] = useState('');
  const [transferring, setTransferring] = useState(false);
  const [transferError, setTransferError] = useState('');

  useEffect(() => {
    if (isOpen && user) {
      fetchBalances();
    }
  }, [isOpen, user]);

  const fetchBalances = async () => {
    if (!user) return;
    setLoadingBalance(true);

    try {
      if (isMock) {
        setAvailableBalance(10000);
        setCopyWalletBalance(10000);
        setMainWalletBalance(0);
        setLoadingBalance(false);
        return;
      }

      const { data: mainWallet } = await supabase
        .from('wallets')
        .select('balance')
        .eq('user_id', user.id)
        .eq('wallet_type', 'main')
        .eq('currency', 'USDT')
        .maybeSingle();

      setMainWalletBalance(parseFloat(mainWallet?.balance || '0'));

      const { data: copyWallet } = await supabase
        .from('wallets')
        .select('balance')
        .eq('user_id', user.id)
        .eq('wallet_type', 'copy')
        .eq('currency', 'USDT')
        .maybeSingle();

      const totalCopyBalance = parseFloat(copyWallet?.balance || '0');
      setCopyWalletBalance(totalCopyBalance);

      const { data: allActiveRelationships } = await supabase
        .from('copy_relationships')
        .select('id, initial_balance')
        .eq('follower_id', user.id)
        .eq('is_active', true)
        .eq('is_mock', false);

      const totalAllocated = allActiveRelationships?.reduce(
        (sum, rel) => sum + parseFloat(rel.initial_balance || '0'),
        0
      ) || 0;

      const available = Math.max(0, totalCopyBalance - totalAllocated);
      setAvailableBalance(available);
    } catch (err) {
      console.error('Error fetching balances:', err);
    } finally {
      setLoadingBalance(false);
    }
  };

  const handleQuickTransfer = async () => {
    if (!user) return;

    const transferAmt = parseFloat(transferAmount);
    if (isNaN(transferAmt) || transferAmt <= 0) {
      setTransferError('Please enter a valid amount');
      return;
    }

    if (transferAmt > mainWalletBalance) {
      setTransferError('Insufficient balance in main wallet');
      return;
    }

    setTransferring(true);
    setTransferError('');

    try {
      const { data, error: rpcError } = await supabase.rpc('transfer_between_wallets', {
        user_id_param: user.id,
        currency_param: 'USDT',
        amount_param: transferAmt,
        from_wallet_type_param: 'main',
        to_wallet_type_param: 'copy'
      });

      if (rpcError) throw rpcError;

      if (data && !data.success) {
        setTransferError(data.error || 'Transfer failed');
        return;
      }

      setTransferAmount('');
      await fetchBalances();
    } catch (err: any) {
      console.error('Transfer error:', err);
      setTransferError(err.message || 'Failed to transfer funds');
    } finally {
      setTransferring(false);
    }
  };

  const handleAddFunds = async () => {
    if (!user) return;

    const addAmount = parseFloat(amount);
    if (isNaN(addAmount) || addAmount <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    if (addAmount < 10) {
      setError('Minimum top-up amount is 10 USDT');
      return;
    }

    if (!isMock && addAmount > availableBalance) {
      setError('Insufficient available balance. Please transfer more funds to your copy wallet.');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const { data, error: rpcError } = await supabase.rpc('add_funds_to_copy_trading', {
        p_relationship_id: relationshipId,
        p_amount: addAmount
      });

      if (rpcError) throw rpcError;

      if (!data?.success) {
        setError(data?.error || 'Failed to add funds');
        return;
      }

      onSuccess();
      onClose();
    } catch (err: any) {
      console.error('Error adding funds:', err);
      setError(err.message || 'Failed to add funds');
    } finally {
      setLoading(false);
    }
  };

  const presetPercentages = [25, 50, 75, 100];

  const handlePresetClick = (percentage: number) => {
    const calculated = (availableBalance * percentage) / 100;
    setAmount(calculated.toFixed(2));
  };

  if (!isOpen) return null;

  const newInitialBalance = currentInitialBalance + (parseFloat(amount) || 0);
  const newCurrentBalance = currentBalance + (parseFloat(amount) || 0);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
      <div className="bg-[#1e2329] rounded-lg w-full max-w-md max-h-[90vh] flex flex-col relative">
        <div className="sticky top-0 bg-[#1e2329] rounded-t-lg px-6 pt-6 pb-4 border-b border-[#2b3139] z-10">
          <button
            onClick={onClose}
            className="absolute top-4 right-4 text-[#848e9c] hover:text-white bg-[#2b3139] hover:bg-[#3b4149] rounded-full p-1.5 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>

          <div className="flex items-center gap-3 mb-1 pr-10">
            <div className="w-10 h-10 rounded-xl bg-[#0ecb81]/10 flex items-center justify-center">
              <Plus className="w-5 h-5 text-[#0ecb81]" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-white">Add Funds</h2>
              <p className="text-[#848e9c] text-sm">
                Top up your allocation with {traderName}
              </p>
            </div>
          </div>
        </div>

        <div className="overflow-y-auto flex-1 px-6 py-4">
          <div className="bg-[#0b0e11] border border-[#2b3139] rounded-lg p-4 mb-4">
            <div className="flex items-center justify-between mb-3">
              <span className="text-[#848e9c] text-sm">Current Allocation</span>
              <span className="text-white font-semibold">
                {currentInitialBalance.toLocaleString(undefined, {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })} USDT
              </span>
            </div>
            <div className="flex items-center justify-between mb-3">
              <span className="text-[#848e9c] text-sm">Current Balance (with P&L)</span>
              <span className={`font-semibold ${currentBalance >= currentInitialBalance ? 'text-[#0ecb81]' : 'text-[#f6465d]'}`}>
                {currentBalance.toLocaleString(undefined, {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })} USDT
              </span>
            </div>
            {isMock && (
              <div className="pt-2 border-t border-[#2b3139]">
                <span className="text-[#fcd535] text-xs">Mock Trading - Virtual Funds</span>
              </div>
            )}
          </div>

          <div className="bg-[#0b0e11] border border-[#2b3139] rounded-lg p-3 mb-4">
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <Wallet className="w-4 h-4 text-[#848e9c]" />
                <span className="text-[#848e9c] text-sm">
                  {isMock ? 'Demo Balance' : 'Available for This Trader'}
                </span>
              </div>
              <div className="text-right">
                {loadingBalance ? (
                  <span className="text-[#848e9c] text-sm">Loading...</span>
                ) : (
                  <div className="text-white font-semibold">
                    {availableBalance.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USDT
                  </div>
                )}
              </div>
            </div>
            {!isMock && !loadingBalance && (
              <>
                {copyWalletBalance > 0 && copyWalletBalance !== availableBalance && (
                  <div className="flex items-center justify-between pt-2 border-t border-[#2b3139]">
                    <span className="text-[#848e9c] text-xs">Total Copy Wallet</span>
                    <span className="text-[#848e9c] text-xs font-medium">
                      {copyWalletBalance.toLocaleString(undefined, {
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

          {!isMock && !loadingBalance && availableBalance < 10 && mainWalletBalance > 0 && (
            <div className="bg-[#fcd535]/10 border border-[#fcd535]/30 rounded-lg p-4 mb-4">
              <div className="flex items-start gap-2 mb-3">
                <AlertCircle className="w-4 h-4 text-[#fcd535] flex-shrink-0 mt-0.5" />
                <div className="flex-1">
                  <p className="text-[#fcd535] text-sm font-medium">Low Available Balance</p>
                  <p className="text-[#fcd535]/80 text-xs mt-1">
                    Transfer funds from your main wallet to add to this allocation
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
                      <div className="text-white font-medium">{copyWalletBalance.toFixed(2)} USDT</div>
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

          {error && (
            <div className="bg-[#f6465d]/10 border border-[#f6465d]/30 rounded-lg p-3 mb-4 flex items-start gap-2">
              <AlertCircle className="w-4 h-4 text-[#f6465d] flex-shrink-0 mt-0.5" />
              <span className="text-[#f6465d] text-sm">{error}</span>
            </div>
          )}

          <div className="space-y-4">
            <div>
              <label className="block text-white text-sm font-medium mb-2">
                Amount to Add
              </label>
              <div className="relative">
                <input
                  type="number"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-[#2b3139] rounded-lg px-4 py-3 text-white pr-16"
                  placeholder="Enter amount"
                  min="10"
                />
                <span className="absolute right-4 top-1/2 -translate-y-1/2 text-[#848e9c]">USDT</span>
              </div>
            </div>

            {!loadingBalance && availableBalance > 0 && (
              <div className="flex gap-2">
                {presetPercentages.map((pct) => (
                  <button
                    key={pct}
                    onClick={() => handlePresetClick(pct)}
                    className="flex-1 py-2 rounded text-sm font-medium transition-colors bg-[#0b0e11] text-[#848e9c] hover:text-white border border-[#2b3139] hover:border-[#474d57]"
                  >
                    {pct}%
                  </button>
                ))}
              </div>
            )}

            {parseFloat(amount) > 0 && (
              <div className="bg-[#0ecb81]/10 border border-[#0ecb81]/30 rounded-lg p-4 space-y-2">
                <div className="flex items-center gap-2 mb-2">
                  <TrendingUp className="w-4 h-4 text-[#0ecb81]" />
                  <span className="text-[#0ecb81] text-sm font-medium">Preview After Adding Funds</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[#848e9c]">New Initial Balance</span>
                  <span className="text-white font-medium">
                    {newInitialBalance.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USDT
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[#848e9c]">New Current Balance</span>
                  <span className="text-white font-medium">
                    {newCurrentBalance.toLocaleString(undefined, {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2
                    })} USDT
                  </span>
                </div>
              </div>
            )}

            <div className="bg-[#1e2329] border border-[#2b3139] rounded-lg p-3 flex items-start gap-2">
              <Info className="w-4 h-4 text-[#848e9c] flex-shrink-0 mt-0.5" />
              <p className="text-[#848e9c] text-xs">
                Adding funds will increase your allocation with this trader. Your past trades and P&L history will not be affected.
              </p>
            </div>

            <button
              onClick={handleAddFunds}
              disabled={loading || !amount || parseFloat(amount) < 10 || (!isMock && parseFloat(amount) > availableBalance)}
              className="w-full bg-[#0ecb81] hover:bg-[#0db777] text-white font-semibold py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Adding Funds...' : `Add ${parseFloat(amount) > 0 ? parseFloat(amount).toFixed(2) : '0.00'} USDT`}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

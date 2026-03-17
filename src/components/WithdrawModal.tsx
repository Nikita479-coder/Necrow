import { useState, useEffect, useMemo } from 'react';
import { X, AlertTriangle, Send, Users, Zap, CheckCircle2, Smartphone } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import CryptoIcon from './CryptoIcon';

interface WithdrawModalProps {
  isOpen: boolean;
  onClose: () => void;
  crypto: {
    symbol: string;
    name: string;
    balance: string;
    networks: string[];
    fee: string;
    minWithdraw: string;
  };
}

export default function WithdrawModal({ isOpen, onClose, crypto }: WithdrawModalProps) {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [withdrawType, setWithdrawType] = useState<'external' | 'internal'>('external');
  const [selectedNetwork, setSelectedNetwork] = useState(crypto.networks[0]);
  const [address, setAddress] = useState('');
  const [amount, setAmount] = useState('');

  const [recipientInput, setRecipientInput] = useState('');
  const [isTransferring, setIsTransferring] = useState(false);
  const [isWithdrawing, setIsWithdrawing] = useState(false);
  const [withdrawalBlocked, setWithdrawalBlocked] = useState(false);
  const [blockReason, setBlockReason] = useState('');
  const [mfaEnabled, setMfaEnabled] = useState(false);
  const [mfaFactorId, setMfaFactorId] = useState('');
  const [needsMfaForWithdraw, setNeedsMfaForWithdraw] = useState(false);
  const [withdrawMfaCode, setWithdrawMfaCode] = useState('');
  const [withdrawMfaError, setWithdrawMfaError] = useState('');

  const isExternalFormValid = useMemo(() => {
    const addressValid = address.trim().length >= 10;
    const amountValid = parseFloat(amount) > 0;
    return addressValid && amountValid && !withdrawalBlocked && mfaEnabled;
  }, [address, amount, withdrawalBlocked, mfaEnabled]);

  const isInternalFormValid = useMemo(() => {
    const recipientValid = recipientInput.trim().length > 0;
    const amountValid = parseFloat(amount) > 0;
    return recipientValid && amountValid && !withdrawalBlocked;
  }, [recipientInput, amount, withdrawalBlocked]);

  useEffect(() => {
    if (isOpen) {
      setWithdrawType('external');
      setSelectedNetwork(crypto.networks[0]);
      setAddress('');
      setAmount('');
      setRecipientInput('');
      setNeedsMfaForWithdraw(false);
      setWithdrawMfaCode('');
      setWithdrawMfaError('');
      checkWithdrawalStatus();
      loadMfaStatus();
    }
  }, [isOpen, crypto.networks]);

  const loadMfaStatus = async () => {
    if (!user) return;

    try {
      await supabase.auth.refreshSession();
      const { data } = await supabase.auth.mfa.listFactors();
      const totpFactor = data?.totp?.find((factor: any) => factor.status === 'verified');
      setMfaEnabled(!!totpFactor);
      setMfaFactorId(totpFactor?.id || '');
    } catch (error) {
      console.error('Error loading MFA status:', error);
      setMfaEnabled(false);
      setMfaFactorId('');
    }
  };

  const checkWithdrawalStatus = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase.rpc('check_withdrawal_allowed', {
        p_user_id: user.id
      });

      if (error) throw error;

      if (data && !data.allowed) {
        setWithdrawalBlocked(true);
        setBlockReason(data.reason || 'Withdrawals are temporarily blocked');
      } else {
        setWithdrawalBlocked(false);
        setBlockReason('');
      }
    } catch (error) {
      console.error('Error checking withdrawal status:', error);
    }
  };

  const networkFee = parseFloat(crypto.fee);
  const amountNum = parseFloat(amount) || 0;
  const availableBalance = parseFloat(crypto.balance) || 0;
  const receiveAmount = withdrawType === 'external'
    ? (amountNum > networkFee ? (amountNum - networkFee).toFixed(6) : '0')
    : amount;

  const handlePaste = async () => {
    try {
      const text = await navigator.clipboard.readText();
      setAddress(text);
    } catch (err) {
      console.error('Failed to read clipboard:', err);
    }
  };

  const handleWithdraw = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();

    if (isWithdrawing) return;
    setWithdrawMfaError('');

    if (!user) {
      showToast('Please sign in to withdraw', 'error');
      return;
    }

    if (!mfaEnabled) {
      showToast('Please enable 2FA before making a withdrawal', 'error');
      return;
    }

    if (!address || address.trim().length < 10) {
      showToast('Please enter a valid wallet address', 'error');
      return;
    }

    const withdrawAmount = parseFloat(amount);
    if (isNaN(withdrawAmount) || withdrawAmount <= 0) {
      showToast('Please enter a valid amount', 'error');
      return;
    }

    const minWithdraw = parseFloat(crypto.minWithdraw);
    if (withdrawAmount < minWithdraw) {
      showToast(`Minimum withdrawal is ${minWithdraw} ${crypto.symbol}`, 'error');
      return;
    }

    if (withdrawAmount > availableBalance) {
      showToast(`Insufficient balance. Available: ${availableBalance.toFixed(6)} ${crypto.symbol}`, 'error');
      return;
    }

    if (mfaEnabled && !needsMfaForWithdraw) {
      setNeedsMfaForWithdraw(true);
      return;
    }

    if (mfaEnabled && needsMfaForWithdraw) {
      if (!withdrawMfaCode || withdrawMfaCode.length !== 6) {
        setWithdrawMfaError('Please enter a valid 6-digit 2FA code');
        return;
      }

      try {
        const { data: challengeData, error: challengeError } = await supabase.auth.mfa.challenge({
          factorId: mfaFactorId
        });

        if (challengeError) {
          setWithdrawMfaError('Failed to initiate 2FA verification. Please try again.');
          return;
        }

        const { error: verifyError } = await supabase.auth.mfa.verify({
          factorId: mfaFactorId,
          challengeId: challengeData.id,
          code: withdrawMfaCode
        });

        if (verifyError) {
          setWithdrawMfaError('Invalid 2FA code. Please try again.');
          return;
        }
      } catch (error) {
        console.error('Error verifying withdrawal MFA:', error);
        setWithdrawMfaError('Failed to verify 2FA. Please try again.');
        return;
      }
    }

    setIsWithdrawing(true);

    const makeRequest = async (attempt: number): Promise<boolean> => {
      try {
        const { data, error } = await supabase.functions.invoke('submit-withdrawal', {
          body: {
            currency: crypto.symbol,
            amount: withdrawAmount,
            address: address.trim(),
            network: selectedNetwork
          }
        });

        if (error) {
          if (attempt < 2 && (error.message?.includes('Failed to fetch') || error.message?.includes('fetch'))) {
            await new Promise(r => setTimeout(r, 500));
            return makeRequest(attempt + 1);
          }
          showToast(error.message || 'Failed to submit withdrawal', 'error');
          return false;
        }

        if (data?.success) {
          showToast(`Withdrawal request submitted for ${withdrawAmount} ${crypto.symbol}`, 'success');
          setNeedsMfaForWithdraw(false);
          setWithdrawMfaCode('');
          setWithdrawMfaError('');
          onClose();
          return true;
        } else {
          showToast(data?.error || 'Withdrawal failed. Please try again.', 'error');
          return false;
        }
      } catch (err: any) {
        if (attempt < 2) {
          await new Promise(r => setTimeout(r, 500));
          return makeRequest(attempt + 1);
        }
        showToast(err.message || 'Failed to submit withdrawal request', 'error');
        return false;
      }
    };

    await makeRequest(0);
    setIsWithdrawing(false);
  };

  const handleTransferToUser = async () => {
    if (!recipientInput.trim() || !amount || parseFloat(amount) <= 0) {
      showToast('Please enter a recipient email/username and amount', 'error');
      return;
    }

    setIsTransferring(true);
    try {
      const { data, error } = await supabase.functions.invoke('transfer-to-user', {
        body: {
          recipient_identifier: recipientInput.trim(),
          amount: parseFloat(amount),
          currency: crypto.symbol
        }
      });

      if (error) throw error;

      if (data.success) {
        showToast(`Successfully sent ${data.amount} ${data.currency} to ${data.recipient_name}`, 'success');
        onClose();
      } else {
        showToast(data.error || 'Transfer failed', 'error');
      }
    } catch (error: any) {
      console.error('Transfer error:', error);
      showToast(error.message || 'Failed to complete transfer', 'error');
    } finally {
      setIsTransferring(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-[#1a1d24] border border-gray-800 rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-[#1a1d24] border-b border-gray-800 p-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-gradient-to-br from-[#f0b90b] to-[#f8d12f] rounded-full flex items-center justify-center">
              <Send className="w-6 h-6 text-black" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-white">Withdraw {crypto.symbol}</h2>
              <p className="text-gray-400 text-sm">
                {withdrawType === 'external' ? 'Send to external wallet' : 'Send to Shark user'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div className="flex items-center gap-3 p-4 bg-[#0b0e11] border border-gray-800 rounded-xl">
            <CryptoIcon symbol={crypto.symbol} size={48} />
            <div>
              <div className="text-gray-400 text-sm">Available Balance</div>
              <div className="text-2xl font-bold text-white">{crypto.balance} {crypto.symbol}</div>
            </div>
          </div>

          {withdrawalBlocked && (
            <div className="bg-red-500/10 border border-red-500/50 rounded-xl p-4">
              <div className="flex items-start gap-3">
                <AlertTriangle className="w-6 h-6 text-red-500 flex-shrink-0 mt-0.5" />
                <div>
                  <h3 className="text-red-500 font-semibold text-lg mb-1">Withdrawals Blocked</h3>
                  <p className="text-gray-300 text-sm mb-3">{blockReason}</p>
                  <p className="text-gray-400 text-xs">
                    Please contact support for more information.
                  </p>
                </div>
              </div>
            </div>
          )}

          <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-1 flex gap-1">
            <button
              onClick={() => setWithdrawType('external')}
              className={`flex-1 px-4 py-3 rounded-lg font-semibold transition-all flex items-center justify-center gap-2 ${
                withdrawType === 'external'
                  ? 'bg-[#f0b90b] text-black shadow-lg'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <Send className="w-4 h-4" />
              External Wallet
            </button>
            <button
              onClick={() => setWithdrawType('internal')}
              className={`flex-1 px-4 py-3 rounded-lg font-semibold transition-all flex items-center justify-center gap-2 ${
                withdrawType === 'internal'
                  ? 'bg-[#0ecb81] text-black shadow-lg'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <Users className="w-4 h-4" />
              Shark Email
            </button>
          </div>

          {withdrawType === 'external' ? (
            <>
              <div>
                <label className="text-gray-400 text-sm font-medium mb-2 block">Select Network</label>
                <div className="space-y-2">
                  {crypto.networks.map((network) => (
                    <button
                      key={network}
                      onClick={() => setSelectedNetwork(network)}
                      className={`w-full p-4 rounded-xl border transition-all text-left ${
                        selectedNetwork === network
                          ? 'bg-[#f0b90b]/10 border-[#f0b90b] shadow-lg shadow-[#f0b90b]/20'
                          : 'bg-[#0b0e11] border-gray-700 hover:border-gray-600'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <div className="font-bold text-white mb-1">{network}</div>
                          <div className="text-gray-400 text-sm">Network fee: {crypto.fee} {crypto.symbol}</div>
                        </div>
                        {selectedNetwork === network && (
                          <CheckCircle2 className="w-6 h-6 text-[#f0b90b]" />
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-gray-400 text-sm font-medium">Withdrawal Address</label>
                  <button
                    onClick={handlePaste}
                    className="text-[#f0b90b] text-sm hover:text-[#f8d12f] transition-colors font-medium"
                  >
                    Paste
                  </button>
                </div>
                <input
                  type="text"
                  placeholder="Enter wallet address"
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors font-mono text-sm"
                />
              </div>

              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-gray-400 text-sm font-medium">Amount</label>
                  <div className="text-gray-400 text-sm">
                    Min: <span className="text-white font-semibold">{crypto.minWithdraw} {crypto.symbol}</span>
                  </div>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    placeholder="0.00"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors pr-24 text-lg font-semibold"
                  />
                  <button
                    onClick={() => setAmount(availableBalance.toFixed(6))}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-bold px-4 py-1.5 rounded-lg text-sm transition-colors"
                  >
                    MAX
                  </button>
                </div>
                <div className="flex gap-2 mt-2">
                  {['25%', '50%', '75%'].map((percent) => (
                    <button
                      key={percent}
                      onClick={() => {
                        const percentage = parseInt(percent) / 100;
                        setAmount((availableBalance * percentage).toFixed(6));
                      }}
                      className="flex-1 px-3 py-2 bg-[#0b0e11] hover:bg-[#2b3139] border border-gray-700 hover:border-[#f0b90b] rounded-lg text-sm text-gray-400 hover:text-white transition-colors"
                    >
                      {percent}
                    </button>
                  ))}
                </div>
              </div>

              {amount && parseFloat(amount) > 0 && (
                <div className="bg-gradient-to-r from-[#0b0e11] to-[#181a20] border border-gray-700 rounded-xl p-4 space-y-3">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Network Fee</span>
                    <span className="text-white font-semibold">{crypto.fee} {crypto.symbol}</span>
                  </div>
                  <div className="h-px bg-gradient-to-r from-transparent via-gray-700 to-transparent"></div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-400">You'll Receive</span>
                    <span className="text-[#f0b90b] font-bold text-lg">{receiveAmount} {crypto.symbol}</span>
                  </div>
                </div>
              )}

              <div className="bg-gradient-to-r from-yellow-900/20 to-orange-900/10 border border-yellow-700/30 rounded-xl p-4">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
                  <div className="text-sm text-gray-300 space-y-2">
                    <p className="font-semibold text-white">Security Notice:</p>
                    <ul className="space-y-1 text-xs">
                      <li className="flex items-start gap-2">
                        <span className="text-yellow-400 mt-0.5">•</span>
                        <span>Double-check the withdrawal address - transactions cannot be reversed</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-yellow-400 mt-0.5">•</span>
                        <span>Ensure you're using the correct network</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-yellow-400 mt-0.5">•</span>
                        <span>Minimum withdrawal: {crypto.minWithdraw} {crypto.symbol}</span>
                      </li>
                    </ul>
                  </div>
                </div>
              </div>

              {mfaEnabled ? (
                <div className="bg-[#0b0e11] border border-[#f0b90b]/30 rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <Smartphone className="w-5 h-5 text-[#f0b90b] flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <p className="text-white text-sm font-semibold">2FA verification required for withdrawals</p>
                      <p className="text-gray-400 text-xs mt-1">
                        Enter the 6-digit code from your authenticator app before submitting your withdrawal.
                      </p>
                    </div>
                  </div>

                  {needsMfaForWithdraw && (
                    <div className="mt-4 space-y-3">
                      <input
                        type="text"
                        value={withdrawMfaCode}
                        onChange={(e) => {
                          setWithdrawMfaCode(e.target.value.replace(/\D/g, '').slice(0, 6));
                          setWithdrawMfaError('');
                        }}
                        placeholder="000000"
                        maxLength={6}
                        autoComplete="off"
                        className="w-full bg-[#181a20] border border-gray-700 rounded-xl px-4 py-3 text-white text-center text-xl tracking-widest outline-none focus:border-[#f0b90b] font-mono"
                      />
                      {withdrawMfaError && (
                        <div className="flex items-center gap-2 text-red-400 text-sm">
                          <AlertTriangle className="w-4 h-4" />
                          {withdrawMfaError}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ) : (
                <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4">
                  <div className="flex items-start gap-3">
                    <AlertTriangle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                    <div>
                      <p className="text-red-400 text-sm font-semibold">2FA is required for withdrawals</p>
                      <p className="text-gray-400 text-xs mt-1">
                        Enable two-factor authentication in your security settings before sending funds to an external wallet.
                      </p>
                    </div>
                  </div>
                </div>
              )}

              <button
                type="button"
                onClick={(e) => handleWithdraw(e)}
                className={`w-full font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2 ${
                  !isExternalFormValid || isWithdrawing || (needsMfaForWithdraw && withdrawMfaCode.length !== 6)
                    ? 'bg-gray-700 text-gray-500 cursor-not-allowed'
                    : 'bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] hover:from-[#f8d12f] hover:to-[#f0b90b] text-black shadow-lg shadow-[#f0b90b]/20'
                }`}
              >
                {withdrawalBlocked ? (
                  <>
                    <AlertTriangle className="w-5 h-5" />
                    Withdrawals Blocked
                  </>
                ) : isWithdrawing ? (
                  <>Processing...</>
                ) : (
                  <>
                    <Send className="w-5 h-5" />
                    {needsMfaForWithdraw ? `Verify & Withdraw ${crypto.symbol}` : `Withdraw ${crypto.symbol}`}
                  </>
                )}
              </button>

              {needsMfaForWithdraw && (
                <button
                  type="button"
                  onClick={() => {
                    setNeedsMfaForWithdraw(false);
                    setWithdrawMfaCode('');
                    setWithdrawMfaError('');
                  }}
                  className="w-full bg-[#2b3139] hover:bg-[#3b4149] text-white font-semibold py-3 rounded-xl transition-colors"
                >
                  Cancel 2FA Verification
                </button>
              )}
            </>
          ) : (
            <>
              <div>
                <label className="text-gray-400 text-sm font-medium mb-2 block">Recipient Email or Username</label>
                <input
                  type="text"
                  placeholder="Enter email or username..."
                  value={recipientInput}
                  onChange={(e) => setRecipientInput(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#0ecb81] transition-colors"
                />
                <p className="text-xs text-gray-500 mt-2">
                  Enter the recipient's email address or username. We'll verify they exist before sending.
                </p>
              </div>

              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-gray-400 text-sm font-medium">Amount to Send</label>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    placeholder="0.00"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#0ecb81] transition-colors pr-24 text-lg font-semibold"
                  />
                  <button
                    onClick={() => setAmount(availableBalance.toFixed(6))}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 bg-[#0ecb81] hover:bg-[#0ecb81]/80 text-black font-bold px-4 py-1.5 rounded-lg text-sm transition-colors"
                  >
                    MAX
                  </button>
                </div>
                <div className="flex gap-2 mt-2">
                  {['25%', '50%', '75%'].map((percent) => (
                    <button
                      key={percent}
                      onClick={() => {
                        const percentage = parseInt(percent) / 100;
                        setAmount((availableBalance * percentage).toFixed(6));
                      }}
                      className="flex-1 px-3 py-2 bg-[#0b0e11] hover:bg-[#2b3139] border border-gray-700 hover:border-[#0ecb81] rounded-lg text-sm text-gray-400 hover:text-white transition-colors"
                    >
                      {percent}
                    </button>
                  ))}
                </div>
              </div>

              {amount && parseFloat(amount) > 0 && recipientInput && (
                <div className="bg-gradient-to-r from-[#0b0e11] to-[#181a20] border border-gray-700 rounded-xl p-4 space-y-3">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Transfer Fee</span>
                    <span className="text-[#0ecb81] font-semibold">FREE</span>
                  </div>
                  <div className="h-px bg-gradient-to-r from-transparent via-gray-700 to-transparent"></div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-400">Recipient will receive</span>
                    <span className="text-[#0ecb81] font-bold text-lg">{amount} {crypto.symbol}</span>
                  </div>
                </div>
              )}

              <div className="bg-gradient-to-r from-emerald-900/20 to-emerald-800/10 border border-emerald-700/30 rounded-xl p-4">
                <div className="flex items-start gap-3">
                  <Zap className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
                  <div className="text-sm text-gray-300 space-y-2">
                    <p className="font-semibold text-white">Instant Transfer Benefits:</p>
                    <ul className="space-y-1 text-xs">
                      <li className="flex items-start gap-2">
                        <span className="text-emerald-400 mt-0.5">•</span>
                        <span>No fees - 100% of your amount goes to the recipient</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-emerald-400 mt-0.5">•</span>
                        <span>Instant transfer - funds arrive immediately</span>
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-emerald-400 mt-0.5">•</span>
                        <span>Safe & secure - transfers only between verified users</span>
                      </li>
                    </ul>
                  </div>
                </div>
              </div>

              <button
                onClick={handleTransferToUser}
                disabled={!isInternalFormValid || isTransferring}
                className="w-full bg-gradient-to-r from-[#0ecb81] to-[#0ecb81]/80 hover:from-[#0ecb81]/90 hover:to-[#0ecb81]/70 disabled:from-gray-700 disabled:to-gray-700 disabled:cursor-not-allowed text-black disabled:text-gray-500 font-bold py-4 rounded-xl transition-all flex items-center justify-center gap-2 shadow-lg shadow-[#0ecb81]/20 disabled:shadow-none"
              >
                {withdrawalBlocked ? (
                  <>
                    <AlertTriangle className="w-5 h-5" />
                    Withdrawals Blocked
                  </>
                ) : isTransferring ? (
                  <>Processing...</>
                ) : (
                  <>
                    <Zap className="w-5 h-5" />
                    Send {crypto.symbol} Instantly
                  </>
                )}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

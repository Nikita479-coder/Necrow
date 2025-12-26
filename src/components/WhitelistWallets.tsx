import { useState, useEffect } from 'react';
import { Shield, Plus, Trash2, AlertCircle, CheckCircle2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import CryptoIcon from './CryptoIcon';

interface WhitelistedWallet {
  id: string;
  wallet_address: string;
  label: string;
  currency: string;
  network: string;
  created_at: string;
  last_used_at: string | null;
}

interface WhitelistWalletsProps {
  mfaEnabled: boolean;
}

function WhitelistWallets({ mfaEnabled }: WhitelistWalletsProps) {
  const { showToast } = useToast();
  const [wallets, setWallets] = useState<WhitelistedWallet[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);
  const [formData, setFormData] = useState({
    address: '',
    label: '',
    currency: 'USDT',
    network: 'TRC20'
  });
  const [verificationCode, setVerificationCode] = useState('');
  const [needsVerification, setNeedsVerification] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const cryptoOptions = [
    'BTC', 'ETH', 'USDT', 'USDC', 'BNB', 'SOL', 'XRP',
    'ADA', 'DOGE', 'MATIC', 'LTC', 'TRX'
  ];

  const networkOptions: Record<string, string[]> = {
    USDT: ['TRC20', 'ERC20', 'BEP20', 'Polygon', 'Solana'],
    USDC: ['ERC20', 'TRC20', 'BEP20', 'Polygon', 'Solana'],
    BTC: ['Bitcoin', 'BEP20'],
    ETH: ['Ethereum', 'BEP20', 'Arbitrum'],
    BNB: ['BEP20', 'BEP2'],
    SOL: ['Solana'],
    XRP: ['Ripple'],
    LTC: ['Litecoin'],
    TRX: ['TRC20'],
    DOGE: ['Dogecoin'],
    ADA: ['Cardano'],
    MATIC: ['Polygon', 'Ethereum'],
  };

  useEffect(() => {
    loadWallets();
  }, []);

  const loadWallets = async () => {
    try {
      const { data, error } = await supabase.rpc('get_whitelisted_wallets');

      if (error) throw error;

      if (data?.success && data.wallets) {
        setWallets(data.wallets);
      }
    } catch (error: any) {
      console.error('Error loading wallets:', error);
      showToast('Failed to load whitelisted wallets', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleAddWallet = async () => {
    if (!mfaEnabled) {
      showToast('Please enable 2FA first to manage whitelisted wallets', 'error');
      return;
    }

    if (!formData.address || !formData.label) {
      showToast('Please fill in all fields', 'error');
      return;
    }

    setNeedsVerification(true);
  };

  const handleVerifyAndAdd = async () => {
    if (!verificationCode || verificationCode.length !== 6) {
      showToast('Please enter a valid 6-digit code', 'error');
      return;
    }

    setSubmitting(true);

    try {
      const { data: factors } = await supabase.auth.mfa.listFactors();
      const totpFactor = factors?.totp?.find(f => f.status === 'verified');

      if (!totpFactor) {
        throw new Error('No verified 2FA factor found');
      }

      const { error: verifyError } = await supabase.auth.mfa.challenge({
        factorId: totpFactor.id
      });

      if (verifyError) throw verifyError;

      const { error: challengeError } = await supabase.auth.mfa.verify({
        factorId: totpFactor.id,
        challengeId: totpFactor.id,
        code: verificationCode
      });

      if (challengeError) {
        showToast('Invalid verification code', 'error');
        return;
      }

      const { data, error } = await supabase.rpc('add_whitelisted_wallet', {
        p_wallet_address: formData.address,
        p_label: formData.label,
        p_currency: formData.currency,
        p_network: formData.network
      });

      if (error) throw error;

      if (data?.error === 'MFA_REQUIRED') {
        showToast(data.message, 'error');
        return;
      }

      if (data?.success) {
        showToast('Wallet added to whitelist successfully!', 'success');
        setShowAddForm(false);
        setNeedsVerification(false);
        setFormData({ address: '', label: '', currency: 'USDT', network: 'TRC20' });
        setVerificationCode('');
        loadWallets();
      }
    } catch (error: any) {
      console.error('Error adding wallet:', error);
      showToast(error.message || 'Failed to add wallet', 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleRemoveWallet = async (walletId: string) => {
    if (!confirm('Are you sure you want to remove this wallet from the whitelist?')) {
      return;
    }

    try {
      const { data, error } = await supabase.rpc('remove_whitelisted_wallet', {
        p_wallet_id: walletId
      });

      if (error) throw error;

      if (data?.success) {
        showToast('Wallet removed from whitelist', 'success');
        loadWallets();
      }
    } catch (error: any) {
      console.error('Error removing wallet:', error);
      showToast('Failed to remove wallet', 'error');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="w-8 h-8 border-2 border-blue-500/30 border-t-blue-500 rounded-full animate-spin"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-xl font-bold text-white flex items-center gap-2">
            <Shield className="w-6 h-6 text-blue-400" />
            Whitelisted Withdrawal Addresses
          </h3>
          <p className="text-sm text-gray-400 mt-1">
            Only whitelisted addresses can be used for withdrawals. 2FA required.
          </p>
        </div>
        <button
          onClick={() => {
            if (!mfaEnabled) {
              showToast('Please enable 2FA first', 'error');
              return;
            }
            setShowAddForm(!showAddForm);
          }}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg transition-colors font-semibold"
        >
          <Plus className="w-4 h-4" />
          Add Address
        </button>
      </div>

      {!mfaEnabled && (
        <div className="bg-yellow-900/20 border border-yellow-700/30 rounded-xl p-4">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
            <div className="text-sm text-gray-300">
              <p className="font-semibold text-white mb-1">2FA Required</p>
              <p>You must enable two-factor authentication before you can manage whitelisted withdrawal addresses.</p>
            </div>
          </div>
        </div>
      )}

      {showAddForm && mfaEnabled && (
        <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-6 space-y-4">
          <h4 className="text-lg font-bold text-white">Add New Whitelisted Address</h4>

          {!needsVerification ? (
            <>
              <div>
                <label className="block text-white font-semibold mb-2">Cryptocurrency</label>
                <select
                  value={formData.currency}
                  onChange={(e) => {
                    const currency = e.target.value;
                    const networks = networkOptions[currency] || [currency];
                    setFormData({
                      ...formData,
                      currency,
                      network: networks[0]
                    });
                  }}
                  className="w-full bg-[#181a20] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-blue-500 transition-colors"
                >
                  {cryptoOptions.map(crypto => (
                    <option key={crypto} value={crypto}>{crypto}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-white font-semibold mb-2">Network</label>
                <select
                  value={formData.network}
                  onChange={(e) => setFormData({ ...formData, network: e.target.value })}
                  className="w-full bg-[#181a20] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-blue-500 transition-colors"
                >
                  {(networkOptions[formData.currency] || [formData.currency]).map(network => (
                    <option key={network} value={network}>{network}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-white font-semibold mb-2">Wallet Address</label>
                <input
                  type="text"
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  placeholder="Enter wallet address"
                  className="w-full bg-[#181a20] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-blue-500 transition-colors font-mono text-sm"
                />
              </div>

              <div>
                <label className="block text-white font-semibold mb-2">Label (Friendly Name)</label>
                <input
                  type="text"
                  value={formData.label}
                  onChange={(e) => setFormData({ ...formData, label: e.target.value })}
                  placeholder="e.g., My Hardware Wallet"
                  className="w-full bg-[#181a20] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-blue-500 transition-colors"
                />
              </div>

              <div className="flex gap-3">
                <button
                  onClick={() => setShowAddForm(false)}
                  className="flex-1 bg-gray-700 hover:bg-gray-600 text-white font-semibold py-3 rounded-lg transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleAddWallet}
                  className="flex-1 bg-blue-600 hover:bg-blue-500 text-white font-semibold py-3 rounded-lg transition-colors"
                >
                  Continue
                </button>
              </div>
            </>
          ) : (
            <>
              <div className="bg-blue-900/20 border border-blue-700/30 rounded-lg p-4">
                <p className="text-sm text-gray-300">
                  Enter your 2FA code to confirm adding this wallet to the whitelist.
                </p>
              </div>

              <div>
                <label className="block text-white font-semibold mb-2">2FA Code</label>
                <input
                  type="text"
                  value={verificationCode}
                  onChange={(e) => setVerificationCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  placeholder="000000"
                  className="w-full bg-[#181a20] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-blue-500 transition-colors text-center text-2xl font-mono tracking-widest"
                  maxLength={6}
                />
              </div>

              <div className="flex gap-3">
                <button
                  onClick={() => {
                    setNeedsVerification(false);
                    setVerificationCode('');
                  }}
                  disabled={submitting}
                  className="flex-1 bg-gray-700 hover:bg-gray-600 disabled:opacity-50 text-white font-semibold py-3 rounded-lg transition-colors"
                >
                  Back
                </button>
                <button
                  onClick={handleVerifyAndAdd}
                  disabled={submitting || verificationCode.length !== 6}
                  className="flex-1 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {submitting ? (
                    <>
                      <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      Adding...
                    </>
                  ) : (
                    'Verify & Add'
                  )}
                </button>
              </div>
            </>
          )}
        </div>
      )}

      <div className="space-y-3">
        {wallets.length === 0 ? (
          <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-8 text-center">
            <Shield className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">No whitelisted addresses yet</p>
            <p className="text-sm text-gray-500 mt-1">Add withdrawal addresses to get started</p>
          </div>
        ) : (
          wallets.map((wallet) => (
            <div
              key={wallet.id}
              className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4 hover:border-gray-600 transition-colors"
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4 flex-1 min-w-0">
                  <CryptoIcon symbol={wallet.currency} size={40} />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h4 className="text-white font-bold">{wallet.label}</h4>
                      <span className="px-2 py-0.5 bg-blue-900/30 border border-blue-700/30 rounded text-xs text-blue-400 font-medium">
                        {wallet.currency}
                      </span>
                      <span className="px-2 py-0.5 bg-gray-700 rounded text-xs text-gray-300">
                        {wallet.network}
                      </span>
                    </div>
                    <p className="text-gray-400 text-sm font-mono truncate">
                      {wallet.wallet_address}
                    </p>
                    <div className="flex items-center gap-4 mt-2 text-xs text-gray-500">
                      <span>Added {new Date(wallet.created_at).toLocaleDateString()}</span>
                      {wallet.last_used_at && (
                        <span>Last used {new Date(wallet.last_used_at).toLocaleDateString()}</span>
                      )}
                    </div>
                  </div>
                </div>
                <button
                  onClick={() => handleRemoveWallet(wallet.id)}
                  className="p-2 bg-red-900/20 hover:bg-red-900/40 border border-red-700/30 hover:border-red-600/50 rounded-lg transition-colors text-red-400 hover:text-red-300"
                >
                  <Trash2 className="w-5 h-5" />
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default WhitelistWallets;

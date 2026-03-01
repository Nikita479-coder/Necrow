import { useState, useEffect } from 'react';
import { Wallet, TrendingUp, Lock, CreditCard } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import AdminCardTransactions from './AdminCardTransactions';

interface Props {
  userId: string;
  userData: any;
  onRefresh: () => void;
}

export default function AdminUserWallets({ userId, userData, onRefresh }: Props) {
  const [wallets, setWallets] = useState<any[]>([]);
  const [futuresWallet, setFuturesWallet] = useState<any>(null);
  const [cardData, setCardData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    loadWallets();
  }, [userId, refreshKey]);

  useEffect(() => {
    setRefreshKey(prev => prev + 1);
  }, [userData]);

  const loadWallets = async () => {
    setLoading(true);
    try {
      const { data: walletsData } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', userId)
        .order('balance', { ascending: false });

      const { data: futuresData } = await supabase
        .from('futures_margin_wallets')
        .select('*')
        .eq('user_id', userId)
        .single();

      const { data: cardDataResult } = await supabase
        .from('shark_cards')
        .select('*')
        .eq('user_id', userId)
        .eq('status', 'active')
        .single();

      setWallets(walletsData || []);
      setFuturesWallet(futuresData);
      setCardData(cardDataResult);
    } catch (error) {
      console.error('Error loading wallets:', error);
    } finally {
      setLoading(false);
    }
  };

  const walletTypeLabels: Record<string, string> = {
    main: 'Main Wallet',
    assets: 'Assets Wallet',
    copy: 'Copy Trading',
    futures: 'Futures Wallet',
    card: 'Shark Card Wallet'
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white mb-4">Spot Wallets</h2>
        {wallets.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-12 text-center border border-gray-800">
            <Wallet className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400">No wallets found for this user</p>
          </div>
        ) : (
          <div className="space-y-3">
            {Object.entries(
              wallets.reduce((acc: any, wallet) => {
                if (!acc[wallet.wallet_type]) acc[wallet.wallet_type] = [];
                acc[wallet.wallet_type].push(wallet);
                return acc;
              }, {})
            ).map(([walletType, typeWallets]: [string, any]) => (
            <div key={walletType} className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
              <h3 className="text-lg font-bold text-white mb-4">{walletTypeLabels[walletType] || walletType}</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {typeWallets.map((wallet: any) => {
                  const balance = parseFloat(wallet.balance);
                  const lockedBalance = parseFloat(wallet.locked_balance);
                  const availableBalance = Math.max(0, balance - lockedBalance);
                  const hasInconsistency = balance < lockedBalance;

                  return (
                  <div key={wallet.id} className={`bg-[#1a1d24] rounded-lg p-4 border ${hasInconsistency ? 'border-red-500/50' : 'border-gray-800'}`}>
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-white font-bold">{wallet.currency}</span>
                      <div className="flex items-center gap-2">
                        {hasInconsistency && (
                          <span className="text-xs bg-red-500/20 text-red-400 px-2 py-0.5 rounded">Inconsistent</span>
                        )}
                        {lockedBalance > 0 && (
                          <Lock className="w-4 h-4 text-yellow-400" />
                        )}
                      </div>
                    </div>
                    <div className="space-y-2">
                      <div>
                        <p className="text-xs text-gray-400">Available</p>
                        <p className="text-lg font-bold text-white">
                          {availableBalance.toFixed(8)}
                        </p>
                      </div>
                      {lockedBalance > 0 && (
                        <div>
                          <p className="text-xs text-gray-400">Locked</p>
                          <p className="text-sm text-yellow-400">{lockedBalance.toFixed(8)}</p>
                        </div>
                      )}
                      <div>
                        <p className="text-xs text-gray-400">Total Balance</p>
                        <p className="text-sm text-white">{balance.toFixed(8)}</p>
                      </div>
                      <div className="pt-2 border-t border-gray-700">
                        <p className="text-xs text-gray-500">
                          Deposited: {parseFloat(wallet.total_deposited).toFixed(2)} •
                          Withdrawn: {parseFloat(wallet.total_withdrawn).toFixed(2)}
                        </p>
                      </div>
                    </div>
                  </div>
                  );
                })}
              </div>
            </div>
          ))}
          </div>
        )}
      </div>

      {futuresWallet && (
        <div>
          <h2 className="text-xl font-bold text-white mb-4">Futures Margin Wallet</h2>
          <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div>
                <p className="text-sm text-gray-400 mb-1">Available Balance</p>
                <p className="text-xl font-bold text-green-400">
                  ${parseFloat(futuresWallet.available_balance).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-400 mb-1">Locked Balance</p>
                <p className="text-xl font-bold text-yellow-400">
                  ${parseFloat(futuresWallet.locked_balance).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-400 mb-1">Total Deposited</p>
                <p className="text-xl font-bold text-white">
                  ${parseFloat(futuresWallet.total_deposited).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-400 mb-1">Total Withdrawn</p>
                <p className="text-xl font-bold text-white">
                  ${parseFloat(futuresWallet.total_withdrawn).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-white flex items-center gap-2">
            <CreditCard className="w-6 h-6 text-[#f0b90b]" />
            Shark Card Transactions
          </h2>
          <AdminCardTransactions
            userId={userId}
            userName={userData?.full_name || userData?.email || 'User'}
            cardId={cardData?.id}
            onTransactionCreated={() => {
              loadWallets();
              onRefresh();
            }}
          />
        </div>
        {!cardData && (
          <div className="bg-gray-800/30 border border-gray-700 rounded-lg p-6 text-center">
            <CreditCard className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">User does not have an active Shark Card</p>
          </div>
        )}
      </div>
    </div>
  );
}

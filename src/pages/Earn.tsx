import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import CryptoIcon from '../components/CryptoIcon';
import { TrendingUp, Clock, Shield, Search, Info, X, ChevronLeft, ChevronRight, CheckCircle, AlertCircle, BookOpen, Award } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import { Toast } from '../components/Toast';

interface EarnProduct {
  id: string;
  coin: string;
  apr: string;
  duration_days: number;
  product_type: 'flexible' | 'fixed';
  min_amount: number;
  max_amount: number | null;
  invested_amount: number;
  total_cap: number;
  badge?: string;
  is_featured: boolean;
  is_new_user_exclusive: boolean;
  eligibility_hours: number | null;
}

interface UserStake {
  id: string;
  product_id: string;
  amount: string;
  apr_locked: string;
  earned_rewards: string;
  start_date: string;
  end_date: string | null;
  status: string;
  coin?: string;
  product_type?: string;
  duration_days?: number;
}

interface WalletBalance {
  currency: string;
  balance: number;
}

function Earn() {
  const { user } = useAuth();
  const { toasts, showSuccess, showError, showInfo, removeToast } = useToast();
  const [activeTab, setActiveTab] = useState<'all' | 'flexible' | 'fixed'>('all');
  const [mainTab, setMainTab] = useState<'products' | 'guide'>('products');
  const [searchQuery, setSearchQuery] = useState('');
  const [products, setProducts] = useState<EarnProduct[]>([]);
  const [userStakes, setUserStakes] = useState<UserStake[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedProduct, setSelectedProduct] = useState<EarnProduct | null>(null);
  const [investAmount, setInvestAmount] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [investLoading, setInvestLoading] = useState(false);
  const [isNewUser, setIsNewUser] = useState(false);
  const [walletBalances, setWalletBalances] = useState<WalletBalance[]>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    loadProducts();
    if (user) {
      checkNewUserStatus();
      loadUserStakes();
      loadWalletBalances();
    }
  }, [user]);

  const loadWalletBalances = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('wallets')
        .select('currency, balance')
        .eq('user_id', user.id)
        .eq('wallet_type', 'main');

      if (error) throw error;

      if (data) {
        setWalletBalances(data.map(w => ({
          currency: w.currency,
          balance: parseFloat(w.balance || '0')
        })));
      }
    } catch (error) {
      console.error('Error loading wallet balances:', error);
    }
  };

  const checkNewUserStatus = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase.rpc('check_new_user_eligibility', {
        p_user_id: user.id,
        p_eligibility_hours: 48
      });

      if (error) throw error;
      setIsNewUser(data === true);
    } catch (error) {
      console.error('Error checking new user status:', error);
    }
  };

  const loadProducts = async () => {
    try {
      const { data, error } = await supabase
        .from('earn_products')
        .select('*')
        .eq('is_active', true)
        .order('is_featured', { ascending: false })
        .order('apr', { ascending: false });

      if (error) throw error;

      if (data) {
        setProducts(data.map(p => ({
          ...p,
          apr: p.apr.toString(),
          invested_amount: parseFloat(p.invested_amount || '0'),
          total_cap: parseFloat(p.total_cap || '0'),
          min_amount: parseFloat(p.min_amount || '0'),
          max_amount: p.max_amount ? parseFloat(p.max_amount) : null
        })));
      }
    } catch (error) {
      console.error('Error loading products:', error);
      showError('Failed to load earn products');
    } finally {
      setLoading(false);
    }
  };

  const loadUserStakes = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('user_stakes')
        .select(`
          *,
          earn_products:product_id (coin, product_type, duration_days)
        `)
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', { ascending: false });

      if (error) throw error;

      if (data) {
        setUserStakes(data.map(stake => ({
          ...stake,
          coin: (stake.earn_products as any)?.coin,
          product_type: (stake.earn_products as any)?.product_type,
          duration_days: (stake.earn_products as any)?.duration_days
        })));
      }
    } catch (error) {
      console.error('Error loading stakes:', error);
    }
  };

  const handleInvest = async () => {
    if (!user) {
      showError('Please sign in to invest');
      return;
    }

    if (!selectedProduct || !investAmount) {
      showError('Please enter an investment amount');
      return;
    }

    const amount = parseFloat(investAmount);

    if (isNaN(amount) || amount <= 0) {
      showError('Please enter a valid amount');
      return;
    }

    if (amount < selectedProduct.min_amount) {
      showError(`Minimum investment is ${selectedProduct.min_amount} ${selectedProduct.coin}`);
      return;
    }

    if (selectedProduct.max_amount && amount > selectedProduct.max_amount) {
      showError(`Maximum investment is ${selectedProduct.max_amount} ${selectedProduct.coin}`);
      return;
    }

    if (selectedProduct.is_new_user_exclusive && !isNewUser) {
      showError('This offer is only available for new users within 48 hours of registration');
      return;
    }

    if (selectedProduct.is_new_user_exclusive) {
      const { data: existingStakes, error: stakeCheckError } = await supabase
        .from('user_stakes')
        .select('id, earn_products!inner(is_new_user_exclusive)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .eq('earn_products.is_new_user_exclusive', true);

      if (stakeCheckError) {
        console.error('Error checking existing stakes:', stakeCheckError);
      } else if (existingStakes && existingStakes.length > 0) {
        showError('You can only stake in one New User Exclusive product at a time');
        return;
      }
    }

    setInvestLoading(true);

    try {
      const { data, error } = await supabase.rpc('stake_tokens', {
        user_id_param: user.id,
        product_id_param: selectedProduct.id,
        amount_param: amount
      });

      if (error) throw error;

      if (data && !data.success) {
        showError(data.error || 'Failed to stake tokens');
        return;
      }

      showSuccess(`Successfully invested ${amount} ${selectedProduct.coin}! You're earning ${selectedProduct.apr}% APR.`);
      setShowModal(false);
      setInvestAmount('');
      setSelectedProduct(null);

      await loadProducts();
      await loadUserStakes();
      await loadWalletBalances();
    } catch (error: any) {
      console.error('Error investing:', error);
      showError(error.message || 'Failed to complete investment. Please try again.');
    } finally {
      setInvestLoading(false);
    }
  };

  const handleWithdraw = async (stake: UserStake) => {
    if (!user) return;

    if (stake.product_type === 'fixed' && stake.end_date) {
      const endDate = new Date(stake.end_date);
      if (endDate > new Date()) {
        const canUnstake = window.confirm('Unstaking before maturity may result in reduced rewards. Continue?');
        if (!canUnstake) return;
      }
    }

    try {
      const { data, error } = await supabase.rpc('unstake_tokens', {
        stake_id_param: stake.id
      });

      if (error) throw error;

      if (data && !data.success) {
        showError(data.error || 'Failed to unstake tokens');
        return;
      }

      const totalAmount = data.total || 0;
      showSuccess(`Successfully withdrawn ${totalAmount.toFixed(6)} ${stake.coin} to your wallet!`);
      await loadUserStakes();
      await loadProducts();
    } catch (error: any) {
      console.error('Error withdrawing:', error);
      showError(error.message || 'Failed to withdraw. Please try again.');
    }
  };

  const totalEarnAsset = userStakes.reduce((sum, stake) => {
    return sum + parseFloat(stake.amount) + parseFloat(stake.earned_rewards);
  }, 0);

  const yesterdayYield = userStakes.reduce((sum, stake) => {
    const dailyYield = (parseFloat(stake.amount) * parseFloat(stake.apr_locked) / 100) / 365;
    return sum + dailyYield;
  }, 0);

  const newUserProducts = products.filter(p => p.is_new_user_exclusive && isNewUser);
  const regularFeaturedProducts = products.filter(p => p.is_featured && !p.is_new_user_exclusive);

  const filteredProducts = products.filter(product => {
    if (product.is_new_user_exclusive && !isNewUser) return false;
    if (activeTab === 'flexible' && product.product_type !== 'flexible') return false;
    if (activeTab === 'fixed' && product.product_type !== 'fixed') return false;
    if (searchQuery && !product.coin.toLowerCase().includes(searchQuery.toLowerCase())) return false;
    return true;
  });

  const totalPages = Math.ceil(filteredProducts.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = startIndex + itemsPerPage;
  const paginatedProducts = filteredProducts.slice(startIndex, endIndex);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, activeTab]);

  const openInvestModal = (product: EarnProduct) => {
    if (product.is_new_user_exclusive && !isNewUser) {
      showInfo('This exclusive offer is only available for new users within 48 hours of registration');
      return;
    }
    setSelectedProduct(product);
    setShowModal(true);
  };

  const renderGuide = () => (
    <div className="space-y-6">
      <div className="bg-[#181a20] rounded-xl p-8 border border-[#2b3139]">
        <h3 className="text-2xl font-bold mb-6">Easy Earn Guide & Terms</h3>

        <div className="space-y-6">
          <section>
            <h4 className="text-xl font-bold mb-3 text-[#fcd535]">What is Easy Earn?</h4>
            <p className="text-gray-300 leading-relaxed mb-4">
              Easy Earn is a simple and secure way to grow your crypto holdings by staking your assets.
              Earn competitive Annual Percentage Rate (APR) returns on your deposited cryptocurrencies with both
              flexible and fixed-term options designed to fit your investment strategy.
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="bg-[#0b0e11] rounded-lg p-4 border border-[#2b3139]">
                <div className="flex items-start gap-3">
                  <Clock className="w-6 h-6 text-blue-400 flex-shrink-0 mt-1" />
                  <div>
                    <h5 className="font-bold mb-2">Flexible Staking</h5>
                    <p className="text-sm text-gray-400">
                      Earn rewards with no lock-up period. Withdraw your funds anytime without penalty.
                      Perfect for users who value liquidity and want immediate access to their assets.
                    </p>
                  </div>
                </div>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 border border-[#2b3139]">
                <div className="flex items-start gap-3">
                  <Shield className="w-6 h-6 text-green-400 flex-shrink-0 mt-1" />
                  <div>
                    <h5 className="font-bold mb-2">Fixed-Term Staking</h5>
                    <p className="text-sm text-gray-400">
                      Lock your assets for a predetermined period (e.g., 30, 60, 90 days) to earn higher APR rates.
                      Best for users who can commit to longer holding periods for maximum returns.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-[#fcd535]">How Rewards Work</h4>
            <p className="text-gray-300 leading-relaxed mb-4">
              Rewards are calculated and distributed automatically based on the APR of your selected product:
            </p>
            <div className="space-y-3">
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-[#2b3139]">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-bold">Daily Calculation</div>
                  <div className="text-sm text-gray-400">APR ÷ 365</div>
                </div>
                <p className="text-sm text-gray-400">
                  Your daily rewards = (Staked Amount × APR ÷ 365). For example, 1000 USDT at 100% APR earns approximately 2.74 USDT per day.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-[#2b3139]">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-bold">Automatic Compounding</div>
                  <div className="text-sm text-gray-400">Reinvested Daily</div>
                </div>
                <p className="text-sm text-gray-400">
                  Rewards accumulate in your staking balance and can be viewed in real-time. For flexible products, rewards compound automatically.
                </p>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-[#2b3139]">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-bold">Withdrawal Process</div>
                  <div className="text-sm text-gray-400">Instant to Wallet</div>
                </div>
                <p className="text-sm text-gray-400">
                  When you withdraw, both your principal and earned rewards are returned to your main wallet instantly.
                  For fixed-term products, early withdrawal may reduce rewards.
                </p>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-[#fcd535]">Product Types & Terms</h4>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-[#2b3139]">
                    <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">Type</th>
                    <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">Lock Period</th>
                    <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">Withdrawal</th>
                    <th className="text-left py-3 px-4 text-sm font-semibold text-gray-400">APR Range</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-b border-[#2b3139]">
                    <td className="py-3 px-4">
                      <div className="font-bold">Flexible</div>
                    </td>
                    <td className="py-3 px-4 text-gray-300">No lock-up</td>
                    <td className="py-3 px-4 text-green-400">Anytime</td>
                    <td className="py-3 px-4 text-gray-300">Lower APR</td>
                  </tr>
                  <tr className="border-b border-[#2b3139]">
                    <td className="py-3 px-4">
                      <div className="font-bold">Fixed (2-7 Days)</div>
                    </td>
                    <td className="py-3 px-4 text-gray-300">2-7 Days</td>
                    <td className="py-3 px-4 text-yellow-400">After maturity</td>
                    <td className="py-3 px-4 text-gray-300">Medium APR</td>
                  </tr>
                  <tr className="border-b border-[#2b3139]">
                    <td className="py-3 px-4">
                      <div className="font-bold">Fixed (30+ Days)</div>
                    </td>
                    <td className="py-3 px-4 text-gray-300">30-90 Days</td>
                    <td className="py-3 px-4 text-yellow-400">After maturity</td>
                    <td className="py-3 px-4 text-gray-300">Higher APR</td>
                  </tr>
                  <tr className="border-b border-[#2b3139]">
                    <td className="py-3 px-4">
                      <div className="font-bold">New User Exclusive</div>
                    </td>
                    <td className="py-3 px-4 text-gray-300">Varies</td>
                    <td className="py-3 px-4 text-green-400">Flexible options</td>
                    <td className="py-3 px-4 text-green-400">Premium APR</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-[#fcd535]">New User Exclusive Offers</h4>
            <div className="bg-gradient-to-br from-[#f6465d]/10 to-[#0b0e11] border border-[#f6465d]/30 rounded-lg p-6">
              <div className="flex items-start gap-4 mb-4">
                <Award className="w-8 h-8 text-[#f6465d] flex-shrink-0" />
                <div>
                  <h5 className="font-bold text-lg mb-2">48-Hour Welcome Bonus</h5>
                  <p className="text-gray-300 mb-3">
                    New users get access to exclusive high-APR products for the first 48 hours after registration.
                    These limited-time offers provide significantly higher returns than standard products.
                  </p>
                </div>
              </div>
              <ul className="space-y-2 text-gray-300">
                <li className="flex items-start gap-2">
                  <CheckCircle className="w-5 h-5 text-[#f6465d] mt-0.5 flex-shrink-0" />
                  <span>Available only within 48 hours of account creation</span>
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle className="w-5 h-5 text-[#f6465d] mt-0.5 flex-shrink-0" />
                  <span>Can participate in one New User Exclusive product at a time</span>
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle className="w-5 h-5 text-[#f6465d] mt-0.5 flex-shrink-0" />
                  <span>Higher APR rates (up to 555%)</span>
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle className="w-5 h-5 text-[#f6465d] mt-0.5 flex-shrink-0" />
                  <span>Limited investment caps to ensure fair distribution</span>
                </li>
              </ul>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-[#fcd535]">Important Information</h4>
            <div className="space-y-3">
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-[#2b3139]">
                <div className="flex items-start gap-3">
                  <Info className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="font-bold mb-1">Minimum Investment</div>
                    <p className="text-sm text-gray-400">
                      Each product has a minimum investment requirement. Check the product details before investing.
                      Typical minimums range from 1 to 100 units of the respective cryptocurrency.
                    </p>
                  </div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-[#2b3139]">
                <div className="flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="font-bold mb-1">Early Withdrawal (Fixed Terms)</div>
                    <p className="text-sm text-gray-400">
                      Withdrawing before the fixed term expires may result in reduced rewards. You will always receive
                      your principal back, but the APR earned may be adjusted based on the actual holding period.
                    </p>
                  </div>
                </div>
              </div>
              <div className="p-4 bg-[#0b0e11] rounded-lg border border-[#2b3139]">
                <div className="flex items-start gap-3">
                  <Shield className="w-5 h-5 text-green-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="font-bold mb-1">Security & Insurance</div>
                    <p className="text-sm text-gray-400">
                      Your staked assets are secured with industry-leading security measures. All funds are held in
                      secure wallets with multi-signature protection and insurance coverage.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-[#0ecb81]">Getting Started</h4>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-[#2b3139]">
                <div className="w-12 h-12 rounded-full bg-[#fcd535]/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-[#fcd535]">1</span>
                </div>
                <div className="font-bold mb-2">Choose Product</div>
                <p className="text-sm text-gray-400">Select a staking product that matches your goals</p>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-[#2b3139]">
                <div className="w-12 h-12 rounded-full bg-[#fcd535]/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-[#fcd535]">2</span>
                </div>
                <div className="font-bold mb-2">Deposit Funds</div>
                <p className="text-sm text-gray-400">Enter the amount you want to stake</p>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-[#2b3139]">
                <div className="w-12 h-12 rounded-full bg-[#fcd535]/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-[#fcd535]">3</span>
                </div>
                <div className="font-bold mb-2">Earn Rewards</div>
                <p className="text-sm text-gray-400">Watch your balance grow daily</p>
              </div>
              <div className="bg-[#0b0e11] rounded-lg p-4 text-center border border-[#2b3139]">
                <div className="w-12 h-12 rounded-full bg-[#fcd535]/20 flex items-center justify-center mx-auto mb-3">
                  <span className="text-2xl font-bold text-[#fcd535]">4</span>
                </div>
                <div className="font-bold mb-2">Withdraw</div>
                <p className="text-sm text-gray-400">Claim your principal and rewards anytime</p>
              </div>
            </div>
          </section>

          <section>
            <h4 className="text-xl font-bold mb-3 text-red-400">Risk Disclosure</h4>
            <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-6">
              <ul className="space-y-2 text-gray-300">
                <li className="flex items-start gap-2">
                  <AlertCircle className="w-5 h-5 text-red-400 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Market Risk:</strong> Cryptocurrency values can fluctuate. While your staked amount remains constant in crypto terms,
                    its fiat value may change due to market volatility.
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <AlertCircle className="w-5 h-5 text-red-400 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Smart Contract Risk:</strong> Staking involves smart contracts. While audited and tested, no system is completely
                    risk-free. Always invest responsibly.
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <AlertCircle className="w-5 h-5 text-red-400 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Not Investment Advice:</strong> The information provided is for educational purposes only. APR rates are indicative
                    and may vary. Always do your own research before investing.
                  </span>
                </li>
              </ul>
            </div>
          </section>
        </div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-4 sm:px-6 py-4 sm:py-8">
        <div className="flex items-center gap-2 text-xs sm:text-sm text-[#848e9c] mb-4">
          <span>Shark Trades Earn</span>
          <span>{'>'}</span>
          <span className="text-white">Easy Earn</span>
        </div>

        <div className="bg-gradient-to-br from-[#181a20] to-[#1e2329] rounded-lg p-4 sm:p-6 lg:p-8 mb-6 sm:mb-8">
          <div className="flex flex-col lg:flex-row items-start gap-6 mb-6 lg:mb-8">
            <div className="flex-1 w-full">
              <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold mb-2 sm:mb-3">Easy Earn</h1>
              <p className="text-[#848e9c] text-sm sm:text-base">
                Your one-stop investment hub with a range of products. Enjoy greater flexibility and higher returns.
              </p>

              <div className="flex flex-col sm:flex-row sm:items-center gap-4 sm:gap-8 lg:gap-12 mt-6 sm:mt-8">
                <div>
                  <div className="text-[#848e9c] text-xs mb-1 flex items-center gap-1">
                    Total Earn Asset
                    <Info className="w-3 h-3" />
                  </div>
                  <div className="text-xl sm:text-2xl font-semibold">
                    {totalEarnAsset.toFixed(2)} <span className="text-sm sm:text-base text-[#848e9c]">USD</span>
                  </div>
                </div>

                <div>
                  <div className="text-[#848e9c] text-xs mb-1">Yesterday's Yield</div>
                  <div className="text-xl sm:text-2xl font-semibold text-[#0ecb81]">
                    {yesterdayYield.toFixed(6)} <span className="text-sm sm:text-base text-[#848e9c]">USD</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-[#fcd535]/20 to-[#f0b90b]/10 border border-[#fcd535]/30 rounded-lg p-4 sm:p-6 w-full lg:min-w-[350px] lg:max-w-[350px]">
              <h3 className="text-[#fcd535] text-base sm:text-lg font-semibold mb-2">Hold USDTb and Earn</h3>
              <div className="text-2xl sm:text-3xl font-bold mb-2 sm:mb-3">3.85% APR</div>
              <p className="text-[#848e9c] text-xs sm:text-sm">Trade USDTb on Spot with 0 fees</p>
            </div>
          </div>
        </div>

        {isNewUser && newUserProducts.length > 0 && (
          <div className="mb-6 sm:mb-8">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4 sm:mb-6">
              <h2 className="text-xl sm:text-2xl font-semibold">New User Exclusives - 48 Hours Only!</h2>
              <div className="bg-[#f6465d]/20 border border-[#f6465d]/30 rounded px-3 py-1 text-xs text-[#f6465d] font-medium w-fit">
                Limited Time Offer
              </div>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              {newUserProducts.map((product) => (
                <div key={product.id} className="bg-gradient-to-br from-[#f6465d]/10 to-[#181a20] rounded-lg overflow-hidden hover:from-[#f6465d]/20 transition-all border border-[#f6465d]/30">
                  {product.badge && (
                    <div className="bg-gradient-to-r from-[#f6465d] to-[#ff6b35] text-white text-xs font-medium px-3 py-1">
                      {product.badge}
                    </div>
                  )}

                  <div className="p-4">
                    <div className="flex items-center gap-3 mb-4">
                      <CryptoIcon symbol={product.coin} size={40} />
                      <div>
                        <div className="font-semibold text-lg">{product.coin}</div>
                        <div className="flex items-center gap-2 text-xs text-[#848e9c]">
                          <Clock className="w-3 h-3" />
                          {product.product_type === 'flexible' ? 'Flexible' : `${product.duration_days} Days`}
                        </div>
                      </div>
                    </div>

                    <div className="mb-4">
                      <div className="text-[#848e9c] text-xs mb-1">APR</div>
                      <div className="text-[#f6465d] text-2xl font-bold">{product.apr}%</div>
                    </div>

                    <div className="mb-4 bg-[#0b0e11]/50 rounded p-2">
                      <div className="text-xs text-[#848e9c] mb-1">Investment Range</div>
                      <div className="text-white text-sm font-medium">
                        ${product.min_amount} - ${product.max_amount || 300} USD
                      </div>
                    </div>

                    <button
                      onClick={() => openInvestModal(product)}
                      className="w-full bg-gradient-to-r from-[#f6465d] to-[#ff6b35] hover:from-[#ff6b35] hover:to-[#f6465d] text-white py-2.5 rounded font-medium transition-all"
                    >
                      Invest Now
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {regularFeaturedProducts.length > 0 && (
          <div className="mb-6 sm:mb-8">
            <h2 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6">Featured</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              {regularFeaturedProducts.map((product) => (
                <div key={product.id} className="bg-[#181a20] rounded-lg overflow-hidden hover:bg-[#1e2329] transition-all border border-[#2b3139] hover:border-[#fcd535]/30">
                  {product.badge && (
                    <div className="bg-[#fcd535] text-[#0b0e11] text-xs font-medium px-3 py-1">
                      {product.badge}
                    </div>
                  )}

                  <div className="p-4">
                    <div className="flex items-center gap-3 mb-4">
                      <CryptoIcon symbol={product.coin} size={40} />
                      <div>
                        <div className="font-semibold text-lg">{product.coin}</div>
                        <div className="flex items-center gap-2 text-xs text-[#848e9c]">
                          <Clock className="w-3 h-3" />
                          {product.product_type === 'flexible' ? 'Flexible' : `${product.duration_days} Days`}
                        </div>
                      </div>
                    </div>

                    <div className="mb-4">
                      <div className="text-[#848e9c] text-xs mb-1">APR</div>
                      <div className="text-[#0ecb81] text-2xl font-bold">{product.apr}%</div>
                    </div>

                    <div className="mb-4">
                      <div className="flex items-center justify-between text-xs text-[#848e9c] mb-1">
                        <span>Invested</span>
                        <span>{((product.invested_amount / product.total_cap) * 100).toFixed(1)}%</span>
                      </div>
                      <div className="w-full bg-[#2b3139] rounded-full h-1.5">
                        <div
                          className="bg-[#fcd535] h-1.5 rounded-full"
                          style={{ width: `${Math.min((product.invested_amount / product.total_cap) * 100, 100)}%` }}
                        />
                      </div>
                    </div>

                    <button
                      onClick={() => openInvestModal(product)}
                      className="w-full bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] py-2.5 rounded font-medium transition-all"
                    >
                      Invest Now
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex gap-2 mb-6 sm:mb-8 overflow-x-auto pb-2">
          <button
            onClick={() => setMainTab('products')}
            className={`flex items-center gap-2 px-6 py-3 rounded-lg transition-all whitespace-nowrap ${
              mainTab === 'products'
                ? 'bg-[#fcd535] text-[#0b0e11] font-semibold'
                : 'bg-[#181a20] text-gray-400 hover:bg-[#1e2329] hover:text-white border border-[#2b3139]'
            }`}
          >
            <TrendingUp className="w-5 h-5" />
            Products
          </button>
          <button
            onClick={() => setMainTab('guide')}
            className={`flex items-center gap-2 px-6 py-3 rounded-lg transition-all whitespace-nowrap ${
              mainTab === 'guide'
                ? 'bg-[#fcd535] text-[#0b0e11] font-semibold'
                : 'bg-[#181a20] text-gray-400 hover:bg-[#1e2329] hover:text-white border border-[#2b3139]'
            }`}
          >
            <BookOpen className="w-5 h-5" />
            How It Works
          </button>
        </div>

        {mainTab === 'guide' ? (
          renderGuide()
        ) : (
          <>
            {userStakes.length > 0 && (
              <div className="mb-6 sm:mb-8 bg-[#181a20] rounded-lg p-4 sm:p-6">
                <h2 className="text-xl sm:text-2xl font-semibold mb-4 sm:mb-6">My Active Stakes</h2>
                <div className="space-y-4">
                  {userStakes.map((stake) => (
                    <div key={stake.id} className="bg-[#0b0e11] rounded-lg p-4 flex flex-col sm:flex-row sm:items-center gap-4 sm:justify-between">
                      <div className="flex items-center gap-4">
                        <CryptoIcon symbol={stake.coin || 'USDT'} size={40} />
                        <div>
                          <div className="font-semibold text-lg">{stake.coin}</div>
                          <div className="text-xs text-[#848e9c]">
                            {stake.product_type === 'flexible' ? 'Flexible' : `${stake.duration_days} Days Fixed`}
                          </div>
                        </div>
                      </div>
                      <div className="flex flex-col sm:flex-row sm:items-center gap-4 flex-1">
                        <div className="flex-1">
                          <div className="text-sm text-[#848e9c]">Staked Amount</div>
                          <div className="font-semibold">{parseFloat(stake.amount).toFixed(6)} {stake.coin}</div>
                        </div>
                        <div className="flex-1">
                          <div className="text-sm text-[#848e9c]">APR</div>
                          <div className="font-semibold text-[#0ecb81]">{stake.apr_locked}%</div>
                        </div>
                        <div className="flex-1">
                          <div className="text-sm text-[#848e9c]">Earned Rewards</div>
                          <div className="font-semibold text-[#0ecb81]">{parseFloat(stake.earned_rewards).toFixed(6)} {stake.coin}</div>
                        </div>
                      </div>
                      <button
                        onClick={() => handleWithdraw(stake)}
                        className="bg-[#2b3139] hover:bg-[#3b4149] text-white px-6 py-2 rounded text-sm font-medium transition-all w-full sm:w-auto"
                      >
                        Withdraw
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="bg-[#181a20] rounded-lg p-4 sm:p-6">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
                <h2 className="text-xl sm:text-2xl font-semibold">All Products</h2>

                <div className="relative w-full sm:w-auto">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-[#848e9c]" />
                  <input
                    type="text"
                    placeholder="Search Coin"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="bg-[#2b3139] border-0 rounded px-10 py-2 text-sm text-white placeholder-[#848e9c] w-full sm:w-64 outline-none focus:ring-1 focus:ring-[#fcd535]"
                  />
                </div>
              </div>

              <div className="flex items-center gap-4 border-b border-[#2b3139] mb-6">
                {(['all', 'flexible', 'fixed'] as const).map((tab) => (
                  <button
                    key={tab}
                    onClick={() => setActiveTab(tab)}
                    className={`pb-3 px-4 text-sm font-medium transition-colors relative ${
                      activeTab === tab ? 'text-white' : 'text-[#848e9c] hover:text-white'
                    }`}
                  >
                    {tab === 'all' ? 'All' : tab === 'flexible' ? 'Flexible Term' : 'Fixed Term'}
                    {activeTab === tab && (
                      <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#fcd535]"></div>
                    )}
                  </button>
                ))}
              </div>

              {loading ? (
                <div className="flex items-center justify-center py-20">
                  <div className="animate-spin w-12 h-12 border-4 border-[#fcd535] border-t-transparent rounded-full"></div>
                </div>
              ) : filteredProducts.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-20">
                  <div className="text-gray-400 text-lg mb-2">No products found</div>
                  <div className="text-gray-500 text-sm">Try adjusting your search or filters</div>
                </div>
              ) : (
                <>
                  <div className="hidden md:block overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-[#2b3139]">
                          <th className="text-left text-[#848e9c] text-xs font-medium pb-3 px-4">Coin</th>
                          <th className="text-left text-[#848e9c] text-xs font-medium pb-3 px-4">Duration</th>
                          <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-4">APR</th>
                          <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-4">Min Amount</th>
                          <th className="text-right text-[#848e9c] text-xs font-medium pb-3 px-4">Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        {paginatedProducts.map((product) => (
                          <tr key={product.id} className="border-b border-[#2b3139] hover:bg-[#1e2329]/50 transition-colors">
                            <td className="py-4 px-4">
                              <div className="flex items-center gap-3">
                                <CryptoIcon symbol={product.coin} size={32} />
                                <div>
                                  <div className="font-medium">{product.coin}</div>
                                  {product.is_new_user_exclusive && (
                                    <span className="text-xs text-[#f6465d]">New User Exclusive</span>
                                  )}
                                </div>
                              </div>
                            </td>
                            <td className="py-4 px-4 text-[#848e9c] text-sm">
                              {product.product_type === 'flexible' ? 'Flexible' : `${product.duration_days} Days`}
                            </td>
                            <td className="py-4 px-4 text-right">
                              <div className="text-[#0ecb81] font-semibold">{product.apr}%</div>
                            </td>
                            <td className="py-4 px-4 text-right text-sm text-[#848e9c]">
                              {product.min_amount} {product.coin}
                            </td>
                            <td className="py-4 px-4 text-right">
                              <button
                                onClick={() => openInvestModal(product)}
                                disabled={product.is_new_user_exclusive && !isNewUser}
                                className={`px-6 py-2 rounded text-sm font-medium transition-all ${
                                  product.is_new_user_exclusive && !isNewUser
                                    ? 'bg-[#2b3139] text-[#848e9c] cursor-not-allowed'
                                    : 'bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11]'
                                }`}
                              >
                                {product.is_new_user_exclusive && !isNewUser ? 'Not Eligible' : 'Invest Now'}
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  <div className="md:hidden space-y-3">
                    {paginatedProducts.map((product) => (
                      <div key={product.id} className="bg-[#0b0e11] rounded-lg p-4 border border-[#2b3139]">
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-3">
                            <CryptoIcon symbol={product.coin} size={32} />
                            <div>
                              <div className="font-medium text-base">{product.coin}</div>
                              <div className="text-xs text-[#848e9c]">
                                {product.product_type === 'flexible' ? 'Flexible' : `${product.duration_days} Days`}
                              </div>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="text-[#0ecb81] text-xl font-bold">{product.apr}%</div>
                            <div className="text-xs text-[#848e9c]">APR</div>
                          </div>
                        </div>

                        {product.is_new_user_exclusive && (
                          <div className="text-xs text-[#f6465d] mb-2">New User Exclusive</div>
                        )}

                        <div className="flex items-center justify-between mb-3 text-sm">
                          <span className="text-[#848e9c]">Min Amount</span>
                          <span className="text-white">{product.min_amount} {product.coin}</span>
                        </div>

                        <button
                          onClick={() => openInvestModal(product)}
                          disabled={product.is_new_user_exclusive && !isNewUser}
                          className={`w-full py-2.5 rounded text-sm font-medium transition-all ${
                            product.is_new_user_exclusive && !isNewUser
                              ? 'bg-[#2b3139] text-[#848e9c] cursor-not-allowed'
                              : 'bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11]'
                          }`}
                        >
                          {product.is_new_user_exclusive && !isNewUser ? 'Not Eligible' : 'Invest Now'}
                        </button>
                      </div>
                    ))}
                  </div>

                  {totalPages > 1 && (
                    <div className="mt-6 flex flex-col sm:flex-row items-center justify-between gap-4 pt-6 border-t border-[#2b3139]">
                      <div className="text-sm text-[#848e9c]">
                        Showing {startIndex + 1} to {Math.min(endIndex, filteredProducts.length)} of {filteredProducts.length} products
                      </div>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                          disabled={currentPage === 1}
                          className="p-2 rounded-lg bg-[#2b3139] hover:bg-[#3b4149] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                        >
                          <ChevronLeft className="w-5 h-5" />
                        </button>
                        <div className="flex items-center gap-1">
                          {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => {
                            if (
                              page === 1 ||
                              page === totalPages ||
                              (page >= currentPage - 1 && page <= currentPage + 1)
                            ) {
                              return (
                                <button
                                  key={page}
                                  onClick={() => setCurrentPage(page)}
                                  className={`w-10 h-10 rounded-lg font-medium transition-all ${
                                    currentPage === page
                                      ? 'bg-[#fcd535] text-[#0b0e11]'
                                      : 'bg-[#2b3139] text-white hover:bg-[#3b4149]'
                                  }`}
                                >
                                  {page}
                                </button>
                              );
                            } else if (
                              page === currentPage - 2 ||
                              page === currentPage + 2
                            ) {
                              return (
                                <span key={page} className="text-[#848e9c] px-2">
                                  ...
                                </span>
                              );
                            }
                            return null;
                          })}
                        </div>
                        <button
                          onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                          disabled={currentPage === totalPages}
                          className="p-2 rounded-lg bg-[#2b3139] hover:bg-[#3b4149] disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                        >
                          <ChevronRight className="w-5 h-5" />
                        </button>
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>

            <div className="mt-6 sm:mt-8 bg-gradient-to-br from-[#181a20] to-[#1e2329] rounded-lg p-4 sm:p-6">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-[#fcd535]/10 rounded-lg flex items-center justify-center flex-shrink-0">
                    <TrendingUp className="w-6 h-6 text-[#fcd535]" />
                  </div>
                  <div>
                    <h3 className="font-semibold mb-2">High Returns</h3>
                    <p className="text-sm text-[#848e9c]">Earn competitive APR on your crypto holdings with both flexible and fixed-term options</p>
                  </div>
                </div>

                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-[#0ecb81]/10 rounded-lg flex items-center justify-center flex-shrink-0">
                    <Shield className="w-6 h-6 text-[#0ecb81]" />
                  </div>
                  <div>
                    <h3 className="font-semibold mb-2">Secure & Safe</h3>
                    <p className="text-sm text-[#848e9c]">Your assets are protected with industry-leading security measures and insurance coverage</p>
                  </div>
                </div>

                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-[#3b4149]/10 rounded-lg flex items-center justify-center flex-shrink-0">
                    <Clock className="w-6 h-6 text-[#3b4149]" />
                  </div>
                  <div>
                    <h3 className="font-semibold mb-2">Flexible Terms</h3>
                    <p className="text-sm text-[#848e9c]">Choose between flexible savings for instant access or fixed terms for higher returns</p>
                  </div>
                </div>
              </div>
            </div>
          </>
        )}
      </div>

      {showModal && selectedProduct && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#181a20] rounded-2xl p-6 max-w-md w-full border border-gray-800">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">Invest in {selectedProduct.coin}</h3>
              <button
                onClick={() => {
                  setShowModal(false);
                  setInvestAmount('');
                }}
                className="text-gray-400 hover:text-white transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="space-y-4 mb-6">
              <div className="bg-[#0b0e11] rounded-xl p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-gray-400 text-sm">APR</span>
                  <span className={`text-xl font-bold ${selectedProduct.is_new_user_exclusive ? 'text-[#f6465d]' : 'text-[#0ecb81]'}`}>
                    {selectedProduct.apr}%
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-gray-400 text-sm">Duration</span>
                  <span className="text-white font-semibold">
                    {selectedProduct.product_type === 'flexible' ? 'Flexible' : `${selectedProduct.duration_days} Days`}
                  </span>
                </div>
              </div>

              {(() => {
                const balance = walletBalances.find(w => w.currency === selectedProduct.coin);
                const availableBalance = balance ? balance.balance : 0;
                const hasBalance = availableBalance > 0;
                const amount = parseFloat(investAmount);
                const insufficientBalance = investAmount && !isNaN(amount) && amount > availableBalance;

                return (
                  <>
                    <div className={`bg-[#0b0e11] rounded-xl p-3 border ${
                      !hasBalance ? 'border-[#f6465d]/30' : 'border-gray-700'
                    }`}>
                      <div className="flex items-center justify-between">
                        <span className="text-gray-400 text-sm">Available Balance</span>
                        <span className={`font-semibold ${!hasBalance ? 'text-[#f6465d]' : 'text-white'}`}>
                          {availableBalance.toFixed(8)} {selectedProduct.coin}
                        </span>
                      </div>
                      {!hasBalance && (
                        <p className="text-[#f6465d] text-xs mt-2">
                          You don't have any {selectedProduct.coin} in your wallet. Please deposit first.
                        </p>
                      )}
                    </div>

                    <div>
                      <label className="text-gray-400 text-sm mb-2 block">Investment Amount</label>
                      <div className="relative">
                        <input
                          type="number"
                          value={investAmount}
                          onChange={(e) => setInvestAmount(e.target.value)}
                          placeholder={`Min: ${selectedProduct.min_amount}${selectedProduct.max_amount ? ` - Max: ${selectedProduct.max_amount}` : ''}`}
                          className={`w-full bg-[#0b0e11] border rounded-xl px-4 py-3 text-white outline-none focus:border-[#fcd535] transition-colors ${
                            insufficientBalance ? 'border-[#f6465d]' : 'border-gray-700'
                          }`}
                          disabled={!hasBalance}
                        />
                        <span className="absolute right-4 top-1/2 transform -translate-y-1/2 text-gray-400">
                          {selectedProduct.coin}
                        </span>
                      </div>
                      <div className="flex items-center justify-between mt-1">
                        <p className="text-xs text-gray-500">
                          Range: {selectedProduct.min_amount} - {selectedProduct.max_amount || 'Unlimited'} {selectedProduct.coin}
                        </p>
                        {hasBalance && (
                          <button
                            type="button"
                            onClick={() => setInvestAmount(availableBalance.toString())}
                            className="text-xs text-[#fcd535] hover:text-[#f0b90b] transition-colors"
                          >
                            Max
                          </button>
                        )}
                      </div>
                      {insufficientBalance && (
                        <p className="text-[#f6465d] text-xs mt-2">
                          Insufficient balance. You have {availableBalance.toFixed(8)} {selectedProduct.coin} available.
                        </p>
                      )}
                    </div>
                  </>
                );
              })()}

              {investAmount && parseFloat(investAmount) > 0 && (
                <div className={`${selectedProduct.is_new_user_exclusive ? 'bg-[#f6465d]/10 border-[#f6465d]/30' : 'bg-[#0ecb81]/10 border-[#0ecb81]/30'} border rounded-xl p-4`}>
                  <div className="text-sm text-gray-400 mb-1">Estimated Daily Earnings</div>
                  <div className={`text-lg font-bold ${selectedProduct.is_new_user_exclusive ? 'text-[#f6465d]' : 'text-[#0ecb81]'}`}>
                    {((parseFloat(investAmount) * parseFloat(selectedProduct.apr) / 100) / 365).toFixed(6)} {selectedProduct.coin}
                  </div>
                  {selectedProduct.product_type === 'fixed' && (
                    <div className="text-sm text-gray-400 mt-2">
                      Total at maturity: {(parseFloat(investAmount) * (1 + parseFloat(selectedProduct.apr) / 100 * selectedProduct.duration_days / 365)).toFixed(6)} {selectedProduct.coin}
                    </div>
                  )}
                </div>
              )}
            </div>

            <button
              onClick={handleInvest}
              disabled={(() => {
                const balance = walletBalances.find(w => w.currency === selectedProduct.coin);
                const availableBalance = balance ? balance.balance : 0;
                const amount = parseFloat(investAmount);
                return investLoading ||
                       !investAmount ||
                       isNaN(amount) ||
                       amount <= 0 ||
                       amount < selectedProduct.min_amount ||
                       amount > availableBalance ||
                       availableBalance === 0;
              })()}
              className="w-full bg-[#fcd535] hover:bg-[#f0b90b] disabled:bg-gray-700 disabled:cursor-not-allowed text-[#0b0e11] disabled:text-gray-500 font-bold py-3 rounded-xl transition-all"
            >
              {investLoading ? 'Processing...' : 'Confirm Investment'}
            </button>
          </div>
        </div>
      )}

      <div className="fixed top-20 right-4 z-50 space-y-2">
        {toasts.map((toast) => (
          <Toast
            key={toast.id}
            message={toast.message}
            type={toast.type}
            onClose={() => removeToast(toast.id)}
          />
        ))}
      </div>
    </div>
  );
}

export default Earn;

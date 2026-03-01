import { useState, useEffect } from 'react';
import { Users, Copy, Share2, ArrowRight, TrendingUp, DollarSign, Award, Gift, Check, Calculator } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';

export default function ReferFriendsBonus() {
  const { user, userProfile } = useAuth();
  const { showToast } = useToast();
  const [referralCode, setReferralCode] = useState('');
  const [referralStats, setReferralStats] = useState({
    total_referrals: 0,
    qualified_referrals: 0,
    total_earnings: 0,
    commission_rate: 10
  });
  const [calculatorReferrals, setCalculatorReferrals] = useState(5);
  const [calculatorVolume, setCalculatorVolume] = useState(10000);

  useEffect(() => {
    if (user) {
      loadReferralData();
    }
  }, [user]);

  const loadReferralData = async () => {
    try {
      const { data: profileData } = await supabase
        .from('user_profiles')
        .select('referral_code')
        .eq('user_id', user!.id)
        .single();

      if (profileData?.referral_code) {
        setReferralCode(profileData.referral_code);
      }

      const { data: statsData } = await supabase
        .from('referral_stats')
        .select('*')
        .eq('user_id', user!.id)
        .single();

      if (statsData) {
        setReferralStats({
          total_referrals: statsData.total_referrals || 0,
          qualified_referrals: statsData.qualified_referrals || 0,
          total_earnings: parseFloat(statsData.total_commission_earned || 0),
          commission_rate: statsData.current_tier_rate || 10
        });
      }
    } catch (error) {
      console.error('Error loading referral data:', error);
    }
  };

  const copyReferralCode = () => {
    navigator.clipboard.writeText(referralCode);
    showToast('Referral code copied!', 'success');
  };

  const copyReferralLink = () => {
    const link = `${window.location.origin}/signup?ref=${referralCode}`;
    navigator.clipboard.writeText(link);
    showToast('Referral link copied!', 'success');
  };

  const shareToSocial = (platform: string) => {
    const link = `${window.location.origin}/signup?ref=${referralCode}`;
    const text = `Join me on Shark Trades and get $20 bonus! Use my referral code: ${referralCode}`;

    const urls: Record<string, string> = {
      whatsapp: `https://wa.me/?text=${encodeURIComponent(text + ' ' + link)}`,
      telegram: `https://t.me/share/url?url=${encodeURIComponent(link)}&text=${encodeURIComponent(text)}`,
      twitter: `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(link)}`,
      facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(link)}`
    };

    window.open(urls[platform], '_blank');
  };

  const calculateEarnings = () => {
    const bonusPerReferral = 20;
    const commissionRate = referralStats.commission_rate / 100;
    const avgVolumePerReferral = calculatorVolume;
    const tradingFeeRate = 0.001;

    const bonusEarnings = calculatorReferrals * bonusPerReferral;
    const commissionEarnings = calculatorReferrals * avgVolumePerReferral * tradingFeeRate * commissionRate;
    const totalEarnings = bonusEarnings + commissionEarnings;

    return {
      bonus: bonusEarnings,
      commission: commissionEarnings,
      total: totalEarnings
    };
  };

  const earnings = calculateEarnings();

  const vipTiers = [
    { name: 'Beginner', volume: 0, rate: 10, rebate: 5 },
    { name: 'Intermediate', volume: 100000, rate: 20, rebate: 7 },
    { name: 'Advanced', volume: 500000, rate: 30, rebate: 10 },
    { name: 'VIP 1', volume: 2000000, rate: 50, rebate: 12 },
    { name: 'VIP 2', volume: 10000000, rate: 60, rebate: 13 },
    { name: 'Diamond', volume: 50000000, rate: 70, rebate: 15 }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 bg-blue-500/10 border border-blue-500/20 rounded-full px-4 py-2 mb-6">
            <Users className="w-4 h-4 text-blue-400" />
            <span className="text-blue-400 text-sm font-semibold">UNLIMITED EARNING POTENTIAL</span>
          </div>

          <h1 className="text-5xl md:text-6xl font-bold text-white mb-6">
            Refer Friends & Earn<br />Up to <span className="text-blue-400">70% Commission</span>
          </h1>

          <p className="text-xl text-gray-300 max-w-3xl mx-auto mb-8">
            Get $20 USDT for each qualified referral plus earn lifetime commissions on their trading fees.
            The more you refer, the higher your commission rate!
          </p>

          {!user ? (
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="/signup"
                className="inline-flex items-center justify-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Start Referring Now
                <ArrowRight className="w-5 h-5" />
              </a>
              <a
                href="/signin"
                className="inline-flex items-center justify-center gap-2 bg-gray-700 hover:bg-gray-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Sign In
              </a>
            </div>
          ) : (
            <a
              href="/referral"
              className="inline-flex items-center justify-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
            >
              Go to Referral Dashboard
              <ArrowRight className="w-5 h-5" />
            </a>
          )}
        </div>

        <div className="grid md:grid-cols-4 gap-6 mb-16">
          <div className="bg-gradient-to-br from-green-500/10 to-green-600/10 border border-green-500/20 rounded-xl p-6 text-center">
            <DollarSign className="w-10 h-10 text-green-400 mx-auto mb-3" />
            <div className="text-3xl font-bold text-green-400 mb-1">$20</div>
            <p className="text-gray-300">Per Qualified Referral</p>
          </div>

          <div className="bg-gradient-to-br from-blue-500/10 to-blue-600/10 border border-blue-500/20 rounded-xl p-6 text-center">
            <TrendingUp className="w-10 h-10 text-blue-400 mx-auto mb-3" />
            <div className="text-3xl font-bold text-blue-400 mb-1">Up to 70%</div>
            <p className="text-gray-300">Lifetime Commission</p>
          </div>

          <div className="bg-gradient-to-br from-purple-500/10 to-purple-600/10 border border-purple-500/20 rounded-xl p-6 text-center">
            <Users className="w-10 h-10 text-purple-400 mx-auto mb-3" />
            <div className="text-3xl font-bold text-purple-400 mb-1">Unlimited</div>
            <p className="text-gray-300">Number of Referrals</p>
          </div>

          <div className="bg-gradient-to-br from-yellow-500/10 to-yellow-600/10 border border-yellow-500/20 rounded-xl p-6 text-center">
            <Award className="w-10 h-10 text-yellow-400 mx-auto mb-3" />
            <div className="text-3xl font-bold text-yellow-400 mb-1">6 Tiers</div>
            <p className="text-gray-300">VIP Reward Levels</p>
          </div>
        </div>

        {user && referralCode && (
          <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8 mb-16">
            <h2 className="text-2xl font-bold text-white mb-6 text-center">Your Referral Tools</h2>

            <div className="grid md:grid-cols-2 gap-6 mb-6">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">Your Referral Code</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={referralCode}
                    readOnly
                    className="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-3 text-white font-mono"
                  />
                  <button
                    onClick={copyReferralCode}
                    className="bg-blue-500 hover:bg-blue-600 text-white px-6 rounded-lg transition-colors flex items-center gap-2"
                  >
                    <Copy className="w-4 h-4" />
                    Copy
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">Your Referral Link</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={`${window.location.origin}/signup?ref=${referralCode}`}
                    readOnly
                    className="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-3 text-white text-sm"
                  />
                  <button
                    onClick={copyReferralLink}
                    className="bg-blue-500 hover:bg-blue-600 text-white px-6 rounded-lg transition-colors flex items-center gap-2"
                  >
                    <Copy className="w-4 h-4" />
                    Copy
                  </button>
                </div>
              </div>
            </div>

            <div className="flex flex-wrap gap-3 justify-center">
              <button
                onClick={() => shareToSocial('whatsapp')}
                className="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg transition-colors flex items-center gap-2"
              >
                <Share2 className="w-4 h-4" />
                WhatsApp
              </button>
              <button
                onClick={() => shareToSocial('telegram')}
                className="bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg transition-colors flex items-center gap-2"
              >
                <Share2 className="w-4 h-4" />
                Telegram
              </button>
              <button
                onClick={() => shareToSocial('twitter')}
                className="bg-sky-500 hover:bg-sky-600 text-white px-6 py-3 rounded-lg transition-colors flex items-center gap-2"
              >
                <Share2 className="w-4 h-4" />
                Twitter
              </button>
              <button
                onClick={() => shareToSocial('facebook')}
                className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-colors flex items-center gap-2"
              >
                <Share2 className="w-4 h-4" />
                Facebook
              </button>
            </div>

            <div className="grid md:grid-cols-4 gap-4 mt-8 pt-8 border-t border-gray-700">
              <div className="text-center">
                <div className="text-3xl font-bold text-white mb-1">{referralStats.total_referrals}</div>
                <div className="text-sm text-gray-400">Total Referrals</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-green-400 mb-1">{referralStats.qualified_referrals}</div>
                <div className="text-sm text-gray-400">Qualified</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-blue-400 mb-1">${referralStats.total_earnings.toFixed(2)}</div>
                <div className="text-sm text-gray-400">Total Earned</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-purple-400 mb-1">{referralStats.commission_rate}%</div>
                <div className="text-sm text-gray-400">Commission Rate</div>
              </div>
            </div>
          </div>
        )}

        <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">How the Referral Program Works</h2>

          <div className="grid md:grid-cols-3 gap-8 mb-8">
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-2xl mx-auto mb-4">
                1
              </div>
              <h3 className="text-xl font-semibold text-white mb-2">Share Your Link</h3>
              <p className="text-gray-400">Share your unique referral link with friends via social media, email, or messenger.</p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-2xl mx-auto mb-4">
                2
              </div>
              <h3 className="text-xl font-semibold text-white mb-2">They Sign Up & Trade</h3>
              <p className="text-gray-400">Your friends create an account, complete KYC, and make their first deposit of $100+.</p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-2xl mx-auto mb-4">
                3
              </div>
              <h3 className="text-xl font-semibold text-white mb-2">Earn Forever</h3>
              <p className="text-gray-400">Get $20 instantly plus earn lifetime commissions on all their trading fees.</p>
            </div>
          </div>

          <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-3">Qualification Requirements:</h3>
            <div className="grid md:grid-cols-2 gap-4">
              <div className="flex items-start gap-3">
                <Check className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <span className="text-gray-300">Friend signs up using your referral link</span>
              </div>
              <div className="flex items-start gap-3">
                <Check className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <span className="text-gray-300">Completes KYC verification</span>
              </div>
              <div className="flex items-start gap-3">
                <Check className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <span className="text-gray-300">Makes first deposit of $100 or more</span>
              </div>
              <div className="flex items-start gap-3">
                <Check className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <span className="text-gray-300">$20 bonus credited to your account</span>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <div className="flex items-center gap-3 mb-8">
            <Calculator className="w-8 h-8 text-blue-400" />
            <h2 className="text-3xl font-bold text-white">Earnings Calculator</h2>
          </div>

          <div className="grid md:grid-cols-2 gap-8">
            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Number of Referrals
                </label>
                <input
                  type="range"
                  min="1"
                  max="100"
                  value={calculatorReferrals}
                  onChange={(e) => setCalculatorReferrals(parseInt(e.target.value))}
                  className="w-full"
                />
                <div className="text-center text-2xl font-bold text-white mt-2">{calculatorReferrals}</div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Avg. Monthly Volume per Referral
                </label>
                <input
                  type="range"
                  min="1000"
                  max="100000"
                  step="1000"
                  value={calculatorVolume}
                  onChange={(e) => setCalculatorVolume(parseInt(e.target.value))}
                  className="w-full"
                />
                <div className="text-center text-2xl font-bold text-white mt-2">${calculatorVolume.toLocaleString()}</div>
              </div>

              <div className="bg-gray-900/50 border border-gray-700 rounded-lg p-4">
                <div className="text-sm text-gray-400 mb-1">Your Current Commission Rate</div>
                <div className="text-2xl font-bold text-blue-400">{referralStats.commission_rate}%</div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-blue-500/10 to-purple-500/10 border border-blue-500/20 rounded-xl p-8">
              <h3 className="text-xl font-bold text-white mb-6 text-center">Estimated Monthly Earnings</h3>

              <div className="space-y-4">
                <div className="flex justify-between items-center pb-3 border-b border-gray-700">
                  <span className="text-gray-400">Referral Bonuses</span>
                  <span className="text-xl font-bold text-green-400">${earnings.bonus.toFixed(2)}</span>
                </div>

                <div className="flex justify-between items-center pb-3 border-b border-gray-700">
                  <span className="text-gray-400">Trading Commissions</span>
                  <span className="text-xl font-bold text-blue-400">${earnings.commission.toFixed(2)}</span>
                </div>

                <div className="flex justify-between items-center pt-3 bg-gradient-to-r from-blue-500/20 to-purple-500/20 -mx-4 px-4 py-4 rounded-lg">
                  <span className="text-white font-bold text-lg">Total Monthly Income</span>
                  <span className="text-3xl font-bold text-blue-400">${earnings.total.toFixed(2)}</span>
                </div>

                <div className="text-center pt-4">
                  <div className="text-sm text-gray-400 mb-1">Yearly Potential</div>
                  <div className="text-2xl font-bold text-purple-400">${(earnings.total * 12).toFixed(2)}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">VIP Commission Tiers</h2>

          <p className="text-center text-gray-400 mb-8">
            Increase your referral network's trading volume to unlock higher commission rates
          </p>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-700">
                  <th className="text-left py-4 px-4 text-gray-400 font-medium">Tier</th>
                  <th className="text-left py-4 px-4 text-gray-400 font-medium">Required Volume</th>
                  <th className="text-left py-4 px-4 text-gray-400 font-medium">Commission Rate</th>
                  <th className="text-left py-4 px-4 text-gray-400 font-medium">Fee Rebate</th>
                </tr>
              </thead>
              <tbody>
                {vipTiers.map((tier, index) => (
                  <tr key={index} className="border-b border-gray-800 hover:bg-gray-800/50 transition-colors">
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-2">
                        <Award className="w-5 h-5 text-blue-400" />
                        <span className="font-semibold text-white">{tier.name}</span>
                      </div>
                    </td>
                    <td className="py-4 px-4 text-gray-300">${tier.volume.toLocaleString()}</td>
                    <td className="py-4 px-4">
                      <span className="text-blue-400 font-bold">{tier.rate}%</span>
                    </td>
                    <td className="py-4 px-4">
                      <span className="text-green-400 font-bold">{tier.rebate}%</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">Referral Milestone Rewards</h2>

          <div className="grid md:grid-cols-3 gap-6">
            <div className="bg-gradient-to-br from-green-500/10 to-green-600/10 border border-green-500/20 rounded-xl p-6 text-center">
              <Gift className="w-12 h-12 text-green-400 mx-auto mb-4" />
              <div className="text-4xl font-bold text-green-400 mb-2">$5</div>
              <div className="text-lg font-semibold text-white mb-2">First Referral</div>
              <p className="text-sm text-gray-400">Bonus for your first qualified referral</p>
            </div>

            <div className="bg-gradient-to-br from-blue-500/10 to-blue-600/10 border border-blue-500/20 rounded-xl p-6 text-center">
              <Gift className="w-12 h-12 text-blue-400 mx-auto mb-4" />
              <div className="text-4xl font-bold text-blue-400 mb-2">$25</div>
              <div className="text-lg font-semibold text-white mb-2">5 Referrals</div>
              <p className="text-sm text-gray-400">Extra bonus when you hit 5 referrals</p>
            </div>

            <div className="bg-gradient-to-br from-purple-500/10 to-purple-600/10 border border-purple-500/20 rounded-xl p-6 text-center">
              <Gift className="w-12 h-12 text-purple-400 mx-auto mb-4" />
              <div className="text-4xl font-bold text-purple-400 mb-2">$70</div>
              <div className="text-lg font-semibold text-white mb-2">10 Referrals</div>
              <p className="text-sm text-gray-400">Big reward for reaching 10 referrals</p>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">Frequently Asked Questions</h2>

          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <h3 className="text-lg font-semibold text-white mb-2">How do I get my $20 per referral?</h3>
              <p className="text-gray-400">You earn $20 when your referred friend completes KYC verification and makes a deposit of $100 or more.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">How do lifetime commissions work?</h3>
              <p className="text-gray-400">You earn a percentage of the trading fees generated by your referrals forever, as long as they trade on the platform.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">Is there a limit to how many people I can refer?</h3>
              <p className="text-gray-400">No! You can refer unlimited people and earn on all their trading activity.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">How do I increase my commission rate?</h3>
              <p className="text-gray-400">Your commission rate increases automatically as your referral network's total trading volume grows.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">When do I receive my commissions?</h3>
              <p className="text-gray-400">Commissions are credited to your account in real-time as your referrals trade.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">Can I withdraw my referral earnings?</h3>
              <p className="text-gray-400">Yes! All referral bonuses and commissions can be withdrawn at any time with no restrictions.</p>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-r from-blue-500/10 to-purple-500/10 border border-blue-500/20 rounded-2xl p-8 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">Start Earning Today</h2>
          <p className="text-xl text-gray-300 mb-8">
            Join thousands of traders earning passive income through our referral program
          </p>

          <div className="flex items-center justify-center gap-6 mb-8">
            <div className="text-center">
              <div className="text-3xl font-bold text-blue-400">$2.4M+</div>
              <div className="text-sm text-gray-400">Paid to Affiliates</div>
            </div>
            <div className="w-px h-12 bg-gray-700" />
            <div className="text-center">
              <div className="text-3xl font-bold text-blue-400">18,500+</div>
              <div className="text-sm text-gray-400">Active Referrers</div>
            </div>
            <div className="w-px h-12 bg-gray-700" />
            <div className="text-center">
              <div className="text-3xl font-bold text-blue-400">$850</div>
              <div className="text-sm text-gray-400">Avg. Monthly Earning</div>
            </div>
          </div>

          {!user ? (
            <a
              href="/signup"
              className="inline-flex items-center justify-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
            >
              Get Your Referral Link Now
              <ArrowRight className="w-5 h-5" />
            </a>
          ) : (
            <a
              href="/referral"
              className="inline-flex items-center justify-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
            >
              View Referral Dashboard
              <ArrowRight className="w-5 h-5" />
            </a>
          )}
        </div>
      </div>
    </div>
  );
}

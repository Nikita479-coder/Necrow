import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Users, Copy, Share2, CheckCircle, Link as LinkIcon, Award, ArrowRight, Zap } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

function Referral() {
  const { user, profile, refreshProfile } = useAuth();
  const [referralCode, setReferralCode] = useState('');
  const [copiedCode, setCopiedCode] = useState(false);
  const [copiedLink, setCopiedLink] = useState(false);
  const [userEarned, setUserEarned] = useState(0);
  const [totalReferrals, setTotalReferrals] = useState(0);
  const [currentVIP, setCurrentVIP] = useState(1);
  const [currentVolume, setCurrentVolume] = useState(0);
  const [monthlyEarnings, setMonthlyEarnings] = useState(0);
  const [referredUsers, setReferredUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeProgram, setActiveProgram] = useState<'referral' | 'affiliate'>('referral');
  const [switching, setSwitching] = useState(false);

  const vipLevels = [
    { level: 1, name: 'Beginner', commission: 10, rebate: 5, perks: 'Entry level - start earning instantly', icon: '🥉' },
    { level: 2, name: 'Intermediate', commission: 20, rebate: 6, perks: 'Higher commission for moderate traders', icon: '🥈' },
    { level: 3, name: 'Advanced', commission: 30, rebate: 7, perks: 'Balanced reward for consistent traders', icon: '🥇' },
    { level: 4, name: 'VIP 1', commission: 40, rebate: 8, perks: 'Advanced traders enjoy boosted rates', icon: '💫' },
    { level: 5, name: 'VIP 2', commission: 50, rebate: 10, perks: 'Top-tier - maximum commissions & exclusive perks', icon: '👑' },
    { level: 6, name: 'Diamond', commission: 70, rebate: 15, perks: 'Diamond Elite - highest rewards, priority support, VIP events', icon: '💎' }
  ];

  useEffect(() => {
    if (user && profile) {
      loadUserStats();
    }
  }, [user, profile]);

  const loadUserStats = async () => {
    if (!user || !profile) return;

    try {
      setReferralCode(profile.referral_code || '');
      setActiveProgram(profile.active_program || 'referral');

      const { data, error } = await supabase
        .from('referral_stats')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        console.error('Error loading stats:', error);
        return;
      }

      if (data) {
        setCurrentVIP(data.vip_level || 1);
        setCurrentVolume(parseFloat(data.total_volume_30d || '0'));
        setTotalReferrals(data.total_referrals || 0);
        setUserEarned(parseFloat(data.total_earnings || '0'));
        setMonthlyEarnings(parseFloat(data.this_month_earnings || '0'));
      } else {
        setCurrentVIP(1);
        setCurrentVolume(0);
        setTotalReferrals(0);
        setUserEarned(0);
        setMonthlyEarnings(0);
      }

      const { data: refData } = await supabase.rpc('get_referred_users', {
        p_referrer_id: user.id
      });

      if (refData) {
        setReferredUsers(refData);
      }
    } catch (error) {
      console.error('Error loading referral data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSwitchProgram = async (program: 'referral' | 'affiliate') => {
    if (!user || program === activeProgram) return;

    setActiveProgram(program);
    setSwitching(true);
    try {
      const { data, error } = await supabase.rpc('switch_active_program', {
        p_user_id: user.id,
        p_program: program
      });

      if (error) throw error;

      if (data?.success) {
        await refreshProfile();
        if (program === 'affiliate') {
          window.location.href = '/affiliate';
        }
      }
    } catch (error) {
      console.error('Error switching program:', error);
      setActiveProgram(activeProgram === 'referral' ? 'affiliate' : 'referral');
    } finally {
      setSwitching(false);
    }
  };

  const copyToClipboard = (text: string, type: 'code' | 'link') => {
    navigator.clipboard.writeText(text);
    if (type === 'code') {
      setCopiedCode(true);
      setTimeout(() => setCopiedCode(false), 2000);
    } else {
      setCopiedLink(true);
      setTimeout(() => setCopiedLink(false), 2000);
    }
  };

  const referralLink = `https://shark-trades.com/signup?ref=${referralCode}`;

  return (
    <div className="min-h-screen bg-[#181a20] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 py-6">
        <div className="bg-gradient-to-r from-[#2b3139] to-[#1e2329] rounded-xl p-6 mb-8 border border-[#3d4450]">
          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
            <div>
              <h1 className="text-2xl font-bold text-white mb-2">Referral Program</h1>
              <p className="text-[#848e9c] text-sm">Earn commissions by inviting friends to trade</p>
            </div>
          </div>
        </div>

        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-8">
            <button className="pb-2 text-base text-white font-medium transition-colors relative">
              Referral Program
              <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
            </button>
          </div>

          <div className="flex items-center gap-2 text-sm">
            <Users className="w-4 h-4 text-[#848e9c]" />
            <span className="text-[#848e9c]">Total Earned:</span>
            <span className="text-[#fcd535] font-semibold">${userEarned.toFixed(2)} USDT</span>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-8">
          <div className="lg:col-span-2 bg-[#2b3139] rounded-lg p-6">
            <div className="flex items-start justify-between mb-6">
              <div>
                <h2 className="text-xl font-medium text-white mb-2">Your VIP Status</h2>
                <p className="text-[#848e9c] text-sm">Increase trading volume to unlock higher rewards</p>
              </div>
              <div className="bg-[#181a20] px-4 py-2 rounded flex items-center gap-2">
                <span className="text-2xl">{vipLevels[currentVIP - 1].icon}</span>
                <span className="text-[#fcd535] font-semibold">VIP {currentVIP}</span>
              </div>
            </div>

            <div className="mb-6">
              <div className="flex items-center justify-between mb-2 text-sm">
                <span className="text-[#848e9c]">30-Day Trading Volume</span>
                <span className="text-[#eaecef] font-medium">
                  ${currentVolume.toLocaleString()}
                </span>
              </div>
              <div className="text-xs text-[#848e9c] mt-1">
                Trade more to unlock higher VIP tiers and better rewards
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="bg-[#181a20] rounded-lg p-4">
                <div className="text-[#848e9c] text-xs mb-2">Your Commission Rate</div>
                <div className="text-2xl font-semibold text-[#0ecb81] mb-1">{vipLevels[currentVIP - 1].commission}%</div>
                <div className="text-[#848e9c] text-xs">On referral trading fees</div>
              </div>
              <div className="bg-[#181a20] rounded-lg p-4">
                <div className="text-[#848e9c] text-xs mb-2">Referral Gets</div>
                <div className="text-2xl font-semibold text-[#fcd535] mb-1">{vipLevels[currentVIP - 1].rebate}%</div>
                <div className="text-[#848e9c] text-xs">Fee rebate (30 days)</div>
              </div>
            </div>
          </div>

          <div className="bg-[#2b3139] rounded-lg p-6">
            <h3 className="text-base font-medium text-white mb-4 flex items-center gap-2">
              <Award className="w-5 h-5 text-[#fcd535]" />
              Quick Stats
            </h3>
            <div className="space-y-3">
              <div className="bg-[#181a20] rounded p-3">
                <div className="text-[#848e9c] text-xs mb-1">Total Earnings</div>
                <div className="text-xl font-semibold text-[#fcd535]">${userEarned.toFixed(2)}</div>
              </div>
              <div className="bg-[#181a20] rounded p-3">
                <div className="text-[#848e9c] text-xs mb-1">Active Referrals</div>
                <div className="text-xl font-semibold text-[#eaecef]">{totalReferrals}</div>
              </div>
              <div className="bg-[#181a20] rounded p-3">
                <div className="text-[#848e9c] text-xs mb-1">This Month</div>
                <div className="text-xl font-semibold text-[#eaecef]">${monthlyEarnings.toFixed(2)}</div>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-[#2b3139] rounded-lg p-6 mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-medium text-white">VIP Levels</h2>
            <a href="/vip" className="text-sm text-[#fcd535] hover:text-[#f0b90b] transition-colors">
              View Requirements & Full Details
            </a>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-[#181a20]">
                  <th className="text-left text-[#848e9c] text-xs font-medium pb-3">Level</th>
                  <th className="text-right text-[#848e9c] text-xs font-medium pb-3">Commission</th>
                  <th className="text-right text-[#848e9c] text-xs font-medium pb-3">Rebate</th>
                  <th className="text-left text-[#848e9c] text-xs font-medium pb-3 pl-4">Benefits</th>
                </tr>
              </thead>
              <tbody>
                {vipLevels.map((level) => (
                  <tr
                    key={level.level}
                    className={`border-b border-[#181a20] transition-colors ${
                      currentVIP === level.level ? 'bg-[#fcd535]/5' : 'hover:bg-[#181a20]/50'
                    }`}
                  >
                    <td className="py-4">
                      <div className="flex items-center gap-2">
                        <span className="text-2xl">{level.icon}</span>
                        <div>
                          <div className="text-[#eaecef] text-sm font-medium">{level.name}</div>
                          {currentVIP === level.level && (
                            <span className="text-[#fcd535] text-[10px] font-medium">Current</span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="py-4 text-right">
                      <div className="text-[#0ecb81] font-semibold text-base">{level.commission}%</div>
                    </td>
                    <td className="py-4 text-right">
                      <div className="text-[#fcd535] font-semibold text-base">{level.rebate}%</div>
                    </td>
                    <td className="py-4 pl-4">
                      <div className="text-[#848e9c] text-xs max-w-xs">{level.perks}</div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-8">
          <div className="bg-[#2b3139] rounded-lg p-6">
            <h3 className="text-base font-medium text-white mb-4">Referral Code & Link</h3>

            <div className="space-y-3">
              <div className="bg-[#181a20] rounded-lg p-4">
                <div className="text-[#848e9c] text-[10px] mb-2 uppercase tracking-wide">Referral Code</div>
                <div className="flex items-center justify-between">
                  <span className="text-lg font-mono font-semibold text-white tracking-wider">{referralCode}</span>
                  <button
                    onClick={() => copyToClipboard(referralCode, 'code')}
                    className="bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] px-4 py-1.5 rounded text-sm font-medium transition-all flex items-center gap-2"
                  >
                    {copiedCode ? <CheckCircle className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                    {copiedCode ? 'Copied' : 'Copy'}
                  </button>
                </div>
              </div>

              <div className="bg-[#181a20] rounded-lg p-4">
                <div className="text-[#848e9c] text-[10px] mb-2 uppercase tracking-wide">Referral Link</div>
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={referralLink}
                    readOnly
                    className="flex-1 bg-[#2b3139] border-0 text-white px-3 py-2 rounded font-mono text-xs outline-none"
                  />
                  <button
                    onClick={() => copyToClipboard(referralLink, 'link')}
                    className="bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] px-4 py-2 rounded text-sm font-medium transition-all flex items-center gap-2 whitespace-nowrap"
                  >
                    {copiedLink ? <CheckCircle className="w-4 h-4" /> : <LinkIcon className="w-4 h-4" />}
                    {copiedLink ? 'Copied' : 'Copy'}
                  </button>
                </div>
              </div>

              <button className="w-full bg-[#181a20] hover:bg-[#1e2329] text-[#eaecef] font-medium py-2.5 rounded transition-all flex items-center justify-center gap-2">
                <Share2 className="w-4 h-4" />
                Share Link
              </button>
            </div>
          </div>

          <div className="bg-[#2b3139] rounded-lg p-6">
            <h3 className="text-base font-medium text-white mb-4">How It Works</h3>

            <div className="space-y-4">
              <div className="flex items-start gap-3">
                <div className="w-8 h-8 rounded-full bg-[#fcd535] flex items-center justify-center text-[#0b0e11] font-bold text-sm flex-shrink-0">
                  1
                </div>
                <div>
                  <h4 className="text-sm font-medium text-[#eaecef] mb-1">Share Your Link</h4>
                  <p className="text-xs text-[#848e9c]">Send your referral code to friends via social media or messaging</p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className="w-8 h-8 rounded-full bg-[#fcd535] flex items-center justify-center text-[#0b0e11] font-bold text-sm flex-shrink-0">
                  2
                </div>
                <div>
                  <h4 className="text-sm font-medium text-[#eaecef] mb-1">Friend Signs Up</h4>
                  <p className="text-xs text-[#848e9c]">They register and complete verification using your link</p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className="w-8 h-8 rounded-full bg-[#fcd535] flex items-center justify-center text-[#0b0e11] font-bold text-sm flex-shrink-0">
                  3
                </div>
                <div>
                  <h4 className="text-sm font-medium text-[#eaecef] mb-1">Both Earn Rewards</h4>
                  <p className="text-xs text-[#848e9c]">You earn commission, they get fee rebates when they trade</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {referredUsers.length > 0 && (
          <div className="bg-[#2b3139] rounded-lg p-6 mb-8">
            <h2 className="text-xl font-medium text-white mb-4">Your Referrals ({referredUsers.length})</h2>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-[#181a20]">
                    <th className="text-left text-[#848e9c] text-xs font-medium pb-3">User</th>
                    <th className="text-left text-[#848e9c] text-xs font-medium pb-3">Email</th>
                    <th className="text-right text-[#848e9c] text-xs font-medium pb-3">Total Trades</th>
                    <th className="text-right text-[#848e9c] text-xs font-medium pb-3">Total Volume</th>
                    <th className="text-left text-[#848e9c] text-xs font-medium pb-3">Joined Date</th>
                  </tr>
                </thead>
                <tbody>
                  {referredUsers.map((refUser) => (
                    <tr key={refUser.user_id} className="border-b border-[#181a20] hover:bg-[#181a20]/50">
                      <td className="py-3">
                        <div className="text-[#eaecef] text-sm">{refUser.username}</div>
                      </td>
                      <td className="py-3">
                        <div className="text-[#848e9c] text-sm font-mono">
                          {refUser.masked_email}
                        </div>
                      </td>
                      <td className="py-3 text-right">
                        <div className="text-[#eaecef] text-sm">{refUser.total_trades}</div>
                      </td>
                      <td className="py-3 text-right">
                        <div className="text-[#eaecef] text-sm">
                          ${parseFloat(refUser.total_volume).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </div>
                      </td>
                      <td className="py-3">
                        <div className="text-[#848e9c] text-sm">
                          {new Date(refUser.joined_date).toLocaleDateString('en-US', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric'
                          })}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        <div className="bg-[#2b3139] rounded-lg p-6">
          <h2 className="text-xl font-medium text-white mb-4">Commission Example</h2>

          <div className="bg-[#181a20] rounded-lg p-5 mb-4">
            <p className="text-[#eaecef] text-sm mb-4">
              If your referral trades <span className="text-white font-semibold">$10,000</span>, and the trading fee is <span className="text-white font-semibold">0.1%</span> = <span className="text-white font-semibold">$10</span> in fees:
            </p>

            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
              {vipLevels.map((level) => {
                const tradingFee = 10;
                const yourEarnings = (tradingFee * level.commission) / 100;
                const friendRebate = (tradingFee * level.rebate) / 100;

                return (
                  <div
                    key={level.level}
                    className={`bg-[#2b3139] border rounded-lg p-3 ${
                      currentVIP === level.level ? 'border-[#fcd535]' : 'border-[#181a20]'
                    }`}
                  >
                    <div className="text-[#848e9c] text-[10px] mb-2">{level.name} {level.icon}</div>
                    <div className="mb-2">
                      <div className="text-[#0ecb81] font-semibold text-base">${yourEarnings.toFixed(2)}</div>
                      <div className="text-[#848e9c] text-[10px]">You earn</div>
                    </div>
                    <div>
                      <div className="text-[#fcd535] font-medium text-sm">${friendRebate.toFixed(2)}</div>
                      <div className="text-[#848e9c] text-[10px]">Friend gets</div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="bg-[#0ecb81]/10 border border-[#0ecb81]/20 rounded-lg p-4">
            <div className="flex items-start gap-3">
              <div className="text-2xl">💡</div>
              <div className="text-sm text-[#eaecef]">
                <p className="font-medium mb-2">How Dual Rewards Work:</p>
                <ul className="space-y-1 text-xs text-[#848e9c]">
                  <li>- You earn commission on every trade your referrals make</li>
                  <li>- Your friends get a fee rebate for their first 30 days</li>
                  <li>- Higher VIP levels = more earnings for both parties</li>
                  <li>- All rewards are paid in USDT automatically</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Referral;

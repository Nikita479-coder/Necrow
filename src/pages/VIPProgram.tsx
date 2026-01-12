import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { Crown, TrendingUp, Gift, Shield, Users, Zap, Star, ArrowRight, CheckCircle, UserCheck, Medal, Award, Trophy, Gem } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface VIPLevel {
  level_number: number;
  level_name: string;
  level_emoji: string;
  min_volume_30d: number;
  max_volume_30d: number | null;
  commission_rate: number;
  rebate_rate: number;
  benefits: string;
  weekly_refill_amount: number;
}

function VIPProgram() {
  const { user } = useAuth();
  const [vipLevels, setVipLevels] = useState<VIPLevel[]>([]);
  const [currentLevel, setCurrentLevel] = useState(1);
  const [currentVolume, setCurrentVolume] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadVIPLevels();
    if (user) {
      loadUserVIPStatus();
    }
  }, [user]);

  const loadVIPLevels = async () => {
    try {
      const { data, error } = await supabase
        .from('vip_levels')
        .select('*')
        .order('level_number', { ascending: true });

      if (error) throw error;
      if (data) {
        setVipLevels(data);
      }
    } catch (error) {
      console.error('Error loading VIP levels:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadUserVIPStatus = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('user_vip_status')
        .select('current_level, volume_30d')
        .eq('user_id', user.id)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        console.error('Error loading VIP status:', error);
        return;
      }

      if (data) {
        setCurrentLevel(data.current_level || 1);
        setCurrentVolume(parseFloat(data.volume_30d || '0'));
      }
    } catch (error) {
      console.error('Error loading VIP status:', error);
    }
  };

  const formatVolume = (volume: number) => {
    if (volume >= 1000000) {
      return `$${(volume / 1000000).toFixed(1)}M`;
    }
    return `$${volume.toLocaleString()}`;
  };

  const getPerksArray = (benefits: string, level: number) => {
    const basePerks = [benefits];

    if (level === 2) {
      basePerks.push('Priority support - Intermediate');
    }
    if (level === 3) {
      basePerks.push('Priority support - Advanced');
      basePerks.push('Reduced trading fees');
    }
    if (level === 4) {
      basePerks.push('Dedicated VIP manager');
      basePerks.push('Exclusive market insights');
      basePerks.push('Advanced trading tools');
    }
    if (level === 5) {
      basePerks.push('Dedicated VIP manager');
      basePerks.push('Personal account manager');
      basePerks.push('Early access to new features');
    }
    if (level === 6) {
      basePerks.push('VIP events & networking');
      basePerks.push('Highest priority support');
      basePerks.push('Custom withdrawal limits');
    }

    return basePerks;
  };

  const nextLevel = vipLevels.find(level => level.level_number === currentLevel + 1);
  const volumeToNext = nextLevel ? nextLevel.min_volume_30d - currentVolume : 0;
  const progressPercent = nextLevel
    ? Math.min((currentVolume / nextLevel.min_volume_30d) * 100, 100)
    : 100;

  const getVIPIcon = (levelNumber: number, size: 'sm' | 'md' | 'lg' = 'md') => {
    const sizeClasses = {
      sm: 'w-5 h-5',
      md: 'w-8 h-8',
      lg: 'w-10 h-10'
    };
    const iconSize = sizeClasses[size];

    switch (levelNumber) {
      case 1:
        return (
          <div className={`${size === 'lg' ? 'w-14 h-14' : size === 'md' ? 'w-12 h-12' : 'w-8 h-8'} rounded-xl bg-gradient-to-br from-amber-700 to-amber-900 flex items-center justify-center shadow-lg`}>
            <Medal className={`${iconSize} text-amber-200`} />
          </div>
        );
      case 2:
        return (
          <div className={`${size === 'lg' ? 'w-14 h-14' : size === 'md' ? 'w-12 h-12' : 'w-8 h-8'} rounded-xl bg-gradient-to-br from-slate-400 to-slate-600 flex items-center justify-center shadow-lg`}>
            <Award className={`${iconSize} text-white`} />
          </div>
        );
      case 3:
        return (
          <div className={`${size === 'lg' ? 'w-14 h-14' : size === 'md' ? 'w-12 h-12' : 'w-8 h-8'} rounded-xl bg-gradient-to-br from-yellow-400 to-yellow-600 flex items-center justify-center shadow-lg`}>
            <Trophy className={`${iconSize} text-yellow-900`} />
          </div>
        );
      case 4:
        return (
          <div className={`${size === 'lg' ? 'w-14 h-14' : size === 'md' ? 'w-12 h-12' : 'w-8 h-8'} rounded-xl bg-gradient-to-br from-[#fcd535] to-[#f0b90b] flex items-center justify-center shadow-lg`}>
            <Star className={`${iconSize} text-[#0b0e11] fill-current`} />
          </div>
        );
      case 5:
        return (
          <div className={`${size === 'lg' ? 'w-14 h-14' : size === 'md' ? 'w-12 h-12' : 'w-8 h-8'} rounded-xl bg-gradient-to-br from-[#fcd535] to-[#e6a800] flex items-center justify-center shadow-lg ring-2 ring-[#fcd535]/50`}>
            <Crown className={`${iconSize} text-[#0b0e11]`} />
          </div>
        );
      case 6:
        return (
          <div className={`${size === 'lg' ? 'w-14 h-14' : size === 'md' ? 'w-12 h-12' : 'w-8 h-8'} rounded-xl bg-gradient-to-br from-cyan-400 via-blue-500 to-cyan-300 flex items-center justify-center shadow-lg ring-2 ring-cyan-400/50`}>
            <Gem className={`${iconSize} text-white`} />
          </div>
        );
      default:
        return (
          <div className={`${size === 'lg' ? 'w-14 h-14' : size === 'md' ? 'w-12 h-12' : 'w-8 h-8'} rounded-xl bg-gradient-to-br from-gray-600 to-gray-800 flex items-center justify-center shadow-lg`}>
            <Medal className={`${iconSize} text-gray-300`} />
          </div>
        );
    }
  };

  return (
    <div className="min-h-screen bg-[#181a20] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 py-6">
        {/* Hero Section */}
        <div className="bg-gradient-to-br from-[#2b3139] via-[#2b3139] to-[#fcd535]/10 rounded-2xl p-8 mb-8 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-96 h-96 bg-[#fcd535]/5 rounded-full blur-3xl"></div>
          <div className="relative z-10">
            <div className="flex items-center gap-3 mb-4">
              <Crown className="w-10 h-10 text-[#fcd535]" />
              <h1 className="text-4xl font-bold text-white">VIP Program</h1>
            </div>
            <p className="text-[#848e9c] text-lg mb-6 max-w-3xl">
              Join our exclusive VIP program and unlock premium benefits, fee rebates, and exclusive perks.
              The more you trade, the higher your tier and rewards.
            </p>

            {user && (
              <div className="bg-[#181a20] rounded-lg p-6 max-w-2xl">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <div className="text-[#848e9c] text-sm mb-1">Your Current Status</div>
                    <div className="flex items-center gap-3">
                      {getVIPIcon(currentLevel, 'lg')}
                      <span className="text-2xl font-bold text-[#fcd535]">
                        {vipLevels[currentLevel - 1]?.level_name || 'Beginner'}
                      </span>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-[#848e9c] text-sm mb-1">30-Day Volume</div>
                    <div className="text-2xl font-bold text-white">{formatVolume(currentVolume)}</div>
                  </div>
                </div>

                {nextLevel && (
                  <div>
                    <div className="flex items-center justify-between mb-2 text-sm">
                      <span className="text-[#848e9c]">Progress to {nextLevel.level_name}</span>
                      <span className="text-[#eaecef] font-medium">
                        {formatVolume(volumeToNext)} to go
                      </span>
                    </div>
                    <div className="w-full bg-[#2b3139] rounded-full h-3">
                      <div
                        className="bg-gradient-to-r from-[#fcd535] to-[#f0b90b] h-3 rounded-full transition-all"
                        style={{ width: `${progressPercent}%` }}
                      />
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* VIP Levels Grid */}
        <div className="mb-8">
          <h2 className="text-2xl font-bold text-white mb-6">All VIP Tiers</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {vipLevels.map((level) => {
              const perks = getPerksArray(level.benefits, level.level_number);
              const isCurrentLevel = currentLevel === level.level_number;

              return (
                <div
                  key={level.level_number}
                  className={`bg-[#2b3139] rounded-xl p-6 border-2 transition-all ${
                    isCurrentLevel
                      ? 'border-[#fcd535] shadow-lg shadow-[#fcd535]/20'
                      : 'border-transparent hover:border-[#3e424a]'
                  }`}
                >
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center gap-3">
                      {getVIPIcon(level.level_number)}
                      <div>
                        <h3 className="text-xl font-bold text-white">{level.level_name}</h3>
                        {isCurrentLevel && (
                          <span className="text-xs text-[#fcd535] font-medium">Your Current Tier</span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="mb-4 pb-4 border-b border-[#181a20]">
                    <div className="text-[#848e9c] text-xs mb-1">30-Day Trading Volume</div>
                    <div className="text-lg font-bold text-white">
                      {formatVolume(level.min_volume_30d)}
                      {level.max_volume_30d ? ` - ${formatVolume(level.max_volume_30d)}` : '+'}
                    </div>
                  </div>

                  <div className="mb-4 space-y-3">
                    <div className="bg-[#181a20] rounded-lg p-4">
                      <div className="text-[#848e9c] text-xs mb-1">Fee Rebate</div>
                      <div className="text-2xl font-bold text-[#fcd535]">{level.rebate_rate}%</div>
                    </div>

                    {level.weekly_refill_amount > 0 && (
                      <div className="bg-gradient-to-br from-[#0ecb81]/20 to-[#0ecb81]/5 border border-[#0ecb81]/30 rounded-lg p-4">
                        <div className="flex items-center gap-2 mb-1">
                          <Gift className="w-4 h-4 text-[#0ecb81]" />
                          <div className="text-[#0ecb81] text-xs font-medium">Weekly Shark Card</div>
                        </div>
                        <div className="text-2xl font-bold text-white">
                          ${level.weekly_refill_amount} USDT
                        </div>
                        <div className="text-[#848e9c] text-xs mt-1">Free weekly refill</div>
                      </div>
                    )}
                  </div>

                  <div className="space-y-2">
                    <div className="text-[#848e9c] text-xs font-medium mb-2">PERKS & BENEFITS</div>
                    {perks.map((perk, index) => (
                      <div key={index} className="flex items-start gap-2">
                        <CheckCircle className="w-4 h-4 text-[#0ecb81] mt-0.5 flex-shrink-0" />
                        <span className="text-sm text-[#eaecef]">{perk}</span>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Features Section */}
        <div className="mb-8">
          <h2 className="text-2xl font-bold text-white mb-6">VIP Benefits Overview</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="bg-gradient-to-br from-[#0ecb81]/10 to-[#0ecb81]/5 border border-[#0ecb81]/20 rounded-lg p-6">
              <div className="w-12 h-12 bg-[#0ecb81]/20 rounded-lg flex items-center justify-center mb-4">
                <Gift className="w-6 h-6 text-[#0ecb81]" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Weekly Shark Cards</h3>
              <p className="text-sm text-[#848e9c]">
                VIP 1 and above members receive free weekly USDT refills up to $500
              </p>
            </div>

            <div className="bg-gradient-to-br from-[#fcd535]/10 to-[#fcd535]/5 border border-[#fcd535]/20 rounded-lg p-6">
              <div className="w-12 h-12 bg-[#fcd535]/20 rounded-lg flex items-center justify-center mb-4">
                <TrendingUp className="w-6 h-6 text-[#fcd535]" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Fee Rebates</h3>
              <p className="text-sm text-[#848e9c]">
                Get up to 15% of your trading fees back automatically
              </p>
            </div>

            <div className="bg-gradient-to-br from-[#3861fb]/10 to-[#3861fb]/5 border border-[#3861fb]/20 rounded-lg p-6">
              <div className="w-12 h-12 bg-[#3861fb]/20 rounded-lg flex items-center justify-center mb-4">
                <UserCheck className="w-6 h-6 text-[#3861fb]" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Dedicated VIP Manager</h3>
              <p className="text-sm text-[#848e9c]">
                VIP 1 and VIP 2 members get a dedicated manager for personalized support
              </p>
            </div>

            <div className="bg-gradient-to-br from-[#f6465d]/10 to-[#f6465d]/5 border border-[#f6465d]/20 rounded-lg p-6">
              <div className="w-12 h-12 bg-[#f6465d]/20 rounded-lg flex items-center justify-center mb-4">
                <Shield className="w-6 h-6 text-[#f6465d]" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Priority Support Tiers</h3>
              <p className="text-sm text-[#848e9c]">
                Priority support starting from Intermediate tier, escalating to Advanced priority
              </p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div className="bg-[#2b3139] rounded-lg p-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-[#fcd535]/10 rounded-lg flex items-center justify-center flex-shrink-0">
                <Star className="w-6 h-6 text-[#fcd535]" />
              </div>
              <div>
                <h3 className="text-lg font-bold text-white mb-2">Exclusive VIP Events</h3>
                <p className="text-sm text-[#848e9c]">
                  Access to VIP-only events, webinars, trading competitions, and networking opportunities with top traders
                </p>
              </div>
            </div>
          </div>

          <div className="bg-[#2b3139] rounded-lg p-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-[#3861fb]/10 rounded-lg flex items-center justify-center flex-shrink-0">
                <Zap className="w-6 h-6 text-[#3861fb]" />
              </div>
              <div>
                <h3 className="text-lg font-bold text-white mb-2">Advanced Trading Tools</h3>
                <p className="text-sm text-[#848e9c]">
                  Unlock exclusive market insights, advanced analytics, and early access to new features as you progress
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* How It Works */}
        <div className="bg-[#2b3139] rounded-xl p-8 mb-8">
          <h2 className="text-2xl font-bold text-white mb-6">How to Climb the VIP Ladder</h2>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="relative">
              <div className="absolute top-8 left-8 w-full h-0.5 bg-[#fcd535]/20 hidden md:block"></div>
              <div className="relative bg-[#181a20] rounded-lg p-6">
                <div className="w-12 h-12 bg-[#fcd535] rounded-full flex items-center justify-center text-[#0b0e11] font-bold text-xl mb-4">
                  1
                </div>
                <h3 className="text-lg font-bold text-white mb-2">Start Trading</h3>
                <p className="text-sm text-[#848e9c]">
                  Every trade you make counts toward your 30-day trading volume
                </p>
              </div>
            </div>

            <div className="relative">
              <div className="absolute top-8 left-8 w-full h-0.5 bg-[#fcd535]/20 hidden md:block"></div>
              <div className="relative bg-[#181a20] rounded-lg p-6">
                <div className="w-12 h-12 bg-[#fcd535] rounded-full flex items-center justify-center text-[#0b0e11] font-bold text-xl mb-4">
                  2
                </div>
                <h3 className="text-lg font-bold text-white mb-2">Increase Volume</h3>
                <p className="text-sm text-[#848e9c]">
                  As your trading volume grows, you automatically move up tiers
                </p>
              </div>
            </div>

            <div className="relative">
              <div className="relative bg-[#181a20] rounded-lg p-6">
                <div className="w-12 h-12 bg-[#fcd535] rounded-full flex items-center justify-center text-[#0b0e11] font-bold text-xl mb-4">
                  3
                </div>
                <h3 className="text-lg font-bold text-white mb-2">Unlock Benefits</h3>
                <p className="text-sm text-[#848e9c]">
                  Enjoy higher fee rebates, priority support, and exclusive VIP perks
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* CTA Section */}
        <div className="bg-gradient-to-r from-[#fcd535] to-[#f0b90b] rounded-xl p-8 text-center">
          <h2 className="text-3xl font-bold text-[#0b0e11] mb-3">Ready to Start Your VIP Journey?</h2>
          <p className="text-[#0b0e11]/80 text-lg mb-6 max-w-2xl mx-auto">
            Begin trading today and watch your status grow. Every trade brings you closer to exclusive rewards.
          </p>
          <div className="flex items-center justify-center gap-4">
            <a
              href="/markets"
              className="bg-[#0b0e11] hover:bg-[#1e2329] text-white font-medium px-8 py-3 rounded-lg transition-all flex items-center gap-2"
            >
              Start Trading
              <ArrowRight className="w-5 h-5" />
            </a>
            <a
              href="/referral"
              className="bg-white/20 hover:bg-white/30 text-[#0b0e11] font-medium px-8 py-3 rounded-lg transition-all"
            >
              View Referral Program
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}

export default VIPProgram;

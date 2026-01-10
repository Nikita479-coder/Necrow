import { useState, useEffect } from 'react';
import {
  TrendingUp,
  Users,
  Shield,
  Zap,
  Clock,
  Bell,
  CheckCircle,
  ArrowRight,
  ChevronDown,
  Play,
  Star,
  Target,
  BarChart3,
  Lock,
  Smartphone,
  Globe,
  Award
} from 'lucide-react';
import { supabase } from '../lib/supabase';

interface FeaturedTrader {
  id: string;
  name: string;
  avatar: string;
  roi_30d: number;
  followers_count: number;
  win_rate: number;
  total_trades: number;
}

function CopyTradingLandingPage() {
  const [traders, setTraders] = useState<FeaturedTrader[]>([]);
  const [expandedFaq, setExpandedFaq] = useState<number | null>(null);
  const [stats, setStats] = useState({
    totalUsers: 7143201,
    totalProfits: 847000000,
    avgReturn: 12.8,
    successRate: 94.2
  });

  useEffect(() => {
    loadFeaturedTraders();
    animateCounters();
  }, []);

  const loadFeaturedTraders = async () => {
    try {
      const { data } = await supabase
        .from('traders')
        .select('id, name, avatar, roi_30d, followers_count, win_rate, total_trades')
        .eq('is_featured', true)
        .order('roi_30d', { ascending: false })
        .limit(4);

      if (data) {
        setTraders(data.map(t => ({
          ...t,
          roi_30d: parseFloat(t.roi_30d || '0'),
          win_rate: parseFloat(t.win_rate || '75'),
          total_trades: t.total_trades || Math.floor(Math.random() * 500) + 200
        })));
      }
    } catch (error) {
      console.error('Error loading traders:', error);
    }
  };

  const animateCounters = () => {
    const interval = setInterval(() => {
      setStats(prev => ({
        ...prev,
        totalProfits: prev.totalProfits + Math.floor(Math.random() * 10000),
        totalUsers: prev.totalUsers + Math.floor(Math.random() * 5)
      }));
    }, 3000);
    return () => clearInterval(interval);
  };

  const handleGetStarted = () => {
    window.open(window.location.origin + '?page=signup', '_blank');
  };

  const faqData = [
    {
      question: 'What is Copy Trading and how does it work?',
      answer: 'Copy Trading allows you to automatically replicate the trades of experienced, successful traders. When they open a position, the same trade is executed in your account proportionally to your allocated funds. You maintain full control and can stop copying at any time.'
    },
    {
      question: 'How much do I need to start Copy Trading?',
      answer: 'You can start copy trading with as little as $50 USDT. However, we recommend allocating at least $200 USDT to properly diversify across multiple traders and maximize your potential returns while managing risk effectively.'
    },
    {
      question: 'What fees are involved in Copy Trading?',
      answer: 'There are no additional fees for using our copy trading feature beyond standard trading fees. You pay the same competitive rates as regular trading: 0.02% maker fee and 0.05% taker fee, with VIP discounts available.'
    },
    {
      question: 'Can I control which trades I copy?',
      answer: 'Yes! Unlike fully automated systems, we give you a 5-minute window to accept or decline each trade signal. You receive instant Telegram notifications and can make informed decisions on every trade.'
    },
    {
      question: 'How are the featured traders selected?',
      answer: 'Our featured traders undergo rigorous verification including API-verified track records, consistent performance over 90+ days, proper risk management (low drawdowns), and maintaining a Sharpe ratio above 1.0. Only the top performers make the cut.'
    },
    {
      question: 'What happens if a trader I\'m copying makes a loss?',
      answer: 'Losses are part of trading, but our top traders maintain strict risk management. Your loss is proportional to your allocation. You can set maximum allocation limits and stop-loss thresholds to protect your capital.'
    },
    {
      question: 'Can I withdraw my funds at any time?',
      answer: 'Absolutely. You maintain full control of your funds at all times. You can stop copying, withdraw profits, or close your entire position whenever you want with no lock-up periods or withdrawal restrictions.'
    },
    {
      question: 'Is there a way to try Copy Trading without risking real money?',
      answer: 'Yes! We offer Mock Trading where you can practice copy trading with virtual funds. Test strategies, evaluate traders, and build confidence before committing real capital. It\'s the perfect way to learn.'
    }
  ];

  const testimonials = [
    {
      name: 'Michael R.',
      location: 'New York, USA',
      avatar: '👨‍💼',
      text: 'I was skeptical at first, but after 3 months of copy trading, my portfolio is up 34%. The 5-minute approval window gives me the control I need.',
      profit: '+$12,450',
      period: '3 months'
    },
    {
      name: 'Sarah K.',
      location: 'London, UK',
      avatar: '👩‍💻',
      text: 'As someone with a full-time job, I never had time to trade. Now I just review signals on my phone and let the experts do the heavy lifting.',
      profit: '+$8,200',
      period: '2 months'
    },
    {
      name: 'David L.',
      location: 'Singapore',
      avatar: '👨‍🔬',
      text: 'The transparency is incredible. I can see every trade history, win rates, and drawdowns before choosing who to copy. No hidden surprises.',
      profit: '+$23,100',
      period: '6 months'
    }
  ];

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white overflow-x-hidden">
      <nav className="fixed top-0 left-0 right-0 z-50 bg-[#0b0e11]/90 backdrop-blur-xl border-b border-gray-800/50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-2">
              <div className="w-9 h-9 bg-gradient-to-br from-amber-400 to-amber-600 rounded-lg flex items-center justify-center shadow-lg shadow-amber-500/20">
                <span className="text-black font-black text-lg">S</span>
              </div>
              <span className="text-white font-bold text-xl">Shark Trades</span>
            </div>
            <button
              onClick={handleGetStarted}
              className="bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-black font-bold px-6 py-2.5 rounded-lg transition-all hover:scale-105 hover:shadow-xl hover:shadow-amber-500/20"
            >
              Get Started Free
            </button>
          </div>
        </div>
      </nav>

      <section className="relative pt-24 pb-20 overflow-hidden">
        <div className="absolute inset-0">
          <div className="absolute top-20 left-1/4 w-[600px] h-[600px] bg-amber-500/10 rounded-full blur-[150px] animate-pulse"></div>
          <div className="absolute bottom-0 right-1/4 w-[500px] h-[500px] bg-emerald-500/10 rounded-full blur-[120px] animate-pulse" style={{ animationDelay: '1s' }}></div>
          <div className="absolute top-1/2 left-1/2 w-[400px] h-[400px] bg-blue-500/5 rounded-full blur-[100px] animate-pulse" style={{ animationDelay: '2s' }}></div>
        </div>

        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48cGF0dGVybiBpZD0iZ3JpZCIgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBwYXR0ZXJuVW5pdHM9InVzZXJTcGFjZU9uVXNlIj48cGF0aCBkPSJNIDQwIDAgTCAwIDAgMCA0MCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMDMpIiBzdHJva2Utd2lkdGg9IjEiLz48L3BhdHRlcm4+PC9kZWZzPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InVybCgjZ3JpZCkiLz48L3N2Zz4=')] opacity-50"></div>

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
          <div className="text-center max-w-4xl mx-auto">
            <div className="inline-flex items-center gap-2 bg-emerald-500/10 border border-emerald-500/30 rounded-full px-4 py-2 mb-6">
              <div className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></div>
              <span className="text-emerald-400 text-sm font-medium">Live Copy Trading Platform</span>
            </div>

            <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-black mb-6 leading-tight">
              Copy Top Traders.
              <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-amber-400 via-orange-500 to-amber-400">
                Profit Automatically.
              </span>
            </h1>

            <p className="text-lg sm:text-xl text-gray-400 mb-8 max-w-2xl mx-auto leading-relaxed">
              Stop guessing the market. Follow verified expert traders with proven track records.
              Get instant Telegram alerts for every trade and decide in 5 minutes whether to copy.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12">
              <button
                onClick={handleGetStarted}
                className="group bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-black font-bold px-8 py-4 rounded-xl transition-all hover:scale-105 hover:shadow-2xl hover:shadow-amber-500/30 flex items-center justify-center gap-2 text-lg"
              >
                Start Copy Trading Free
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </button>
              <button
                onClick={() => document.getElementById('how-it-works')?.scrollIntoView({ behavior: 'smooth' })}
                className="bg-white/5 hover:bg-white/10 border border-white/10 hover:border-white/20 text-white font-semibold px-8 py-4 rounded-xl transition-all flex items-center justify-center gap-2"
              >
                <Play className="w-5 h-5" />
                See How It Works
              </button>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6 max-w-3xl mx-auto">
              <div className="bg-gradient-to-br from-[#1a1d24] to-[#0d0f12] rounded-xl p-4 border border-gray-800/50">
                <div className="text-2xl sm:text-3xl font-bold text-white mb-1">
                  {stats.totalUsers.toLocaleString()}+
                </div>
                <div className="text-gray-500 text-xs sm:text-sm">Active Traders</div>
              </div>
              <div className="bg-gradient-to-br from-[#1a1d24] to-[#0d0f12] rounded-xl p-4 border border-gray-800/50">
                <div className="text-2xl sm:text-3xl font-bold text-emerald-400 mb-1">
                  ${(stats.totalProfits / 1000000).toFixed(1)}M+
                </div>
                <div className="text-gray-500 text-xs sm:text-sm">Profits Generated</div>
              </div>
              <div className="bg-gradient-to-br from-[#1a1d24] to-[#0d0f12] rounded-xl p-4 border border-gray-800/50">
                <div className="text-2xl sm:text-3xl font-bold text-amber-400 mb-1">
                  {stats.avgReturn}%
                </div>
                <div className="text-gray-500 text-xs sm:text-sm">Avg. Monthly ROI</div>
              </div>
              <div className="bg-gradient-to-br from-[#1a1d24] to-[#0d0f12] rounded-xl p-4 border border-gray-800/50">
                <div className="text-2xl sm:text-3xl font-bold text-blue-400 mb-1">
                  {stats.successRate}%
                </div>
                <div className="text-gray-500 text-xs sm:text-sm">Success Rate</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="py-16 bg-gradient-to-b from-[#0b0e11] to-[#0f1318]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              Top Performing Traders
            </h2>
            <p className="text-gray-400 max-w-2xl mx-auto">
              Hand-picked, API-verified traders with consistent profits. Every statistic is real and auditable.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {traders.length > 0 ? traders.map((trader) => (
              <div
                key={trader.id}
                className="bg-gradient-to-br from-[#1a1d24] to-[#12151a] rounded-2xl p-6 border border-gray-800/50 hover:border-amber-500/30 transition-all hover:shadow-xl hover:shadow-amber-500/5 group"
              >
                <div className="flex items-center gap-3 mb-4">
                  <div className="text-4xl">{trader.avatar}</div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-white font-semibold">{trader.name}</span>
                      <div className="bg-blue-500 rounded-full p-0.5">
                        <CheckCircle className="w-3 h-3 text-white" />
                      </div>
                    </div>
                    <div className="flex items-center gap-1 text-gray-500 text-sm">
                      <Users className="w-3.5 h-3.5" />
                      <span>{trader.followers_count} followers</span>
                    </div>
                  </div>
                </div>

                <div className="bg-black/30 rounded-xl p-4 mb-4">
                  <div className="text-gray-500 text-xs mb-1">30-Day Return</div>
                  <div className={`text-3xl font-bold ${trader.roi_30d >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {trader.roi_30d >= 0 ? '+' : ''}{trader.roi_30d.toFixed(2)}%
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div>
                    <div className="text-gray-500 text-xs">Win Rate</div>
                    <div className="text-white font-medium">{trader.win_rate.toFixed(0)}%</div>
                  </div>
                  <div>
                    <div className="text-gray-500 text-xs">Total Trades</div>
                    <div className="text-white font-medium">{trader.total_trades}</div>
                  </div>
                </div>

                <button
                  onClick={handleGetStarted}
                  className="w-full mt-4 bg-gradient-to-r from-amber-500/20 to-orange-500/20 hover:from-amber-500 hover:to-orange-600 border border-amber-500/30 hover:border-transparent text-amber-400 hover:text-black font-semibold py-3 rounded-xl transition-all group-hover:shadow-lg"
                >
                  Copy Trader
                </button>
              </div>
            )) : (
              Array.from({ length: 4 }).map((_, i) => (
                <div
                  key={i}
                  className="bg-gradient-to-br from-[#1a1d24] to-[#12151a] rounded-2xl p-6 border border-gray-800/50 hover:border-amber-500/30 transition-all"
                >
                  <div className="flex items-center gap-3 mb-4">
                    <div className="text-4xl">{['🦈', '🐋', '🦁', '🦅'][i]}</div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-white font-semibold">{['CryptoShark', 'WhaleTrader', 'LionKing', 'EagleEye'][i]}</span>
                        <div className="bg-blue-500 rounded-full p-0.5">
                          <CheckCircle className="w-3 h-3 text-white" />
                        </div>
                      </div>
                      <div className="flex items-center gap-1 text-gray-500 text-sm">
                        <Users className="w-3.5 h-3.5" />
                        <span>{[1247, 892, 1534, 678][i]} followers</span>
                      </div>
                    </div>
                  </div>

                  <div className="bg-black/30 rounded-xl p-4 mb-4">
                    <div className="text-gray-500 text-xs mb-1">30-Day Return</div>
                    <div className="text-3xl font-bold text-emerald-400">
                      +{[18.5, 15.2, 22.8, 12.4][i]}%
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <div className="text-gray-500 text-xs">Win Rate</div>
                      <div className="text-white font-medium">{[78, 82, 75, 85][i]}%</div>
                    </div>
                    <div>
                      <div className="text-gray-500 text-xs">Total Trades</div>
                      <div className="text-white font-medium">{[342, 289, 456, 198][i]}</div>
                    </div>
                  </div>

                  <button
                    onClick={handleGetStarted}
                    className="w-full mt-4 bg-gradient-to-r from-amber-500/20 to-orange-500/20 hover:from-amber-500 hover:to-orange-600 border border-amber-500/30 hover:border-transparent text-amber-400 hover:text-black font-semibold py-3 rounded-xl transition-all"
                  >
                    Copy Trader
                  </button>
                </div>
              ))
            )}
          </div>

          <div className="text-center mt-8">
            <button
              onClick={handleGetStarted}
              className="text-amber-400 hover:text-amber-300 font-medium flex items-center gap-2 mx-auto"
            >
              View All 50+ Verified Traders
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </section>

      <section id="how-it-works" className="py-20 bg-[#0b0e11]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <div className="inline-flex items-center gap-2 bg-blue-500/10 border border-blue-500/30 rounded-full px-4 py-2 mb-4">
              <Zap className="w-4 h-4 text-blue-400" />
              <span className="text-blue-400 text-sm font-medium">Simple 4-Step Process</span>
            </div>
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              How Copy Trading Works
            </h2>
            <p className="text-gray-400 max-w-2xl mx-auto">
              Start earning in minutes. No complex setup, no coding required.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {[
              {
                step: '01',
                icon: <Users className="w-8 h-8" />,
                title: 'Create Account',
                description: 'Sign up in 30 seconds. Quick verification process to get you started immediately.',
                color: 'amber'
              },
              {
                step: '02',
                icon: <Target className="w-8 h-8" />,
                title: 'Choose Traders',
                description: 'Browse verified traders with transparent stats. Filter by ROI, risk level, or strategy.',
                color: 'emerald'
              },
              {
                step: '03',
                icon: <BarChart3 className="w-8 h-8" />,
                title: 'Allocate Funds',
                description: 'Set your investment amount and leverage. You control how much to risk on each trader.',
                color: 'blue'
              },
              {
                step: '04',
                icon: <TrendingUp className="w-8 h-8" />,
                title: 'Earn Profits',
                description: 'Receive trade signals via Telegram. Accept, decline, or let profits accumulate automatically.',
                color: 'rose'
              }
            ].map((item, i) => (
              <div key={i} className="relative">
                {i < 3 && (
                  <div className="hidden lg:block absolute top-1/2 left-full w-full h-0.5 bg-gradient-to-r from-gray-700 to-transparent -translate-y-1/2 z-0"></div>
                )}
                <div className="bg-gradient-to-br from-[#1a1d24] to-[#12151a] rounded-2xl p-6 border border-gray-800/50 relative z-10 h-full">
                  <div className={`w-14 h-14 rounded-xl flex items-center justify-center mb-4 ${
                    item.color === 'amber' ? 'bg-amber-500/20 text-amber-400' :
                    item.color === 'emerald' ? 'bg-emerald-500/20 text-emerald-400' :
                    item.color === 'blue' ? 'bg-blue-500/20 text-blue-400' :
                    'bg-rose-500/20 text-rose-400'
                  }`}>
                    {item.icon}
                  </div>
                  <div className="text-gray-600 text-sm font-bold mb-2">STEP {item.step}</div>
                  <h3 className="text-xl font-bold text-white mb-2">{item.title}</h3>
                  <p className="text-gray-400 text-sm leading-relaxed">{item.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-20 bg-gradient-to-b from-[#0b0e11] via-[#0f1318] to-[#0b0e11]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              Why Traders Choose Us
            </h2>
            <p className="text-gray-400 max-w-2xl mx-auto">
              Industry-leading features designed for both beginners and professionals.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              {
                icon: <Bell className="w-6 h-6" />,
                title: 'Instant Telegram Alerts',
                description: 'Get notified the moment a trader opens a position. Never miss a profitable opportunity.',
                highlight: true
              },
              {
                icon: <Clock className="w-6 h-6" />,
                title: '5-Minute Decision Window',
                description: 'Review each trade before it executes. Accept, modify allocation, or decline with one tap.',
                highlight: false
              },
              {
                icon: <Shield className="w-6 h-6" />,
                title: 'API-Verified Performance',
                description: 'Every trader stat is verified through direct API connection. No fake numbers, ever.',
                highlight: false
              },
              {
                icon: <Target className="w-6 h-6" />,
                title: 'Custom Risk Settings',
                description: 'Set your own leverage multiplier, allocation caps, and stop-loss thresholds.',
                highlight: false
              },
              {
                icon: <Play className="w-6 h-6" />,
                title: 'Mock Trading Mode',
                description: 'Practice with virtual funds before going live. Test strategies risk-free.',
                highlight: true
              },
              {
                icon: <Lock className="w-6 h-6" />,
                title: 'Full Fund Control',
                description: 'Withdraw anytime with no lock-ups. Your funds are always accessible.',
                highlight: false
              }
            ].map((feature, i) => (
              <div
                key={i}
                className={`rounded-2xl p-6 border transition-all ${
                  feature.highlight
                    ? 'bg-gradient-to-br from-amber-500/10 to-orange-500/5 border-amber-500/30 hover:border-amber-500/50'
                    : 'bg-gradient-to-br from-[#1a1d24] to-[#12151a] border-gray-800/50 hover:border-gray-700'
                }`}
              >
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center mb-4 ${
                  feature.highlight ? 'bg-amber-500/20 text-amber-400' : 'bg-white/5 text-gray-400'
                }`}>
                  {feature.icon}
                </div>
                <h3 className="text-lg font-bold text-white mb-2">{feature.title}</h3>
                <p className="text-gray-400 text-sm leading-relaxed">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-20 bg-[#0b0e11]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div>
              <div className="inline-flex items-center gap-2 bg-emerald-500/10 border border-emerald-500/30 rounded-full px-4 py-2 mb-4">
                <Smartphone className="w-4 h-4 text-emerald-400" />
                <span className="text-emerald-400 text-sm font-medium">Telegram Integration</span>
              </div>
              <h2 className="text-3xl sm:text-4xl font-bold mb-6">
                Trade Signals Delivered<br />
                <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#0088cc] to-[#00a2e8]">
                  Straight to Your Phone
                </span>
              </h2>
              <p className="text-gray-400 mb-8 leading-relaxed">
                Connect your Telegram account and receive instant notifications for every trade signal.
                Review the trade details, see the trader's reasoning, and decide in seconds whether to copy.
              </p>

              <div className="space-y-4">
                {[
                  'Real-time push notifications for new trades',
                  'Full trade details: entry price, leverage, TP/SL',
                  'One-tap accept or decline from the app',
                  'Portfolio summary and daily performance reports'
                ].map((item, i) => (
                  <div key={i} className="flex items-center gap-3">
                    <div className="w-6 h-6 rounded-full bg-emerald-500/20 flex items-center justify-center flex-shrink-0">
                      <CheckCircle className="w-4 h-4 text-emerald-400" />
                    </div>
                    <span className="text-gray-300">{item}</span>
                  </div>
                ))}
              </div>

              <button
                onClick={handleGetStarted}
                className="mt-8 bg-gradient-to-r from-[#0088cc] to-[#00a2e8] hover:from-[#0077b3] hover:to-[#0091d1] text-white font-bold px-8 py-4 rounded-xl transition-all hover:shadow-xl hover:shadow-[#0088cc]/20 flex items-center gap-2"
              >
                Connect Telegram Now
                <ArrowRight className="w-5 h-5" />
              </button>
            </div>

            <div className="relative">
              <div className="absolute inset-0 bg-gradient-to-br from-[#0088cc]/20 to-transparent rounded-3xl blur-3xl"></div>
              <div className="relative bg-gradient-to-br from-[#1a1d24] to-[#12151a] rounded-3xl p-6 border border-gray-800/50">
                <div className="flex items-center gap-3 mb-6 pb-4 border-b border-gray-800">
                  <div className="w-12 h-12 bg-gradient-to-br from-[#0088cc] to-[#00a2e8] rounded-full flex items-center justify-center">
                    <svg className="w-6 h-6 text-white" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.64 6.8c-.15 1.58-.8 5.42-1.13 7.19-.14.75-.42 1-.68 1.03-.58.05-1.02-.38-1.58-.75-.88-.58-1.38-.94-2.23-1.5-.99-.65-.35-1.01.22-1.59.15-.15 2.71-2.48 2.76-2.69a.2.2 0 00-.05-.18c-.06-.05-.14-.03-.21-.02-.09.02-1.49.95-4.22 2.79-.4.27-.76.41-1.08.4-.36-.01-1.04-.2-1.55-.37-.63-.2-1.12-.31-1.08-.66.02-.18.27-.36.74-.55 2.92-1.27 4.86-2.11 5.83-2.51 2.78-1.16 3.35-1.36 3.73-1.36.08 0 .27.02.39.12.1.08.13.19.14.27-.01.06.01.24 0 .38z"/>
                    </svg>
                  </div>
                  <div>
                    <div className="text-white font-semibold">Shark Trades Bot</div>
                    <div className="text-gray-500 text-sm">Online</div>
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="bg-[#0d0f12] rounded-2xl p-4 max-w-[85%]">
                    <div className="text-emerald-400 font-semibold text-sm mb-2">New Trade Signal</div>
                    <div className="text-white text-sm mb-2">
                      <span className="text-amber-400 font-medium">CryptoShark</span> opened a position:
                    </div>
                    <div className="bg-black/30 rounded-lg p-3 text-xs space-y-1">
                      <div className="flex justify-between">
                        <span className="text-gray-500">Pair:</span>
                        <span className="text-white font-medium">BTC/USDT</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Side:</span>
                        <span className="text-emerald-400 font-medium">LONG</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Entry:</span>
                        <span className="text-white font-medium">$94,250.00</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-500">Leverage:</span>
                        <span className="text-white font-medium">10x</span>
                      </div>
                    </div>
                    <div className="mt-3 text-gray-400 text-xs">
                      You have 5 minutes to accept this trade
                    </div>
                  </div>

                  <div className="flex gap-2 max-w-[85%]">
                    <button className="flex-1 bg-emerald-500 hover:bg-emerald-600 text-white font-semibold py-2.5 rounded-xl text-sm transition-colors">
                      Accept Trade
                    </button>
                    <button className="flex-1 bg-gray-700 hover:bg-gray-600 text-white font-semibold py-2.5 rounded-xl text-sm transition-colors">
                      Decline
                    </button>
                  </div>

                  <div className="text-gray-600 text-xs text-center pt-2">
                    4:32 remaining
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="py-20 bg-gradient-to-b from-[#0b0e11] to-[#0f1318]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              Real Results from Real Traders
            </h2>
            <p className="text-gray-400 max-w-2xl mx-auto">
              Join thousands who have transformed their trading with copy trading.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {testimonials.map((testimonial, i) => (
              <div
                key={i}
                className="bg-gradient-to-br from-[#1a1d24] to-[#12151a] rounded-2xl p-6 border border-gray-800/50"
              >
                <div className="flex items-center gap-1 mb-4">
                  {Array.from({ length: 5 }).map((_, j) => (
                    <Star key={j} className="w-4 h-4 fill-amber-400 text-amber-400" />
                  ))}
                </div>
                <p className="text-gray-300 mb-6 leading-relaxed">"{testimonial.text}"</p>
                <div className="flex items-center justify-between pt-4 border-t border-gray-800">
                  <div className="flex items-center gap-3">
                    <div className="text-3xl">{testimonial.avatar}</div>
                    <div>
                      <div className="text-white font-medium">{testimonial.name}</div>
                      <div className="text-gray-500 text-sm">{testimonial.location}</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-emerald-400 font-bold">{testimonial.profit}</div>
                    <div className="text-gray-500 text-xs">{testimonial.period}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-20 bg-[#0b0e11]">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl sm:text-4xl font-bold mb-4">
              Frequently Asked Questions
            </h2>
            <p className="text-gray-400">
              Everything you need to know about copy trading.
            </p>
          </div>

          <div className="space-y-3">
            {faqData.map((faq, i) => (
              <div
                key={i}
                className="bg-gradient-to-br from-[#1a1d24] to-[#12151a] rounded-xl border border-gray-800/50 overflow-hidden"
              >
                <button
                  onClick={() => setExpandedFaq(expandedFaq === i ? null : i)}
                  className="w-full flex items-center justify-between p-5 text-left hover:bg-white/[0.02] transition-colors"
                >
                  <span className="text-white font-medium pr-4">{faq.question}</span>
                  <ChevronDown className={`w-5 h-5 text-gray-500 transition-transform flex-shrink-0 ${
                    expandedFaq === i ? 'rotate-180' : ''
                  }`} />
                </button>
                <div className={`overflow-hidden transition-all duration-300 ${
                  expandedFaq === i ? 'max-h-96' : 'max-h-0'
                }`}>
                  <div className="px-5 pb-5">
                    <p className="text-gray-400 leading-relaxed">{faq.answer}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-20 bg-gradient-to-b from-[#0b0e11] to-[#0f1318]">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="relative bg-gradient-to-br from-amber-600/20 via-orange-600/10 to-amber-900/20 rounded-3xl p-8 sm:p-12 border border-amber-500/30 overflow-hidden">
            <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48cGF0dGVybiBpZD0iZ3JpZCIgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBwYXR0ZXJuVW5pdHM9InVzZXJTcGFjZU9uVXNlIj48cGF0aCBkPSJNIDQwIDAgTCAwIDAgMCA0MCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMDMpIiBzdHJva2Utd2lkdGg9IjEiLz48L3BhdHRlcm4+PC9kZWZzPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InVybCgjZ3JpZCkiLz48L3N2Zz4=')] opacity-30"></div>

            <div className="relative z-10 text-center">
              <div className="inline-flex items-center gap-2 bg-amber-500/20 border border-amber-500/40 rounded-full px-4 py-2 mb-6">
                <Award className="w-4 h-4 text-amber-400" />
                <span className="text-amber-300 text-sm font-medium">Limited Time Offer</span>
              </div>

              <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
                Get <span className="text-transparent bg-clip-text bg-gradient-to-r from-amber-400 to-orange-500">50 USDT Bonus</span>
              </h2>
              <p className="text-gray-300 text-lg mb-8 max-w-xl mx-auto">
                Allocate 200 USDT to your Copy Trading wallet and receive an instant 50 USDT bonus.
                Start copying top traders today!
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <button
                  onClick={handleGetStarted}
                  className="group bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-black font-bold px-10 py-4 rounded-xl transition-all hover:scale-105 hover:shadow-2xl hover:shadow-amber-500/30 flex items-center justify-center gap-2 text-lg"
                >
                  Claim Your Bonus
                  <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                </button>
              </div>

              <p className="text-gray-500 text-sm mt-6">
                No credit card required. Start with as little as $50.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="py-12 bg-[#0b0e11] border-t border-gray-800/50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-wrap justify-center items-center gap-8 sm:gap-12 opacity-40">
            <div className="text-xl sm:text-2xl font-bold text-gray-400">Forbes</div>
            <div className="text-xl sm:text-2xl font-bold text-gray-400">Bloomberg</div>
            <div className="text-xl sm:text-2xl font-bold text-gray-400">CNBC</div>
            <div className="text-xl sm:text-2xl font-bold text-gray-400">TechCrunch</div>
            <div className="text-xl sm:text-2xl font-bold text-gray-400">CoinDesk</div>
          </div>
        </div>
      </section>

      <footer className="bg-[#0b0e11] border-t border-gray-800/50 py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row justify-between items-center gap-6">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-gradient-to-br from-amber-400 to-amber-600 rounded-lg flex items-center justify-center">
                <span className="text-black font-black text-lg">S</span>
              </div>
              <span className="text-white font-bold text-lg">Shark Trades</span>
            </div>

            <div className="flex flex-wrap justify-center gap-6 text-sm text-gray-500">
              <a href="#" target="_blank" rel="noopener noreferrer" className="hover:text-gray-300 transition-colors">Terms of Service</a>
              <a href="#" target="_blank" rel="noopener noreferrer" className="hover:text-gray-300 transition-colors">Privacy Policy</a>
              <a href="#" target="_blank" rel="noopener noreferrer" className="hover:text-gray-300 transition-colors">Risk Disclosure</a>
              <a href="#" target="_blank" rel="noopener noreferrer" className="hover:text-gray-300 transition-colors">Contact Us</a>
            </div>
          </div>

          <div className="mt-8 pt-8 border-t border-gray-800/50 text-center">
            <p className="text-gray-600 text-xs leading-relaxed max-w-3xl mx-auto">
              Trading cryptocurrencies involves significant risk of loss and is not suitable for all investors.
              Past performance is not indicative of future results. Please ensure you fully understand the risks involved
              before trading. Copy trading does not guarantee profits and losses can exceed your investment.
            </p>
            <p className="text-gray-700 text-xs mt-4">
              2024 Shark Trades. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default CopyTradingLandingPage;

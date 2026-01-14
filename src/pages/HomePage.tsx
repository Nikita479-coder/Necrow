import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import SharkCardApplicationModal from '../components/SharkCardApplicationModal';
import CryptoIcon from '../components/CryptoIcon';
import TelegramPromoSection from '../components/TelegramPromoSection';
import { Shield, ChevronDown, ArrowRight, Gift, Check, ChevronLeft, ChevronRight, Zap, Lock, Globe, Users, TrendingUp, LineChart, Clock, Headphones, Loader2, Newspaper, ExternalLink, Smartphone, Bell } from 'lucide-react';
import { usePrices } from '../hooks/usePrices';
import { useNavigation } from '../App';
import { useAuth } from '../context/AuthContext';

interface NewsItem {
  id: string;
  title: string;
  source: string;
  url: string;
  publishedAt: string;
  category: string;
}

function HomePage() {
  const prices = usePrices();
  const { navigateTo } = useNavigation();
  const { user } = useAuth();
  const [showSharkCardModal, setShowSharkCardModal] = useState(false);
  const [currentSlide, setCurrentSlide] = useState(0);
  const [expandedFaq, setExpandedFaq] = useState<number | null>(null);
  const [news, setNews] = useState<NewsItem[]>([]);
  const [newsLoading, setNewsLoading] = useState(true);
  const [touchStart, setTouchStart] = useState<number | null>(null);
  const [touchEnd, setTouchEnd] = useState<number | null>(null);
  const [isPaused, setIsPaused] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [dragOffset, setDragOffset] = useState(0);

  const heroSlides = [
    {
      id: 'shark-card',
      title: 'Introducing Shark Card',
      subtitle: 'Your Crypto-Backed Credit',
      description: 'Access instant credit backed by your crypto holdings. Spend anywhere while your assets keep growing. No credit checks, no hassle.',
      cta: 'Apply Now',
      ctaAction: () => setShowSharkCardModal(true),
      visual: 'sharkcard',
      reward: 'Zero Interest',
      status: 'available',
    },
    {
      id: 'verified-deposit',
      title: 'Refer a Friend and Grab',
      subtitle: 'Up to 20 USDT',
      description: 'When your verified referral deposits $100 USD, you both receive 20 USDT each. More referrals, more rewards!',
      cta: 'Start Referring',
      ctaAction: () => navigateTo('referral'),
      visual: 'referral',
      reward: '20 USDT Each',
      status: 'available',
    },
  ];

  useEffect(() => {
    const fetchNews = async () => {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 5000);

        const response = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/fetch-crypto-news`,
          {
            headers: {
              'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
              'Content-Type': 'application/json',
            },
            signal: controller.signal,
          }
        );

        clearTimeout(timeout);

        if (response.ok) {
          const data = await response.json();
          if (data.success && data.news) {
            setNews(data.news);
          }
        }
      } catch (error) {
        // Silently fail
      } finally {
        setNewsLoading(false);
      }
    };

    fetchNews();
    const interval = setInterval(fetchNews, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (isPaused) return;

    const interval = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % heroSlides.length);
    }, 3000);

    return () => clearInterval(interval);
  }, [heroSlides.length, isPaused]);

  const formatTimeAgo = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    return `${diffDays}d ago`;
  };

  const faqData = [
    {
      question: 'What is a cryptocurrency exchange?',
      answer: 'A cryptocurrency exchange is a digital marketplace where you can buy, sell, and trade cryptocurrencies like Bitcoin, Ethereum, and many other digital assets. Shark Trades provides a secure platform with advanced trading tools, competitive fees, and 24/7 support to help you navigate the crypto markets with confidence.'
    },
    {
      question: 'What products does Shark Trades provide?',
      answer: 'Shark Trades offers a comprehensive suite of products including: Spot Trading for buying and selling crypto at current market prices, Futures Trading with up to 125x leverage, Copy Trading to follow successful traders automatically, Staking & Earn products for passive income, Shark Card for crypto-backed credit, and a secure Wallet for storing your digital assets.'
    },
    {
      question: 'How to buy Bitcoin and other cryptocurrencies on Shark Trades?',
      answer: 'Getting started is easy: 1) Create your free account and complete KYC verification, 2) Deposit funds using crypto transfer or supported payment methods, 3) Navigate to the trading page and select your desired cryptocurrency, 4) Enter the amount you want to buy and confirm your order. Your crypto will be instantly credited to your wallet.'
    },
    {
      question: 'How to track cryptocurrency prices?',
      answer: 'Shark Trades provides real-time price tracking with live charts, price alerts, and market analytics. You can view prices on our Markets page, set custom price alerts via the notification system, and access detailed charts with technical indicators. Our mobile app also provides push notifications for price movements.'
    },
    {
      question: 'How to trade cryptocurrencies on Shark Trades?',
      answer: 'Trading on Shark Trades is straightforward: For Spot Trading, simply select a trading pair, choose market or limit order, enter your amount, and execute. For Futures Trading, select your leverage (up to 125x), set take-profit and stop-loss levels, and manage your positions in real-time. We also offer Copy Trading where you can automatically mirror the trades of top performers.'
    },
    {
      question: 'How to earn from crypto on Shark Trades?',
      answer: 'There are multiple ways to earn: 1) Staking - Lock your crypto and earn up to 15% APY, 2) Copy Trading - Allocate funds to follow profitable traders and share their returns, 3) Referral Program - Earn up to 40% commission on referred users trading fees, 4) VIP Program - Higher tier members receive trading fee rebates and exclusive rewards, 5) Promotional Events - Regular trading competitions with prize pools.'
    },
    {
      question: 'Is my money safe on Shark Trades?',
      answer: 'Security is our top priority. We employ industry-leading measures including: Cold storage for 95% of user funds, Multi-signature authorization for withdrawals, 2FA authentication, Advanced encryption protocols, and regular security audits by third parties to ensure your assets are protected at all times.'
    },
    {
      question: 'What are the trading fees on Shark Trades?',
      answer: 'Shark Trades offers competitive fee structures: Spot trading fees start at 0.1% for makers and takers, Futures trading fees are 0.02% maker and 0.05% taker. VIP members enjoy significant discounts up to 50% off standard fees. Holding our native token or increasing trading volume unlocks additional fee reductions.'
    },
  ];

  const nextSlide = () => {
    setCurrentSlide((prev) => (prev + 1) % heroSlides.length);
    setIsPaused(true);
    setTimeout(() => setIsPaused(false), 3000);
  };

  const prevSlide = () => {
    setCurrentSlide((prev) => (prev - 1 + heroSlides.length) % heroSlides.length);
    setIsPaused(true);
    setTimeout(() => setIsPaused(false), 3000);
  };

  const minSwipeDistance = 50;

  const onTouchStart = (e: React.TouchEvent) => {
    setIsPaused(true);
    setIsDragging(true);
    setTouchEnd(null);
    setTouchStart(e.targetTouches[0].clientX);
  };

  const onTouchMove = (e: React.TouchEvent) => {
    if (!touchStart) return;
    const currentTouch = e.targetTouches[0].clientX;
    setTouchEnd(currentTouch);
    const diff = currentTouch - touchStart;
    setDragOffset(diff);
  };

  const onTouchEnd = () => {
    setIsDragging(false);
    setDragOffset(0);

    if (!touchStart || !touchEnd) {
      setTimeout(() => setIsPaused(false), 3000);
      return;
    }

    const distance = touchStart - touchEnd;
    const isLeftSwipe = distance > minSwipeDistance;
    const isRightSwipe = distance < -minSwipeDistance;

    if (isLeftSwipe) {
      nextSlide();
    } else if (isRightSwipe) {
      prevSlide();
    } else {
      setTimeout(() => setIsPaused(false), 3000);
    }
  };

  const getCryptoData = (symbol: string) => {
    const priceData = prices.get(symbol);
    return {
      price: priceData ? priceData.price : 0,
      change: priceData ? priceData.change24h : 0
    };
  };

  const btcData = getCryptoData('BTC/USDT');
  const ethData = getCryptoData('ETH/USDT');
  const bnbData = getCryptoData('BNB/USDT');
  const xrpData = getCryptoData('XRP/USDT');
  const solData = getCryptoData('SOL/USDT');

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="relative overflow-hidden bg-gradient-to-b from-[#181a20] to-[#0b0e11]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-16">
          {/* Hero Slider */}
          <div
            className="relative bg-gradient-to-br from-amber-600/20 via-orange-600/20 to-amber-900/20 border border-amber-500/30 rounded-2xl sm:rounded-3xl overflow-hidden mb-6 sm:mb-12"
            onMouseEnter={() => setIsPaused(true)}
            onMouseLeave={() => setIsPaused(false)}
          >
            <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48cGF0dGVybiBpZD0iZ3JpZCIgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBwYXR0ZXJuVW5pdHM9InVzZXJTcGFjZU9uVXNlIj48cGF0aCBkPSJNIDQwIDAgTCAwIDAgMCA0MCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMDMpIiBzdHJva2Utd2lkdGg9IjEiLz48L3BhdHRlcm4+PC9kZWZzPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InVybCgjZ3JpZCkiLz48L3N2Zz4=')] opacity-30"></div>

            <div className="relative">
              {/* Slide Content */}
              <div
                className="relative min-h-[420px] sm:min-h-[500px] lg:min-h-[550px] overflow-hidden touch-pan-y cursor-grab active:cursor-grabbing select-none"
                onTouchStart={onTouchStart}
                onTouchMove={onTouchMove}
                onTouchEnd={onTouchEnd}
                onMouseDown={(e) => {
                  setIsPaused(true);
                  setIsDragging(true);
                  setTouchStart(e.clientX);
                  setTouchEnd(null);
                }}
                onMouseMove={(e) => {
                  if (!isDragging || !touchStart) return;
                  const currentPos = e.clientX;
                  setTouchEnd(currentPos);
                  const diff = currentPos - touchStart;
                  setDragOffset(diff);
                }}
                onMouseUp={() => {
                  if (!isDragging) return;
                  setIsDragging(false);
                  setDragOffset(0);

                  if (!touchStart || !touchEnd) {
                    setTimeout(() => setIsPaused(false), 3000);
                    return;
                  }

                  const distance = touchStart - touchEnd;
                  const isLeftSwipe = distance > minSwipeDistance;
                  const isRightSwipe = distance < -minSwipeDistance;

                  if (isLeftSwipe) {
                    nextSlide();
                  } else if (isRightSwipe) {
                    prevSlide();
                  } else {
                    setTimeout(() => setIsPaused(false), 3000);
                  }
                }}
                onMouseLeave={() => {
                  if (isDragging) {
                    setIsDragging(false);
                    setDragOffset(0);
                    setTimeout(() => setIsPaused(false), 3000);
                  }
                }}
              >
                <div
                  className={`flex h-full ${isDragging ? '' : 'transition-transform duration-700 ease-in-out'}`}
                  style={{
                    width: `${heroSlides.length * 100}%`,
                    transform: `translateX(calc(-${(currentSlide * 100) / heroSlides.length}% + ${dragOffset}px))`
                  }}
                >
                {heroSlides.map((slide, index) => (
                  <div
                    key={slide.id}
                    className="h-full flex-shrink-0"
                    style={{ width: `${100 / heroSlides.length}%` }}
                  >
                    <div className="flex flex-col lg:grid lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8 p-5 sm:p-8 lg:p-12 h-full">
                      {/* Left Side - Content */}
                      <div className="flex flex-col justify-center space-y-3 sm:space-y-4 lg:space-y-6 order-2 lg:order-1">
                        <div>
                          <h1 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl xl:text-6xl font-bold text-white leading-tight mb-1 sm:mb-2">
                            {slide.title}
                          </h1>
                          <h2 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl xl:text-6xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-amber-400 to-orange-500">
                            {slide.subtitle}
                          </h2>
                        </div>

                        <p className="text-slate-300 text-sm sm:text-base lg:text-lg max-w-xl line-clamp-3 sm:line-clamp-none">
                          {slide.description}
                        </p>

                        <div>
                          <button
                            onClick={slide.ctaAction}
                            onMouseDown={(e) => e.stopPropagation()}
                            onTouchStart={(e) => e.stopPropagation()}
                            className="group px-6 py-3 sm:px-8 sm:py-3.5 lg:px-10 lg:py-4 bg-gradient-to-r from-amber-500 to-orange-600 hover:from-amber-600 hover:to-orange-700 text-black font-bold text-sm sm:text-base lg:text-lg rounded-xl transition-all hover:scale-105 hover:shadow-2xl hover:shadow-amber-500/20 flex items-center gap-2 w-fit cursor-pointer"
                          >
                            {slide.cta}
                            <ArrowRight className="w-4 h-4 sm:w-5 sm:h-5 group-hover:translate-x-1 transition-transform" />
                          </button>
                        </div>

                        {/* Reward Badge for Bonus Slides */}
                        {slide.reward && (
                          <div className="flex items-center gap-4">
                            {slide.status === 'claimed' && (
                              <div className="flex items-center gap-2 bg-emerald-500/20 border border-emerald-500/40 rounded-full px-3 py-1.5 sm:px-4 sm:py-2">
                                <Check className="w-4 h-4 sm:w-5 sm:h-5 text-emerald-400" />
                                <span className="text-emerald-400 text-xs sm:text-sm font-medium">Claimed</span>
                              </div>
                            )}
                          </div>
                        )}
                      </div>

                      {/* Right Side - Visual */}
                      <div className="relative flex items-center justify-center order-1 lg:order-2 py-4 sm:py-0">
                        <div className="absolute inset-0 bg-gradient-to-br from-amber-500/20 to-orange-500/20 blur-3xl"></div>

                        {/* Shark Card Visual */}
                        {slide.visual === 'sharkcard' && (
                          <div className="relative scale-[0.55] sm:scale-75 lg:scale-90 xl:scale-100 origin-center">
                            <div className="transform hover:scale-105 transition-transform duration-500">
                              <div className="bg-gradient-to-br from-slate-900 via-slate-800 to-black rounded-2xl p-6 shadow-2xl border border-amber-500/30" style={{ width: '360px', height: '220px' }}>
                                <div className="flex flex-col justify-between h-full">
                                  <div className="flex justify-between items-start">
                                    <div className="text-amber-400 font-bold text-lg">SHARK CARD</div>
                                    <div className="w-12 h-12 rounded-full bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center">
                                      <svg className="w-7 h-7 text-black" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
                                      </svg>
                                    </div>
                                  </div>

                                  <div className="space-y-2">
                                    <div className="text-white/60 text-xs uppercase tracking-wide">Available Credit</div>
                                    <div className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-amber-400 to-orange-500">
                                      $10,000
                                    </div>
                                  </div>

                                  <div className="flex justify-between items-center">
                                    <div className="text-white/80 font-semibold tracking-wider">•••• •••• •••• 8742</div>
                                    <div className="text-white/60 text-sm">{slide.reward}</div>
                                  </div>
                                </div>
                              </div>
                            </div>
                            <div className="absolute -top-6 -right-6 w-20 h-20 bg-gradient-to-br from-emerald-500 to-teal-600 rounded-full flex items-center justify-center shadow-xl animate-bounce">
                              <span className="text-white font-bold text-xs text-center leading-tight">0%<br/>APR</span>
                            </div>
                          </div>
                        )}

                        {/* Referral Visual */}
                        {slide.visual === 'referral' && (
                          <div className="relative scale-[0.55] sm:scale-75 lg:scale-90 xl:scale-100 origin-center">
                            <div className="transform rotate-6 hover:rotate-0 transition-transform duration-500">
                              <div className="bg-gradient-to-br from-slate-800 via-slate-700 to-slate-800 rounded-xl p-6 shadow-2xl border border-amber-500/20" style={{ width: '340px', height: '214px' }}>
                                <div className="flex justify-between items-start mb-8">
                                  <div className="text-white/80 font-semibold text-base">REFERRAL BONUS</div>
                                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
                                    <Gift className="w-5 h-5 text-white" />
                                  </div>
                                </div>
                                <div className="space-y-4">
                                  <div className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-amber-400 to-orange-500">{slide.reward}</div>
                                  <div className="text-white/60 text-sm">For verified deposits of $100+</div>
                                </div>
                              </div>
                            </div>
                            <div className="absolute -bottom-6 -left-6 w-20 h-20 bg-gradient-to-br from-amber-500 to-orange-600 rounded-full flex items-center justify-center shadow-xl animate-pulse">
                              <span className="text-white font-bold text-sm">$100+</span>
                            </div>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
                </div>
              </div>

              {/* Slide Indicators */}
              <div className="absolute bottom-4 sm:bottom-6 lg:bottom-8 left-1/2 transform -translate-x-1/2 flex gap-2 sm:gap-3 z-20">
                {heroSlides.map((_, index) => (
                  <button
                    key={index}
                    onClick={() => {
                      setCurrentSlide(index);
                      setIsPaused(true);
                      setTimeout(() => setIsPaused(false), 3000);
                    }}
                    onMouseDown={(e) => e.stopPropagation()}
                    onTouchStart={(e) => e.stopPropagation()}
                    className={`transition-all rounded-full cursor-pointer ${
                      index === currentSlide
                        ? 'bg-amber-500 w-2.5 h-2.5 sm:w-3 sm:h-3'
                        : 'bg-slate-600 hover:bg-slate-500 w-2 h-2 sm:w-2.5 sm:h-2.5'
                    }`}
                  />
                ))}
              </div>

              {/* Navigation Arrows */}
              <button
                onClick={prevSlide}
                onMouseDown={(e) => e.stopPropagation()}
                onTouchStart={(e) => e.stopPropagation()}
                className="absolute left-2 sm:left-4 top-1/2 transform -translate-y-1/2 w-8 h-8 sm:w-10 sm:h-10 flex items-center justify-center bg-black/40 hover:bg-black/60 rounded-full border border-white/20 hover:border-amber-500/50 transition-all z-20 cursor-pointer"
              >
                <ChevronLeft className="w-5 h-5 sm:w-6 sm:h-6 text-white" />
              </button>
              <button
                onClick={nextSlide}
                onMouseDown={(e) => e.stopPropagation()}
                onTouchStart={(e) => e.stopPropagation()}
                className="absolute right-2 sm:right-4 top-1/2 transform -translate-y-1/2 w-8 h-8 sm:w-10 sm:h-10 flex items-center justify-center bg-black/40 hover:bg-black/60 rounded-full border border-white/20 hover:border-amber-500/50 transition-all z-20 cursor-pointer"
              >
                <ChevronRight className="w-5 h-5 sm:w-6 sm:h-6 text-white" />
              </button>
            </div>
          </div>

          <div className="text-center mb-8 sm:mb-12">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 sm:gap-8 mb-8 sm:mb-12">
              <div>
                <div className="text-2xl sm:text-4xl md:text-5xl font-bold text-white mb-2">7,143,201</div>
                <div className="text-gray-400 text-xs sm:text-sm uppercase tracking-wide">Users Trust Us</div>
              </div>
              <div>
                <div className="text-2xl sm:text-4xl md:text-5xl font-bold text-white mb-2">No.1</div>
                <div className="text-gray-400 text-xs sm:text-sm uppercase tracking-wide">Customer Assets</div>
                <div className="text-base sm:text-xl text-gray-300 mt-2">Assets</div>
                <div className="text-lg sm:text-2xl font-bold text-[#f0b90b]">$1.5B</div>
              </div>
              <div>
                <div className="text-2xl sm:text-4xl md:text-5xl font-bold text-white mb-2">No.1</div>
                <div className="text-gray-400 text-xs sm:text-sm uppercase tracking-wide">Trading Volume</div>
                <div className="text-base sm:text-xl text-gray-300 mt-2">24H</div>
                <div className="text-lg sm:text-2xl font-bold text-[#f0b90b]">$1.2B</div>
              </div>
            </div>

            {!user && (
              <div className="max-w-md mx-auto">
                <button
                  onClick={() => navigateTo('signup')}
                  className="w-full bg-[#f0b90b] hover:bg-[#d9a506] text-black font-semibold py-3 rounded-lg transition-colors"
                >
                  Get Started
                </button>
              </div>
            )}
          </div>

          <div className="bg-[#181a20] rounded-2xl p-4 sm:p-6 border border-gray-800 mb-8">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-4">
              <div className="flex gap-4 sm:gap-6">
                <button className="text-white font-semibold pb-2 border-b-2 border-[#f0b90b] text-sm sm:text-base">Popular</button>
                <button className="text-gray-400 hover:text-white transition-colors text-sm sm:text-base">New Listing</button>
              </div>
              <button
                onClick={() => navigateTo('markets')}
                className="text-gray-400 text-xs sm:text-sm hover:text-white cursor-pointer whitespace-nowrap"
              >
                View All 350+ Coins →
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
              <div onClick={() => navigateTo('futures-trading')} className="bg-[#0b0e11] rounded-lg p-4 hover:bg-[#1a1d24] transition-colors cursor-pointer">
                <div className="flex items-center gap-3 mb-3">
                  <CryptoIcon symbol="BTC" size={32} />
                  <div>
                    <div className="text-white font-semibold">BTC</div>
                    <div className="text-gray-400 text-xs">Bitcoin</div>
                  </div>
                </div>
                <div className="text-white font-bold text-lg">
                  ${btcData.price > 0 ? btcData.price.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '108,404.47'}
                </div>
                <div className={`text-sm ${btcData.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {btcData.price > 0 ? `${btcData.change >= 0 ? '+' : ''}${btcData.change.toFixed(2)}%` : '+1.28%'}
                </div>
              </div>

              <div onClick={() => navigateTo('futures-trading')} className="bg-[#0b0e11] rounded-lg p-4 hover:bg-[#1a1d24] transition-colors cursor-pointer">
                <div className="flex items-center gap-3 mb-3">
                  <CryptoIcon symbol="ETH" size={32} />
                  <div>
                    <div className="text-white font-semibold">ETH</div>
                    <div className="text-gray-400 text-xs">Ethereum</div>
                  </div>
                </div>
                <div className="text-white font-bold text-lg">
                  ${ethData.price > 0 ? ethData.price.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '3,987.72'}
                </div>
                <div className={`text-sm ${ethData.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {ethData.price > 0 ? `${ethData.change >= 0 ? '+' : ''}${ethData.change.toFixed(2)}%` : '+2.95%'}
                </div>
              </div>

              <div onClick={() => navigateTo('futures-trading')} className="bg-[#0b0e11] rounded-lg p-4 hover:bg-[#1a1d24] transition-colors cursor-pointer">
                <div className="flex items-center gap-3 mb-3">
                  <CryptoIcon symbol="BNB" size={32} />
                  <div>
                    <div className="text-white font-semibold">BNB</div>
                    <div className="text-gray-400 text-xs">BNB</div>
                  </div>
                </div>
                <div className="text-white font-bold text-lg">
                  ${bnbData.price > 0 ? bnbData.price.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '1,119.94'}
                </div>
                <div className={`text-sm ${bnbData.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {bnbData.price > 0 ? `${bnbData.change >= 0 ? '+' : ''}${bnbData.change.toFixed(2)}%` : '+2.43%'}
                </div>
              </div>

              <div onClick={() => navigateTo('futures-trading')} className="bg-[#0b0e11] rounded-lg p-4 hover:bg-[#1a1d24] transition-colors cursor-pointer">
                <div className="flex items-center gap-3 mb-3">
                  <CryptoIcon symbol="XRP" size={32} />
                  <div>
                    <div className="text-white font-semibold">XRP</div>
                    <div className="text-gray-400 text-xs">XRP</div>
                  </div>
                </div>
                <div className="text-white font-bold text-lg">
                  ${xrpData.price > 0 ? xrpData.price.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '2.41'}
                </div>
                <div className={`text-sm ${xrpData.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {xrpData.price > 0 ? `${xrpData.change >= 0 ? '+' : ''}${xrpData.change.toFixed(2)}%` : '+2.18%'}
                </div>
              </div>

              <div onClick={() => navigateTo('futures-trading')} className="bg-[#0b0e11] rounded-lg p-4 hover:bg-[#1a1d24] transition-colors cursor-pointer">
                <div className="flex items-center gap-3 mb-3">
                  <CryptoIcon symbol="SOL" size={32} />
                  <div>
                    <div className="text-white font-semibold">SOL</div>
                    <div className="text-gray-400 text-xs">Solana</div>
                  </div>
                </div>
                <div className="text-white font-bold text-lg">
                  ${solData.price > 0 ? solData.price.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '191.51'}
                </div>
                <div className={`text-sm ${solData.change >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                  {solData.price > 0 ? `${solData.change >= 0 ? '+' : ''}${solData.change.toFixed(2)}%` : '+3.27%'}
                </div>
              </div>
            </div>
          </div>

          <div className="bg-[#181a20] rounded-2xl p-6 border border-gray-800 mb-8">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Newspaper className="w-5 h-5 text-[#f0b90b]" />
                <h3 className="text-white font-semibold text-lg">Latest Crypto News</h3>
                {newsLoading && <Loader2 className="w-4 h-4 text-gray-400 animate-spin" />}
              </div>
              <div className="flex items-center gap-2">
                <span className="text-xs text-gray-500">Live updates</span>
                <div className="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></div>
              </div>
            </div>

            {newsLoading ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {[1, 2, 3, 4].map((i) => (
                  <div key={i} className="p-4 bg-[#0b0e11] rounded-lg animate-pulse">
                    <div className="h-4 bg-gray-700 rounded w-3/4 mb-2"></div>
                    <div className="h-3 bg-gray-800 rounded w-1/4"></div>
                  </div>
                ))}
              </div>
            ) : news.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {news.slice(0, 6).map((item) => (
                  <a
                    key={item.id}
                    href={item.url !== '#' ? item.url : undefined}
                    target={item.url !== '#' ? '_blank' : undefined}
                    rel="noopener noreferrer"
                    className="group p-4 bg-[#0b0e11] rounded-lg hover:bg-[#1a1d24] cursor-pointer transition-all border border-transparent hover:border-gray-700"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <p className="text-gray-300 text-sm group-hover:text-white transition-colors line-clamp-2 flex-1">
                        {item.title}
                      </p>
                      {item.url !== '#' && (
                        <ExternalLink className="w-4 h-4 text-gray-600 group-hover:text-[#f0b90b] transition-colors flex-shrink-0 mt-0.5" />
                      )}
                    </div>
                    <div className="flex items-center gap-2 mt-2">
                      <span className="text-xs text-[#f0b90b]">{item.source}</span>
                      <span className="text-gray-600">-</span>
                      <span className="text-xs text-gray-500">{formatTimeAgo(item.publishedAt)}</span>
                    </div>
                  </a>
                ))}
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="text-gray-300 text-sm hover:text-white cursor-pointer transition-colors p-4 hover:bg-[#0b0e11] rounded">
                  Bitcoin maintains strong momentum above key support levels
                </div>
                <div className="text-gray-300 text-sm hover:text-white cursor-pointer transition-colors p-4 hover:bg-[#0b0e11] rounded">
                  Institutional investors continue accumulating crypto positions
                </div>
                <div className="text-gray-300 text-sm hover:text-white cursor-pointer transition-colors p-4 hover:bg-[#0b0e11] rounded">
                  DeFi protocols see increased adoption across major networks
                </div>
                <div className="text-gray-300 text-sm hover:text-white cursor-pointer transition-colors p-4 hover:bg-[#0b0e11] rounded">
                  Layer 2 solutions gain traction as scaling solutions mature
                </div>
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
            <div className="bg-gradient-to-br from-blue-600/20 to-blue-800/20 border border-blue-600/30 rounded-2xl p-6">
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 bg-blue-500 rounded-lg flex items-center justify-center flex-shrink-0">
                  <Shield className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h3 className="text-white font-bold text-lg mb-2">Recognized as Forbes'</h3>
                  <p className="text-gray-300 text-sm">Most Trusted Crypto Exchanges 2025</p>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-emerald-600/20 to-emerald-800/20 border border-emerald-600/30 rounded-2xl p-6">
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 bg-emerald-500 rounded-lg flex items-center justify-center flex-shrink-0">
                  <Shield className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h3 className="text-white font-bold text-lg mb-2">Listed #1 in Fortune's</h3>
                  <p className="text-gray-300 text-sm">FinTech Innovators Asia 2024 in Blockchain & Crypto</p>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-[#f0b90b]/20 to-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-2xl p-6">
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 bg-[#f0b90b] rounded-lg flex items-center justify-center flex-shrink-0">
                  <Shield className="w-6 h-6 text-black" />
                </div>
                <div>
                  <h3 className="text-white font-bold text-lg mb-2">Named CNBC's</h3>
                  <p className="text-gray-300 text-sm">World's Top Fintech Companies 2025 in Digital Assets</p>
                </div>
              </div>
            </div>
          </div>

          <div className="mb-8 sm:mb-12">
            <TelegramPromoSection />
          </div>

          <div className="bg-gradient-to-br from-[#181a20] to-[#1a1d24] rounded-2xl p-6 sm:p-8 border border-gray-800 mb-12 overflow-hidden relative">
            <div className="absolute top-0 right-0 w-64 h-64 bg-[#f0b90b]/5 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2"></div>
            <div className="flex flex-col md:flex-row items-center justify-between gap-8 relative z-10">
              <div className="flex-1 text-center md:text-left">
                <div className="inline-flex items-center gap-2 bg-[#f0b90b]/10 text-[#f0b90b] px-4 py-1.5 rounded-full text-sm font-medium mb-4">
                  <Smartphone className="w-4 h-4" />
                  Coming Soon
                </div>
                <h2 className="text-2xl sm:text-3xl font-bold text-white mb-3">Trade on the go. Anywhere, anytime.</h2>
                <p className="text-gray-400 mb-6 max-w-md">Our mobile app is under development. Get notified when it launches and be among the first to experience seamless trading on your fingertips.</p>
                <div className="flex flex-col sm:flex-row gap-3 justify-center md:justify-start">
                  <div className="flex items-center gap-2 bg-[#181a20] border border-gray-700 rounded-xl px-4 py-3">
                    <svg className="w-6 h-6 text-white" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09l.01-.01zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
                    </svg>
                    <div className="text-left">
                      <div className="text-[10px] text-gray-500 leading-tight">Coming to</div>
                      <div className="text-white text-sm font-semibold leading-tight">App Store</div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 bg-[#181a20] border border-gray-700 rounded-xl px-4 py-3">
                    <svg className="w-6 h-6 text-white" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 0 1-.61-.92V2.734a1 1 0 0 1 .609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-3.198l2.807 1.626a1 1 0 0 1 0 1.73l-2.808 1.626L15.206 12l2.492-2.491zM5.864 2.658L16.8 8.99l-2.302 2.302-8.634-8.634z"/>
                    </svg>
                    <div className="text-left">
                      <div className="text-[10px] text-gray-500 leading-tight">Coming to</div>
                      <div className="text-white text-sm font-semibold leading-tight">Google Play</div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="flex-1 flex justify-center">
                <div className="relative">
                  <div className="w-48 h-96 bg-gradient-to-b from-[#2a2d35] to-[#181a20] rounded-[2.5rem] border-4 border-gray-700 shadow-2xl flex items-center justify-center">
                    <div className="absolute top-4 left-1/2 -translate-x-1/2 w-20 h-6 bg-black rounded-full"></div>
                    <div className="text-center p-6">
                      <div className="w-16 h-16 bg-gradient-to-br from-[#f0b90b] to-[#f5d55a] rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg">
                        <TrendingUp className="w-8 h-8 text-black" />
                      </div>
                      <div className="text-white font-bold text-lg mb-1">Shark Trades</div>
                      <div className="text-gray-500 text-xs">Mobile App</div>
                    </div>
                  </div>
                  <div className="absolute -bottom-2 left-1/2 -translate-x-1/2 w-32 h-4 bg-black/30 rounded-full blur-md"></div>
                </div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-12">
            <div className="bg-gradient-to-br from-[#181a20] to-[#1a1d24] rounded-2xl p-6 sm:p-8 border border-gray-800">
              <h3 className="text-xl sm:text-2xl font-bold text-white mb-6">Why Choose Shark Trades?</h3>
              <div className="space-y-5">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-gradient-to-br from-amber-500/20 to-orange-500/20 rounded-xl flex items-center justify-center flex-shrink-0">
                    <Zap className="w-6 h-6 text-amber-500" />
                  </div>
                  <div>
                    <h4 className="text-white font-semibold mb-1">Lightning Fast Execution</h4>
                    <p className="text-gray-400 text-sm">Execute trades in milliseconds with our high-performance matching engine processing 1.4M TPS.</p>
                  </div>
                </div>
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-gradient-to-br from-emerald-500/20 to-teal-500/20 rounded-xl flex items-center justify-center flex-shrink-0">
                    <Lock className="w-6 h-6 text-emerald-500" />
                  </div>
                  <div>
                    <h4 className="text-white font-semibold mb-1">Bank-Grade Security</h4>
                    <p className="text-gray-400 text-sm">95% cold storage, multi-sig wallets, and 2FA authentication protect your assets around the clock.</p>
                  </div>
                </div>
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-gradient-to-br from-blue-500/20 to-cyan-500/20 rounded-xl flex items-center justify-center flex-shrink-0">
                    <Globe className="w-6 h-6 text-blue-500" />
                  </div>
                  <div>
                    <h4 className="text-white font-semibold mb-1">Global Coverage</h4>
                    <p className="text-gray-400 text-sm">Available in 180+ countries with 40+ fiat currency support and localized customer service.</p>
                  </div>
                </div>
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-gradient-to-br from-rose-500/20 to-pink-500/20 rounded-xl flex items-center justify-center flex-shrink-0">
                    <Headphones className="w-6 h-6 text-rose-500" />
                  </div>
                  <div>
                    <h4 className="text-white font-semibold mb-1">24/7 Support</h4>
                    <p className="text-gray-400 text-sm">Round-the-clock customer support via live chat, email, and phone in multiple languages.</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-[#181a20] to-[#1a1d24] rounded-2xl p-6 sm:p-8 border border-gray-800 relative overflow-hidden">
              <div className="absolute top-0 right-0 w-32 h-32 bg-[#0088cc]/10 rounded-full blur-2xl"></div>
              <div className="relative z-10">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-12 h-12 bg-gradient-to-br from-[#0088cc] to-[#00a2e8] rounded-xl flex items-center justify-center">
                    <svg className="w-6 h-6 text-white" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.64 6.8c-.15 1.58-.8 5.42-1.13 7.19-.14.75-.42 1-.68 1.03-.58.05-1.02-.38-1.58-.75-.88-.58-1.38-.94-2.23-1.5-.99-.65-.35-1.01.22-1.59.15-.15 2.71-2.48 2.76-2.69a.2.2 0 00-.05-.18c-.06-.05-.14-.03-.21-.02-.09.02-1.49.95-4.22 2.79-.4.27-.76.41-1.08.4-.36-.01-1.04-.2-1.55-.37-.63-.2-1.12-.31-1.08-.66.02-.18.27-.36.74-.55 2.92-1.27 4.86-2.11 5.83-2.51 2.78-1.16 3.35-1.36 3.73-1.36.08 0 .27.02.39.12.1.08.13.19.14.27-.01.06.01.24 0 .38z"/>
                    </svg>
                  </div>
                  <div>
                    <h3 className="text-xl sm:text-2xl font-bold text-white">Copy Trading Alerts</h3>
                    <p className="text-[#0088cc] text-sm font-medium">Powered by Telegram</p>
                  </div>
                </div>

                <p className="text-gray-400 text-sm mb-6">Never miss a trading opportunity. Get instant notifications when expert traders open new positions.</p>

                <div className="space-y-4 mb-6">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-emerald-500/20 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Bell className="w-4 h-4 text-emerald-400" />
                    </div>
                    <div>
                      <p className="text-white text-sm font-medium">Real-Time Trade Alerts</p>
                      <p className="text-gray-500 text-xs">Instant notifications when trades are opened</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-blue-500/20 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Users className="w-4 h-4 text-blue-400" />
                    </div>
                    <div>
                      <p className="text-white text-sm font-medium">Follow Top Traders</p>
                      <p className="text-gray-500 text-xs">Copy strategies from verified experts</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-amber-500/20 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Clock className="w-4 h-4 text-amber-400" />
                    </div>
                    <div>
                      <p className="text-white text-sm font-medium">5-Minute Decision Window</p>
                      <p className="text-gray-500 text-xs">Accept or decline trades on your terms</p>
                    </div>
                  </div>
                </div>

                <div className="bg-[#0d0e12] rounded-xl p-4 border border-gray-800">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 bg-gradient-to-br from-[#0088cc] to-[#00a2e8] rounded-full flex items-center justify-center flex-shrink-0">
                      <svg className="w-5 h-5 text-white" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.64 6.8c-.15 1.58-.8 5.42-1.13 7.19-.14.75-.42 1-.68 1.03-.58.05-1.02-.38-1.58-.75-.88-.58-1.38-.94-2.23-1.5-.99-.65-.35-1.01.22-1.59.15-.15 2.71-2.48 2.76-2.69a.2.2 0 00-.05-.18c-.06-.05-.14-.03-.21-.02-.09.02-1.49.95-4.22 2.79-.4.27-.76.41-1.08.4-.36-.01-1.04-.2-1.55-.37-.63-.2-1.12-.31-1.08-.66.02-.18.27-.36.74-.55 2.92-1.27 4.86-2.11 5.83-2.51 2.78-1.16 3.35-1.36 3.73-1.36.08 0 .27.02.39.12.1.08.13.19.14.27-.01.06.01.24 0 .38z"/>
                      </svg>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-white text-sm font-semibold">Shark Trades Bot</span>
                        <span className="text-gray-500 text-xs">just now</span>
                      </div>
                      <div className="bg-[#1a1d24] rounded-lg p-3 text-xs">
                        <p className="text-emerald-400 font-medium mb-1">New Trade Opened!</p>
                        <p className="text-gray-400">CryptoWhale opened a <span className="text-emerald-400">LONG</span> position on <span className="text-white">BTC/USDT</span></p>
                        <p className="text-gray-500 mt-1">Entry: $94,250 | Leverage: 10x</p>
                      </div>
                    </div>
                  </div>
                </div>

                <button
                  onClick={() => navigateTo('copytrading')}
                  className="w-full mt-4 py-3 bg-gradient-to-r from-[#0088cc] to-[#00a2e8] hover:from-[#0077b3] hover:to-[#0091d1] text-white font-semibold rounded-lg transition-all flex items-center justify-center gap-2"
                >
                  Explore Copy Trading
                  <ArrowRight className="w-5 h-5" />
                </button>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-12">
            <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800 text-center">
              <div className="w-12 h-12 bg-amber-500/20 rounded-full flex items-center justify-center mx-auto mb-3">
                <TrendingUp className="w-6 h-6 text-amber-500" />
              </div>
              <div className="text-2xl font-bold text-white mb-1">350+</div>
              <div className="text-gray-400 text-sm">Trading Pairs</div>
            </div>
            <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800 text-center">
              <div className="w-12 h-12 bg-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-3">
                <Users className="w-6 h-6 text-emerald-500" />
              </div>
              <div className="text-2xl font-bold text-white mb-1">7.1M+</div>
              <div className="text-gray-400 text-sm">Registered Users</div>
            </div>
            <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800 text-center">
              <div className="w-12 h-12 bg-blue-500/20 rounded-full flex items-center justify-center mx-auto mb-3">
                <LineChart className="w-6 h-6 text-blue-500" />
              </div>
              <div className="text-2xl font-bold text-white mb-1">$1.2B</div>
              <div className="text-gray-400 text-sm">24h Volume</div>
            </div>
            <div className="bg-[#181a20] rounded-xl p-5 border border-gray-800 text-center">
              <div className="w-12 h-12 bg-rose-500/20 rounded-full flex items-center justify-center mx-auto mb-3">
                <Clock className="w-6 h-6 text-rose-500" />
              </div>
              <div className="text-2xl font-bold text-white mb-1">&lt; 0.01s</div>
              <div className="text-gray-400 text-sm">Avg. Execution</div>
            </div>
          </div>

          <div className="bg-[#181a20] rounded-2xl p-6 sm:p-8 border border-gray-800 mb-12">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-4">
              <h2 className="text-2xl font-bold text-white">Frequently Asked Questions</h2>
              <button
                onClick={() => navigateTo('support')}
                className="text-[#f0b90b] hover:underline text-sm flex items-center gap-1"
              >
                Need more help? Contact Support
                <ArrowRight className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              {faqData.map((faq, idx) => (
                <div
                  key={idx}
                  className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden transition-all"
                >
                  <button
                    onClick={() => setExpandedFaq(expandedFaq === idx ? null : idx)}
                    className="w-full flex items-center justify-between p-4 sm:p-5 text-left hover:bg-[#1a1d24] transition-colors"
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-8 h-8 bg-[#f0b90b]/20 rounded-full flex items-center justify-center text-[#f0b90b] text-sm font-bold flex-shrink-0">
                        {idx + 1}
                      </div>
                      <span className="text-gray-200 font-medium text-sm sm:text-base">{faq.question}</span>
                    </div>
                    <div className={`transform transition-transform duration-200 ${expandedFaq === idx ? 'rotate-180' : ''}`}>
                      <ChevronDown className="w-5 h-5 text-gray-500" />
                    </div>
                  </button>
                  <div
                    className={`overflow-hidden transition-all duration-300 ${
                      expandedFaq === idx ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0'
                    }`}
                  >
                    <div className="px-4 sm:px-5 pb-4 sm:pb-5 pt-0">
                      <div className="pl-12 text-gray-400 text-sm leading-relaxed border-l-2 border-[#f0b90b]/30 ml-4">
                        {faq.answer}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-gradient-to-r from-[#f0b90b]/10 via-amber-500/5 to-[#f0b90b]/10 rounded-2xl p-8 border border-[#f0b90b]/20 mb-12">
            <div className="text-center mb-8">
              <h2 className="text-2xl sm:text-3xl font-bold text-white mb-3">Trusted by Millions Worldwide</h2>
              <p className="text-gray-400">Join the world's most trusted cryptocurrency exchange</p>
            </div>
            <div className="flex flex-wrap justify-center items-center gap-8 sm:gap-12 opacity-60">
              <div className="text-xl sm:text-2xl font-bold text-gray-400">Forbes</div>
              <div className="text-xl sm:text-2xl font-bold text-gray-400">Bloomberg</div>
              <div className="text-xl sm:text-2xl font-bold text-gray-400">CNBC</div>
              <div className="text-xl sm:text-2xl font-bold text-gray-400">TechCrunch</div>
              <div className="text-xl sm:text-2xl font-bold text-gray-400">Reuters</div>
              <div className="text-xl sm:text-2xl font-bold text-gray-400">CoinDesk</div>
            </div>
          </div>

          {!user && (
            <div className="text-center mt-12">
              <button
                onClick={() => navigateTo('signup')}
                className="px-12 py-4 bg-[#f0b90b] hover:bg-[#d9a506] text-black font-bold text-lg rounded-lg transition-all hover:scale-105"
              >
                Start earning today
              </button>
            </div>
          )}
        </div>
      </div>

      <footer className="bg-[#0b0e11] border-t border-gray-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-8">
            <div className="col-span-2 md:col-span-1">
              <div className="flex items-center gap-2 mb-4">
                <div className="w-8 h-8 bg-[#f0b90b] rounded-lg flex items-center justify-center">
                  <span className="text-black font-bold text-lg">S</span>
                </div>
                <span className="text-white font-bold text-xl">Shark Trades</span>
              </div>
              <p className="text-gray-500 text-sm">
                The world's leading cryptocurrency exchange platform for trading digital assets.
              </p>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Products</h4>
              <ul className="space-y-2">
                <li><button onClick={() => navigateTo('futures')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Futures Trading</button></li>
                <li><button onClick={() => navigateTo('swap')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Spot/Swap</button></li>
                <li><button onClick={() => navigateTo('copytrading')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Copy Trading</button></li>
                <li><button onClick={() => navigateTo('earn')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Earn</button></li>
              </ul>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Programs</h4>
              <ul className="space-y-2">
                <li><button onClick={() => navigateTo('referral')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Referral</button></li>
                <li><button onClick={() => navigateTo('affiliate')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Affiliate</button></li>
                <li><button onClick={() => navigateTo('vip')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">VIP Program</button></li>
                <li><button onClick={() => navigateTo('rewardshub')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Rewards Hub</button></li>
              </ul>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Support</h4>
              <ul className="space-y-2">
                <li><button onClick={() => navigateTo('support')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Help Center</button></li>
                <li><button onClick={() => navigateTo('kyc')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Verification</button></li>
              </ul>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Legal</h4>
              <ul className="space-y-2">
                <li><button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Legal Center</button></li>
                <li><button onClick={() => navigateTo('terms')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Terms of Service</button></li>
                <li><button onClick={() => navigateTo('bonusterms')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Bonus Terms</button></li>
              </ul>
            </div>
          </div>

          <div className="mt-12 pt-8 border-t border-gray-800">
            <div className="flex flex-col md:flex-row justify-between items-center gap-4">
              <p className="text-gray-500 text-sm">
                2024 Shark Trades. All rights reserved.
              </p>
              <div className="flex flex-wrap justify-center gap-4 text-sm">
                <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">Privacy Policy</button>
                <span className="text-gray-700">|</span>
                <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">Cookie Policy</button>
                <span className="text-gray-700">|</span>
                <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">Risk Disclosure</button>
                <span className="text-gray-700">|</span>
                <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">AML/KYC Policy</button>
              </div>
            </div>
          </div>
        </div>
      </footer>

      <SharkCardApplicationModal
        isOpen={showSharkCardModal}
        onClose={() => setShowSharkCardModal(false)}
      />
    </div>
  );
}

export default HomePage;

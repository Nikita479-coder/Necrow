import { useState, useEffect } from 'react';
import { X, Gift, Trophy, Ticket, ArrowRight, Sparkles } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';

const POPUP_INTERVAL_MS = 2 * 60 * 60 * 1000;
const STORAGE_KEY = 'giveaway_popup_last_shown';

export default function GiveawayPopup() {
  const { isAuthenticated } = useAuth();
  const { navigateTo } = useNavigation();
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    if (!isAuthenticated) return;

    const lastShown = localStorage.getItem(STORAGE_KEY);
    const now = Date.now();

    if (!lastShown || now - parseInt(lastShown) >= POPUP_INTERVAL_MS) {
      const timer = setTimeout(() => {
        setIsVisible(true);
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [isAuthenticated]);

  const handleClose = () => {
    localStorage.setItem(STORAGE_KEY, Date.now().toString());
    setIsVisible(false);
  };

  const handleViewGiveaways = () => {
    localStorage.setItem(STORAGE_KEY, Date.now().toString());
    setIsVisible(false);
    navigateTo('giveawayhub');
  };

  if (!isVisible) return null;

  return (
    <div className="fixed inset-0 z-[9998] flex items-center justify-center p-4 animate-fadeIn">
      <div
        className="absolute inset-0 bg-black/80 backdrop-blur-sm"
        onClick={handleClose}
      />

      <div className="relative bg-gradient-to-br from-[#1a1d24] via-[#0b0e11] to-[#1a1d24] rounded-2xl border border-yellow-500/30 max-w-lg w-full overflow-hidden shadow-2xl animate-slideUp">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute -top-20 -right-20 w-40 h-40 bg-yellow-500/20 rounded-full blur-3xl" />
          <div className="absolute -bottom-20 -left-20 w-40 h-40 bg-amber-500/20 rounded-full blur-3xl" />
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-60 h-60 bg-yellow-500/5 rounded-full blur-2xl" />
        </div>

        <button
          onClick={handleClose}
          className="absolute top-4 right-4 z-10 p-2 bg-black/50 hover:bg-black/70 rounded-full text-white transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="relative p-6 sm:p-8">
          <div className="flex justify-center mb-6">
            <div className="relative">
              <div className="w-24 h-24 bg-gradient-to-br from-yellow-500 to-amber-600 rounded-2xl flex items-center justify-center shadow-xl shadow-yellow-500/30 animate-bounce-slow">
                <Gift className="w-12 h-12 text-white" />
              </div>
              <div className="absolute -top-2 -right-2 w-8 h-8 bg-emerald-500 rounded-full flex items-center justify-center animate-pulse">
                <Sparkles className="w-4 h-4 text-white" />
              </div>
            </div>
          </div>

          <div className="text-center mb-6">
            <h2 className="text-2xl sm:text-3xl font-bold text-white mb-2">
              Win Big with Giveaways!
            </h2>
            <p className="text-gray-400 text-sm sm:text-base">
              Participate in exclusive campaigns and win amazing prizes including USDT, fee vouchers, and more!
            </p>
          </div>

          <div className="grid grid-cols-3 gap-3 mb-6">
            <div className="bg-[#0b0e11]/80 rounded-xl p-4 text-center border border-gray-800">
              <div className="w-10 h-10 bg-yellow-500/20 rounded-lg flex items-center justify-center mx-auto mb-2">
                <Trophy className="w-5 h-5 text-yellow-500" />
              </div>
              <div className="text-white font-bold text-lg">$10K+</div>
              <div className="text-gray-500 text-xs">Prize Pools</div>
            </div>
            <div className="bg-[#0b0e11]/80 rounded-xl p-4 text-center border border-gray-800">
              <div className="w-10 h-10 bg-emerald-500/20 rounded-lg flex items-center justify-center mx-auto mb-2">
                <Ticket className="w-5 h-5 text-emerald-500" />
              </div>
              <div className="text-white font-bold text-lg">Free</div>
              <div className="text-gray-500 text-xs">Tickets</div>
            </div>
            <div className="bg-[#0b0e11]/80 rounded-xl p-4 text-center border border-gray-800">
              <div className="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center mx-auto mb-2">
                <Gift className="w-5 h-5 text-blue-500" />
              </div>
              <div className="text-white font-bold text-lg">Daily</div>
              <div className="text-gray-500 text-xs">Rewards</div>
            </div>
          </div>

          <div className="bg-gradient-to-r from-yellow-500/10 to-amber-500/10 rounded-xl p-4 border border-yellow-500/20 mb-6">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-yellow-500 rounded-xl flex items-center justify-center flex-shrink-0">
                <Sparkles className="w-6 h-6 text-black" />
              </div>
              <div>
                <div className="text-white font-semibold">How to participate?</div>
                <div className="text-gray-400 text-sm">Trade, deposit, or complete tasks to earn tickets!</div>
              </div>
            </div>
          </div>

          <div className="flex gap-3">
            <button
              onClick={handleClose}
              className="flex-1 px-4 py-3 bg-gray-800 hover:bg-gray-700 text-white font-medium rounded-xl transition-colors"
            >
              Maybe Later
            </button>
            <button
              onClick={handleViewGiveaways}
              className="flex-1 px-4 py-3 bg-gradient-to-r from-yellow-500 to-amber-600 hover:from-yellow-600 hover:to-amber-700 text-black font-bold rounded-xl transition-all flex items-center justify-center gap-2"
            >
              View Giveaways
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      <style>{`
        @keyframes fadeIn {
          from { opacity: 0; }
          to { opacity: 1; }
        }
        @keyframes slideUp {
          from {
            opacity: 0;
            transform: translateY(20px) scale(0.95);
          }
          to {
            opacity: 1;
            transform: translateY(0) scale(1);
          }
        }
        @keyframes bounce-slow {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-8px); }
        }
        .animate-fadeIn { animation: fadeIn 0.2s ease-out; }
        .animate-slideUp { animation: slideUp 0.3s ease-out; }
        .animate-bounce-slow { animation: bounce-slow 2s ease-in-out infinite; }
      `}</style>
    </div>
  );
}

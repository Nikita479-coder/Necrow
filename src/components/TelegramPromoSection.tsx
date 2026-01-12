import { MessageCircle, CheckCircle2, Zap, Shield } from 'lucide-react';

export default function TelegramPromoSection() {
  const handleJoinTelegram = () => {
    window.open('https://t.me/officialsharkexchange', '_blank');
  };

  return (
    <div className="relative overflow-hidden bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 rounded-2xl border border-teal-500/20 p-8 md:p-12">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-5">
        <div className="absolute inset-0" style={{
          backgroundImage: `radial-gradient(circle at 2px 2px, rgba(20, 184, 166, 0.4) 1px, transparent 0)`,
          backgroundSize: '40px 40px'
        }} />
      </div>

      {/* Glow Effect */}
      <div className="absolute top-0 right-0 w-96 h-96 bg-teal-500/10 rounded-full blur-3xl" />
      <div className="absolute bottom-0 left-0 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl" />

      <div className="relative z-10 max-w-4xl mx-auto text-center">
        {/* Shark Icon */}
        <div className="inline-flex items-center justify-center w-16 h-16 bg-teal-500/10 rounded-2xl mb-6 border border-teal-500/20">
          <svg className="w-8 h-8 text-teal-400" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z"/>
          </svg>
        </div>

        {/* Main Headline */}
        <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold text-white mb-4">
          🦈 Don't Trade Alone. <span className="text-transparent bg-clip-text bg-gradient-to-r from-teal-400 to-cyan-400">Trade With Sharks.</span>
        </h2>

        {/* Sub-Headline */}
        <p className="text-lg md:text-xl text-slate-300 mb-8 max-w-2xl mx-auto">
          Join the official Shark-Trades Telegram Channel & Community Group
          and get real-time signals, market insights, and exclusive updates directly from our traders.
        </p>

        {/* Key Benefits */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8 max-w-2xl mx-auto">
          <div className="flex items-center gap-3 text-left bg-slate-800/50 backdrop-blur-sm rounded-xl p-4 border border-teal-500/10">
            <div className="flex-shrink-0">
              <CheckCircle2 className="w-5 h-5 text-teal-400" />
            </div>
            <span className="text-slate-200 font-medium">Live trade signals</span>
          </div>

          <div className="flex items-center gap-3 text-left bg-slate-800/50 backdrop-blur-sm rounded-xl p-4 border border-teal-500/10">
            <div className="flex-shrink-0">
              <CheckCircle2 className="w-5 h-5 text-teal-400" />
            </div>
            <span className="text-slate-200 font-medium">Market news & alerts</span>
          </div>

          <div className="flex items-center gap-3 text-left bg-slate-800/50 backdrop-blur-sm rounded-xl p-4 border border-teal-500/10">
            <div className="flex-shrink-0">
              <CheckCircle2 className="w-5 h-5 text-teal-400" />
            </div>
            <span className="text-slate-200 font-medium">Community support & discussions</span>
          </div>

          <div className="flex items-center gap-3 text-left bg-slate-800/50 backdrop-blur-sm rounded-xl p-4 border border-teal-500/10">
            <div className="flex-shrink-0">
              <CheckCircle2 className="w-5 h-5 text-teal-400" />
            </div>
            <span className="text-slate-200 font-medium">Early access to features & promotions</span>
          </div>
        </div>

        {/* Urgency Line */}
        <div className="inline-flex items-center gap-2 bg-gradient-to-r from-teal-500/20 to-cyan-500/20 border border-teal-500/30 rounded-full px-6 py-2.5 mb-8">
          <Zap className="w-4 h-4 text-teal-400" />
          <span className="text-teal-300 font-medium">Thousands of active traders are already inside</span>
        </div>

        {/* CTA Button */}
        <div className="mb-6">
          <button
            onClick={handleJoinTelegram}
            className="group relative inline-flex items-center gap-3 px-8 py-4 bg-gradient-to-r from-teal-500 to-cyan-500 hover:from-teal-400 hover:to-cyan-400 text-white font-bold text-lg rounded-xl transition-all duration-300 shadow-lg shadow-teal-500/30 hover:shadow-teal-500/50 hover:scale-105"
          >
            <MessageCircle className="w-6 h-6" />
            <span>Join Shark-Trades Telegram Now</span>
            <div className="absolute inset-0 bg-white/20 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity blur-xl" />
          </button>
        </div>

        {/* Secondary Info */}
        <div className="flex items-center justify-center gap-4 text-sm text-slate-400">
          <div className="flex items-center gap-1.5">
            <Shield className="w-4 h-4 text-teal-400" />
            <span>Safe</span>
          </div>
          <span>•</span>
          <span>Free</span>
          <span>•</span>
          <span>Instant Access</span>
        </div>

        {/* Official Link Disclaimer */}
        <div className="mt-6 pt-6 border-t border-slate-700/50">
          <p className="text-xs text-slate-500">
            Official Shark-Trades Telegram – no impersonators
          </p>
          <a
            href="https://t.me/officialsharkexchange"
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-teal-400 hover:text-teal-300 transition-colors mt-1 inline-block"
          >
            https://t.me/officialsharkexchange
          </a>
        </div>
      </div>
    </div>
  );
}

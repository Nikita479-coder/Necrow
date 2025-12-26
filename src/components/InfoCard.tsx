import { ChevronRight, TrendingUp, TrendingDown, Flame, Sparkles, Trophy, BarChart3 } from 'lucide-react';

interface Token {
  symbol: string;
  name: string;
  price: number;
  change24h: number;
  icon: string;
}

interface InfoCardProps {
  title: string;
  tokens: Token[];
}

const titleIcons = {
  'Hot': Flame,
  'New': Sparkles,
  'Top Gainer': Trophy,
  'Top Volume': BarChart3,
};

export default function InfoCard({ title, tokens }: InfoCardProps) {
  const IconComponent = titleIcons[title as keyof typeof titleIcons];

  return (
    <div className="glass-card rounded-2xl p-5 hover-lift neon-glow-hover transition-all duration-300 group relative overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-br from-[#f0b90b]/5 via-transparent to-[#f8d12f]/5 opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
      <div className="absolute -top-20 -right-20 w-40 h-40 bg-[#f0b90b]/10 rounded-full blur-3xl group-hover:bg-[#f0b90b]/20 transition-all duration-500"></div>

      <div className="relative z-10">
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-2">
            {IconComponent && <IconComponent className="w-4 h-4 text-[#f0b90b]" />}
            <h3 className="text-gray-300 text-sm font-semibold tracking-wide">{title}</h3>
          </div>
          <button className="text-gray-500 hover:text-[#f0b90b] transition-all duration-300 flex items-center gap-1 text-xs group/btn">
            <span className="group-hover/btn:mr-1 transition-all">More</span>
            <ChevronRight className="w-3 h-3 group-hover/btn:translate-x-1 transition-transform" />
          </button>
        </div>

        <div className="space-y-4">
          {tokens.map((token, index) => (
            <div
              key={token.symbol}
              className="flex items-center justify-between p-2 rounded-xl hover:bg-white/5 transition-all duration-300 cursor-pointer group/token"
              style={{ animationDelay: `${index * 100}ms` }}
            >
              <div className="flex items-center gap-3">
                <div className="relative">
                  <span className="text-2xl filter drop-shadow-lg">{token.icon}</span>
                  <div className="absolute inset-0 blur-md opacity-50">{token.icon}</div>
                </div>
                <span className="text-gray-100 font-semibold group-hover/token:text-[#f0b90b] transition-colors">
                  {token.symbol}
                </span>
              </div>
              <div className="text-right">
                <div className="text-gray-100 font-bold text-sm mb-1">
                  ${token.price >= 1000 ? `${(token.price / 1000).toFixed(2)}K` : token.price.toFixed(4)}
                </div>
                <div className="flex items-center gap-1 justify-end">
                  {token.change24h >= 0 ? (
                    <TrendingUp className="w-3 h-3 text-emerald-400" />
                  ) : (
                    <TrendingDown className="w-3 h-3 text-rose-400" />
                  )}
                  <div
                    className={`text-xs font-bold px-2 py-0.5 rounded-full ${
                      token.change24h >= 0
                        ? 'text-emerald-400 bg-emerald-400/10'
                        : 'text-rose-400 bg-rose-400/10'
                    }`}
                  >
                    {token.change24h >= 0 ? '+' : ''}{token.change24h.toFixed(2)}%
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

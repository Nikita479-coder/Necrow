import { useState } from 'react';
import { Sparkles } from 'lucide-react';

const mainTabs = [
  'Favorites',
  'Cryptos',
  'Spot',
  'Futures',
  'Alpha',
  'New',
  'Zones',
];

const subTabs = [
  'All',
  'BNB Chain',
  'Solana',
  'RWA',
  'Meme',
  'Payments',
  'AI',
  'Layer 1 / Layer 2',
  'Metaverse',
  'Seed',
  'Launchpool',
  'Megadrop',
  'Gaming',
];

export default function TabNavigation() {
  const [activeMainTab, setActiveMainTab] = useState('Cryptos');
  const [activeSubTab, setActiveSubTab] = useState('All');

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-8 border-b border-[#f0b90b]/10 relative">
        <div className="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-[#f0b90b]/30 to-transparent"></div>
        {mainTabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveMainTab(tab)}
            className={`pb-4 text-sm font-semibold transition-all duration-300 relative group ${
              activeMainTab === tab
                ? 'text-[#f0b90b]'
                : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            <span className="relative z-10">{tab}</span>
            {tab === 'Alpha' && (
              <span className="absolute -top-1 -right-9 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black text-[10px] px-2 py-0.5 rounded-full font-bold shadow-lg animate-pulse flex items-center gap-1">
                <Sparkles className="w-2 h-2" />
                New
              </span>
            )}
            {activeMainTab === tab ? (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] shadow-[0_0_10px_rgba(240,185,11,0.5)]"></div>
            ) : (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] scale-x-0 group-hover:scale-x-100 transition-transform duration-300 origin-left"></div>
            )}
          </button>
        ))}
      </div>

      <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-custom">
        {subTabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveSubTab(tab)}
            className={`px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all duration-300 relative overflow-hidden group ${
              activeSubTab === tab
                ? 'bg-gradient-to-r from-[#f0b90b]/20 to-[#f8d12f]/20 text-[#f0b90b] border border-[#f0b90b]/30 shadow-lg shadow-[#f0b90b]/10'
                : 'text-gray-400 hover:text-gray-200 border border-gray-700/30 hover:border-[#f0b90b]/30 hover:bg-[#f0b90b]/5'
            }`}
          >
            <span className="relative z-10 flex items-center gap-1.5">
              {tab}
              {(tab === 'Solana' || tab === 'Launchpool' || tab === 'Megadrop') && (
                <span className="bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black text-[9px] px-1.5 py-0.5 rounded-full font-bold">
                  New
                </span>
              )}
            </span>
            {activeSubTab === tab && (
              <div className="absolute inset-0 bg-gradient-to-r from-[#f0b90b]/10 to-[#f8d12f]/10 animate-pulse"></div>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}

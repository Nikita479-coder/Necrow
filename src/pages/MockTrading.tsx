import { useState } from 'react';
import Navbar from '../components/Navbar';
import { useNavigation } from '../App';
import { ArrowLeft } from 'lucide-react';

interface CopiedTrader {
  name: string;
  avatar: string;
  copiedOn: string;
  copyAmount: string;
  roi: string;
  unrealizedPnl: string;
}

function MockTrading() {
  const { navigateTo } = useNavigation();
  const [activeTab, setActiveTab] = useState<'mock'>('mock');

  const copiedTraders: CopiedTrader[] = [
    {
      name: 'billionith',
      avatar: '💰',
      copiedOn: '2025-11-01 08:07',
      copyAmount: '10,000.0000',
      roi: '-0.03%',
      unrealizedPnl: '-3.5424'
    },
    {
      name: 'Patrick429',
      avatar: '👤',
      copiedOn: '2025-11-01 08:05',
      copyAmount: '10,000.0000',
      roi: '-0.17%',
      unrealizedPnl: '-17.5954'
    }
  ];

  return (
    <div className="min-h-screen bg-[#181a20] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 py-4">
        <button
          onClick={() => navigateTo('copytrading')}
          className="flex items-center gap-1 text-gray-400 hover:text-white transition-colors text-sm mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Portfolios List
        </button>

        <div className="flex items-center gap-8 mb-8">
          <button
            onClick={() => setActiveTab('mock')}
            className={`pb-2 text-sm font-normal transition-colors relative ${
              activeTab === 'mock'
                ? 'text-white'
                : 'text-gray-400 hover:text-gray-300'
            }`}
          >
            Mock Copy Trading (2)
            {activeTab === 'mock' && (
              <div className="absolute bottom-0 left-0 right-0 h-[2px] bg-[#fcd535]"></div>
            )}
          </button>
        </div>

        <div className="space-y-0">
          {copiedTraders.map((trader, idx) => (
            <div key={idx} className="py-6 border-b border-[#2b3139] last:border-b-0">
              <div className="flex items-center justify-between mb-6">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-[#2b3139] flex items-center justify-center text-xl">
                    {trader.avatar}
                  </div>
                  <div>
                    <h3 className="text-base font-normal text-white mb-0.5">{trader.name}</h3>
                    <p className="text-xs text-[#848e9c]">Copied on: {trader.copiedOn}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => navigateTo('activecopying')}
                    className="bg-[#fcd535] hover:bg-[#f0b90b] text-[#0b0e11] px-5 py-1.5 rounded text-sm font-medium transition-colors"
                  >
                    Copy
                  </button>
                  <button className="bg-transparent hover:bg-[#2b3139] border border-[#474d57] text-[#eaecef] px-5 py-1.5 rounded text-sm font-medium transition-colors">
                    Stop Mock Trading
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-6">
                <div>
                  <div className="text-[#848e9c] text-xs mb-1.5">Net Copy Amount</div>
                  <div className="text-[#eaecef] text-base font-normal">{trader.copyAmount}</div>
                </div>
                <div>
                  <div className="text-[#848e9c] text-xs mb-1.5">ROI</div>
                  <div className={`text-base font-normal ${
                    trader.roi.startsWith('-') ? 'text-[#f6465d]' : 'text-[#0ecb81]'
                  }`}>
                    {trader.roi}
                  </div>
                </div>
                <div>
                  <div className="text-[#848e9c] text-xs mb-1.5">Unrealized PNL (USDT)</div>
                  <div className={`text-base font-normal ${
                    trader.unrealizedPnl.startsWith('-') ? 'text-[#f6465d]' : 'text-[#0ecb81]'
                  }`}>
                    {trader.unrealizedPnl}
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

export default MockTrading;

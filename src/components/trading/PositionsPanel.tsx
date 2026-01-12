import { useState } from 'react';

const tabs = [
  'Positions(0)',
  'Open Orders(0)',
  'Order History',
  'Trade History',
  'Transaction History',
  'Position History',
  'Bots',
  'Assets',
];

function PositionsPanel() {
  const [activeTab, setActiveTab] = useState('Positions(0)');

  return (
    <div className="h-64 bg-[#0b0e11] border-t border-gray-800">
      <div className="flex items-center gap-6 px-4 border-b border-gray-800">
        {tabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`py-3 text-xs font-medium transition-colors relative ${
              activeTab === tab
                ? 'text-white'
                : 'text-gray-400 hover:text-gray-300'
            }`}
          >
            {tab}
            {activeTab === tab && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#f0b90b]" />
            )}
          </button>
        ))}
      </div>

      <div className="p-8 flex flex-col items-center justify-center text-center">
        <div className="w-16 h-16 mb-4 bg-gray-800 rounded-full flex items-center justify-center">
          <svg
            className="w-8 h-8 text-gray-600"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
        </div>
        <p className="text-gray-400 text-sm">No positions</p>
      </div>
    </div>
  );
}

export default PositionsPanel;

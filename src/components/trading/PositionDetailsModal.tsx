import { useState, useEffect } from 'react';
import { X, Download, Share2, ChevronLeft, ChevronRight } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Position {
  position_id: string;
  pair: string;
  side: string;
  entry_price: number;
  mark_price: number;
  quantity: number;
  leverage: number;
  margin_allocated: number;
  realized_pnl?: number;
  unrealized_pnl?: number;
  cumulative_fees?: number;
  opened_at: string;
  closed_at?: string;
  status: string;
}

interface FeeDetail {
  fee_type: string;
  fee_amount: number;
  fee_rate: number;
  notional_size: number;
  created_at: string;
}

interface PositionDetailsModalProps {
  position: Position;
  onClose: () => void;
}

function PositionDetailsModal({ position, onClose }: PositionDetailsModalProps) {
  const [currentSlide, setCurrentSlide] = useState(0);
  const [feeDetails, setFeeDetails] = useState<FeeDetail[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchFeeDetails();
  }, [position.position_id]);

  const fetchFeeDetails = async () => {
    try {
      const { data, error } = await supabase
        .from('fee_collections')
        .select('*')
        .eq('position_id', position.position_id)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setFeeDetails(data || []);
    } catch (error) {
      console.error('Error fetching fee details:', error);
    } finally {
      setLoading(false);
    }
  };

  const baseCurrency = position.pair.replace('USDT', '');
  const exitPrice = position.status === 'closed' ? position.mark_price : null;
  const pnl = position.status === 'closed' ? (position.realized_pnl || 0) : (position.unrealized_pnl || 0);
  const isProfitable = pnl >= 0;

  const totalOpeningFee = feeDetails
    .filter(f => f.fee_type === 'futures_open')
    .reduce((sum, f) => sum + parseFloat(f.fee_amount.toString()), 0);

  const totalClosingFee = feeDetails
    .filter(f => f.fee_type === 'futures_close')
    .reduce((sum, f) => sum + parseFloat(f.fee_amount.toString()), 0);

  const totalFundingFees = feeDetails
    .filter(f => f.fee_type === 'funding_payment')
    .reduce((sum, f) => sum + parseFloat(f.fee_amount.toString()), 0);

  const totalFeesUSDT = totalOpeningFee + totalClosingFee + Math.abs(totalFundingFees);

  const marginInBase = position.margin_allocated / position.entry_price;
  const openingFeeInBase = (totalOpeningFee / position.margin_allocated) * marginInBase;
  const closingFeeInBase = (totalClosingFee / position.margin_allocated) * marginInBase;
  const fundingFeesInBase = (Math.abs(totalFundingFees) / position.margin_allocated) * marginInBase;
  const totalFeesInBase = (totalFeesUSDT / position.margin_allocated) * marginInBase;

  const pnlInBase = (Math.abs(pnl) / (exitPrice || position.mark_price));

  const downloadImage = async () => {
    const slide = document.getElementById('share-slide');
    if (!slide) return;

    try {
      const html2canvas = (await import('html2canvas')).default;
      const canvas = await html2canvas(slide, {
        backgroundColor: '#0b0e11',
        scale: 2,
      });

      const link = document.createElement('a');
      link.download = `${position.pair}-${position.side}-trade.png`;
      link.href = canvas.toDataURL();
      link.click();
    } catch (error) {
      console.error('Failed to download image:', error);
    }
  };

  const renderShareSlide = () => (
    <div
      id="share-slide"
      className="relative w-full h-full bg-gradient-to-br from-[#0b0e11] via-[#1a1f2e] to-[#0b0e11] p-8 flex flex-col items-center justify-center overflow-hidden"
    >
      <div className="absolute inset-0 opacity-5">
        <div className="absolute inset-0" style={{
          backgroundImage: 'radial-gradient(circle at 2px 2px, rgba(255,255,255,0.15) 1px, transparent 0)',
          backgroundSize: '32px 32px'
        }}></div>
      </div>

      <div className="relative z-10 w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-block px-4 py-1 bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-full mb-4">
            <span className="text-[#f0b90b] font-bold text-sm tracking-wider">SHARK TRADING</span>
          </div>
        </div>

        <div className="bg-black/40 backdrop-blur-sm border border-gray-700/50 rounded-2xl p-8 shadow-2xl">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-4xl font-bold text-white mb-1">{position.pair}</h2>
              <p className="text-gray-400 text-sm">
                {new Date(position.closed_at || position.opened_at).toLocaleDateString('en-US', {
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric'
                })}
              </p>
            </div>
            <div className={`px-6 py-3 rounded-xl font-bold text-2xl ${
              position.side === 'long'
                ? 'bg-green-500/20 text-green-400 border border-green-500/30'
                : 'bg-red-500/20 text-red-400 border border-red-500/30'
            }`}>
              {position.side.toUpperCase()}
            </div>
          </div>

          <div className="space-y-4 mb-6">
            <div className="flex justify-between items-center py-3 border-b border-gray-700/50">
              <span className="text-gray-400 text-sm">Entry Price</span>
              <span className="text-white font-mono text-lg font-semibold">
                ${position.entry_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </span>
            </div>
            {exitPrice && (
              <div className="flex justify-between items-center py-3 border-b border-gray-700/50">
                <span className="text-gray-400 text-sm">Exit Price</span>
                <span className="text-white font-mono text-lg font-semibold">
                  ${exitPrice.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
            )}
            <div className="flex justify-between items-center py-3 border-b border-gray-700/50">
              <span className="text-gray-400 text-sm">Size</span>
              <span className="text-white font-mono text-lg font-semibold">
                {position.quantity.toFixed(4)} {baseCurrency}
              </span>
            </div>
            <div className="flex justify-between items-center py-3">
              <span className="text-gray-400 text-sm">Leverage</span>
              <span className="text-[#f0b90b] font-mono text-lg font-bold">
                {position.leverage}x
              </span>
            </div>
          </div>

          <div className={`relative rounded-xl p-6 ${
            isProfitable
              ? 'bg-gradient-to-br from-green-500/20 to-green-600/10 border border-green-500/30'
              : 'bg-gradient-to-br from-red-500/20 to-red-600/10 border border-red-500/30'
          }`}>
            <div className="absolute top-4 right-4 text-5xl opacity-10">
              {isProfitable ? '📈' : '📉'}
            </div>
            <div className="relative">
              <p className={`text-sm font-medium mb-2 ${isProfitable ? 'text-green-400' : 'text-red-400'}`}>
                {position.status === 'closed' ? 'Realized' : 'Unrealized'} P&L
              </p>
              <div className="flex items-baseline gap-2">
                <span className={`text-5xl font-bold ${isProfitable ? 'text-green-400' : 'text-red-400'}`}>
                  {isProfitable ? '+' : ''}{pnl.toFixed(2)}
                </span>
                <span className="text-2xl text-gray-400">USDT</span>
              </div>
              <div className={`text-sm mt-2 ${isProfitable ? 'text-green-400/80' : 'text-red-400/80'}`}>
                {isProfitable ? '+' : ''}{pnlInBase.toFixed(6)} {baseCurrency}
              </div>
            </div>
          </div>
        </div>

        <div className="mt-6 text-center">
          <p className="text-gray-500 text-xs">
            Trade ID: {position.position_id.slice(0, 8)}...
          </p>
        </div>
      </div>
    </div>
  );

  const renderDetailsSlide = () => (
    <div className="p-6 overflow-y-auto h-full">
      <h3 className="text-xl font-bold text-white mb-6">Trade Breakdown</h3>

      <div className="space-y-6">
        <div className="bg-gray-800/50 rounded-lg p-4">
          <h4 className="text-sm font-semibold text-gray-400 mb-3 uppercase tracking-wider">Position Info</h4>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Pair</span>
              <span className="text-white font-medium">{position.pair}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Side</span>
              <span className={position.side === 'long' ? 'text-green-400' : 'text-red-400'}>
                {position.side.toUpperCase()}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Size</span>
              <span className="text-white font-mono">{position.quantity.toFixed(4)} {baseCurrency}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Leverage</span>
              <span className="text-[#f0b90b] font-semibold">{position.leverage}x</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Margin</span>
              <span className="text-white font-mono">${position.margin_allocated.toFixed(2)}</span>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 rounded-lg p-4">
          <h4 className="text-sm font-semibold text-gray-400 mb-3 uppercase tracking-wider">Price Points</h4>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Entry Price</span>
              <span className="text-white font-mono">${position.entry_price.toFixed(2)}</span>
            </div>
            {exitPrice && (
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Exit Price</span>
                <span className="text-white font-mono">${exitPrice.toFixed(2)}</span>
              </div>
            )}
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Current/Mark Price</span>
              <span className="text-white font-mono">${position.mark_price.toFixed(2)}</span>
            </div>
          </div>
        </div>

        {!loading && feeDetails.length > 0 && (
          <div className="bg-gray-800/50 rounded-lg p-4">
            <h4 className="text-sm font-semibold text-gray-400 mb-3 uppercase tracking-wider">Fee Breakdown</h4>
            <div className="space-y-3">
              {totalOpeningFee > 0 && (
                <div className="border-b border-gray-700 pb-2">
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-gray-400">Opening Fee</span>
                    <span className="text-orange-400 font-mono">
                      {openingFeeInBase.toFixed(8)} {baseCurrency}
                    </span>
                  </div>
                  <div className="flex justify-end">
                    <span className="text-xs text-gray-500 font-mono">
                      ${totalOpeningFee.toFixed(4)} USDT
                    </span>
                  </div>
                </div>
              )}

              {totalClosingFee > 0 && (
                <div className="border-b border-gray-700 pb-2">
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-gray-400">Closing Fee</span>
                    <span className="text-orange-400 font-mono">
                      {closingFeeInBase.toFixed(8)} {baseCurrency}
                    </span>
                  </div>
                  <div className="flex justify-end">
                    <span className="text-xs text-gray-500 font-mono">
                      ${totalClosingFee.toFixed(4)} USDT
                    </span>
                  </div>
                </div>
              )}

              {totalFundingFees > 0 && (
                <div className="border-b border-gray-700 pb-2">
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-gray-400">Funding Fees</span>
                    <span className="text-orange-400 font-mono">
                      {fundingFeesInBase.toFixed(8)} {baseCurrency}
                    </span>
                  </div>
                  <div className="flex justify-end">
                    <span className="text-xs text-gray-500 font-mono">
                      ${totalFundingFees.toFixed(4)} USDT
                    </span>
                  </div>
                </div>
              )}

              <div className="pt-2 border-t-2 border-gray-600">
                <div className="flex justify-between text-sm font-semibold mb-1">
                  <span className="text-white">Total Fees</span>
                  <span className="text-orange-400 font-mono">
                    {totalFeesInBase.toFixed(8)} {baseCurrency}
                  </span>
                </div>
                <div className="flex justify-end">
                  <span className="text-xs text-gray-400 font-mono">
                    ${totalFeesUSDT.toFixed(4)} USDT
                  </span>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className={`rounded-lg p-4 ${
          isProfitable ? 'bg-green-500/10 border border-green-500/30' : 'bg-red-500/10 border border-red-500/30'
        }`}>
          <h4 className="text-sm font-semibold text-gray-400 mb-3 uppercase tracking-wider">
            {position.status === 'closed' ? 'Realized' : 'Unrealized'} P&L
          </h4>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-300 text-lg">In {baseCurrency}</span>
              <span className={`text-xl font-bold font-mono ${isProfitable ? 'text-green-400' : 'text-red-400'}`}>
                {isProfitable ? '+' : ''}{pnlInBase.toFixed(8)}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-300 text-lg">In USDT</span>
              <span className={`text-xl font-bold font-mono ${isProfitable ? 'text-green-400' : 'text-red-400'}`}>
                {isProfitable ? '+' : ''}{pnl.toFixed(2)}
              </span>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 rounded-lg p-4">
          <h4 className="text-sm font-semibold text-gray-400 mb-3 uppercase tracking-wider">Timeline</h4>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Opened</span>
              <span className="text-white">
                {new Date(position.opened_at).toLocaleString()}
              </span>
            </div>
            {position.closed_at && (
              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Closed</span>
                <span className="text-white">
                  {new Date(position.closed_at).toLocaleString()}
                </span>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-[#0b0e11] border border-gray-700 rounded-lg w-full max-w-2xl max-h-[90vh] flex flex-col shadow-2xl">
        <div className="flex items-center justify-between p-4 border-b border-gray-700">
          <div className="flex items-center gap-2">
            <h2 className="text-lg font-bold text-white">Position Details</h2>
            <div className="flex items-center gap-1 text-xs text-gray-400">
              <div className={`w-2 h-2 rounded-full ${currentSlide === 0 ? 'bg-[#f0b90b]' : 'bg-gray-600'}`}></div>
              <div className={`w-2 h-2 rounded-full ${currentSlide === 1 ? 'bg-[#f0b90b]' : 'bg-gray-600'}`}></div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {currentSlide === 0 && (
              <button
                onClick={downloadImage}
                className="p-2 hover:bg-gray-700 rounded-lg transition-colors"
                title="Download Image"
              >
                <Download className="w-5 h-5 text-gray-400" />
              </button>
            )}
            <button
              onClick={onClose}
              className="p-2 hover:bg-gray-700 rounded-lg transition-colors"
            >
              <X className="w-5 h-5 text-gray-400" />
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-hidden relative bg-[#0b0e11]">
          <div
            className="flex transition-transform duration-300 h-full"
            style={{ transform: `translateX(-${currentSlide * 100}%)` }}
          >
            <div className="min-w-full h-full">
              {renderShareSlide()}
            </div>
            <div className="min-w-full h-full">
              {renderDetailsSlide()}
            </div>
          </div>
        </div>

        <div className="flex items-center justify-between p-4 border-t border-gray-700">
          <button
            onClick={() => setCurrentSlide(0)}
            disabled={currentSlide === 0}
            className="flex items-center gap-2 px-4 py-2 bg-gray-800 hover:bg-gray-700 disabled:bg-gray-900 disabled:text-gray-600 disabled:cursor-not-allowed text-white rounded-lg transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
            Share View
          </button>
          <div className="text-sm text-gray-400">
            {currentSlide + 1} / 2
          </div>
          <button
            onClick={() => setCurrentSlide(1)}
            disabled={currentSlide === 1}
            className="flex items-center gap-2 px-4 py-2 bg-gray-800 hover:bg-gray-700 disabled:bg-gray-900 disabled:text-gray-600 disabled:cursor-not-allowed text-white rounded-lg transition-colors"
          >
            Details
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}

export default PositionDetailsModal;

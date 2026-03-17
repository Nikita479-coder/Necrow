import { useState } from 'react';
import { X, AlertTriangle, CheckCircle, XCircle } from 'lucide-react';

interface TradeResponseModalProps {
  isOpen: boolean;
  onClose: () => void;
  mode: 'accept' | 'decline';
  trade: {
    pair: string;
    side: 'long' | 'short';
    entry_price: number;
    leverage: number;
  };
  allocatedAmount: number;
  onConfirm: (riskAcknowledged: boolean, declineReason?: string) => Promise<void>;
}

export default function TradeResponseModal({
  isOpen,
  onClose,
  mode,
  trade,
  allocatedAmount,
  onConfirm
}: TradeResponseModalProps) {
  const [riskAcknowledged, setRiskAcknowledged] = useState(false);
  const [declineReason, setDeclineReason] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const handleConfirm = async () => {
    if (mode === 'accept' && !riskAcknowledged) {
      return;
    }

    setIsSubmitting(true);
    try {
      await onConfirm(riskAcknowledged, declineReason);
      onClose();
    } catch (error) {
      console.error('Error submitting response:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleClose = () => {
    if (!isSubmitting) {
      setRiskAcknowledged(false);
      setDeclineReason('');
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
      <div className="bg-[#181a20] rounded-xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-800">
          <div className="flex items-center gap-3">
            {mode === 'accept' ? (
              <CheckCircle className="w-6 h-6 text-emerald-400" />
            ) : (
              <XCircle className="w-6 h-6 text-red-400" />
            )}
            <h2 className="text-xl font-bold">
              {mode === 'accept' ? 'Accept Trade' : 'Decline Trade'}
            </h2>
          </div>
          <button
            onClick={handleClose}
            disabled={isSubmitting}
            className="text-gray-400 hover:text-white transition-colors disabled:opacity-50"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6">
          {/* Trade Summary */}
          <div className="bg-[#0b0e11] rounded-lg p-4">
            <div className="text-sm text-gray-400 mb-3">Trade Summary</div>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-gray-400">Pair:</span>
                <span className="text-white font-semibold">{trade.pair}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Entry Price:</span>
                <span className="text-white font-semibold">
                  ${trade.entry_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Leverage:</span>
                <span className="text-[#f0b90b] font-semibold">{trade.leverage}x</span>
              </div>
              <div className="flex justify-between pt-2 border-t border-gray-800">
                <span className="text-gray-400">Your Allocation:</span>
                <span className="text-white font-bold">
                  ${allocatedAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
            </div>
          </div>

          {mode === 'accept' ? (
            <>
              {/* Risk Warning */}
              <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                  <div className="space-y-2 text-sm">
                    <p className="text-red-400 font-semibold">Risk Disclosure</p>
                    <p className="text-gray-300">
                      Cryptocurrency trading involves substantial risk of loss. The high degree of leverage can work against you as well as for you.
                    </p>
                    <p className="text-gray-300">
                      Before deciding to trade, you should carefully consider your investment objectives, level of experience, and risk appetite.
                    </p>
                    <p className="text-gray-300">
                      <strong>You may lose some or all of your allocated investment.</strong> Past performance is not indicative of future results.
                    </p>
                  </div>
                </div>
              </div>

              {/* Risk Acknowledgment Checkbox */}
              <label className="flex items-start gap-3 cursor-pointer p-4 bg-[#0b0e11] rounded-lg border-2 border-gray-800 hover:border-[#f0b90b]/30 transition-colors">
                <input
                  type="checkbox"
                  checked={riskAcknowledged}
                  onChange={(e) => setRiskAcknowledged(e.target.checked)}
                  disabled={isSubmitting}
                  className="w-5 h-5 mt-0.5 rounded border-gray-700 bg-[#0b0e11] text-[#f0b90b] focus:ring-[#f0b90b] focus:ring-offset-0"
                />
                <span className="text-sm text-gray-300">
                  I understand and acknowledge the risks involved in cryptocurrency trading. I confirm that I have read and understood the risk disclosure above, and I accept full responsibility for any gains or losses that may result from this trade.
                </span>
              </label>
            </>
          ) : (
            <>
              {/* Decline Reason */}
              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Reason for declining (optional)
                </label>
                <textarea
                  value={declineReason}
                  onChange={(e) => setDeclineReason(e.target.value)}
                  disabled={isSubmitting}
                  placeholder="e.g., Market conditions, portfolio rebalancing, risk management..."
                  rows={4}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white text-sm outline-none focus:border-[#f0b90b] transition-colors resize-none disabled:opacity-50"
                />
                <p className="text-xs text-gray-500 mt-2">
                  Your reason helps the trader understand your trading preferences
                </p>
              </div>

              {/* Decline Confirmation */}
              <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-4">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                  <div className="text-sm">
                    <p className="text-blue-400 font-semibold mb-1">Declining This Trade</p>
                    <p className="text-gray-300">
                      By declining, no funds will be allocated to this trade. You will continue to receive future trade signals from this trader.
                    </p>
                  </div>
                </div>
              </div>
            </>
          )}

          {/* Action Buttons */}
          <div className="flex gap-3 pt-4">
            <button
              onClick={handleClose}
              disabled={isSubmitting}
              className="flex-1 bg-[#2b3139] hover:bg-[#3b4149] disabled:bg-gray-800 disabled:cursor-not-allowed text-white font-semibold py-3 rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleConfirm}
              disabled={isSubmitting || (mode === 'accept' && !riskAcknowledged)}
              className={`flex-1 font-semibold py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                mode === 'accept'
                  ? 'bg-emerald-600 hover:bg-emerald-700 text-white'
                  : 'bg-red-600 hover:bg-red-700 text-white'
              }`}
            >
              {isSubmitting ? (
                'Processing...'
              ) : mode === 'accept' ? (
                'Confirm & Accept'
              ) : (
                'Confirm Decline'
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

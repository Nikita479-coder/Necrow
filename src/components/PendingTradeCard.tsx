import { useState, useEffect } from 'react';
import { Clock, AlertCircle, Lock } from 'lucide-react';
import CryptoIcon from './CryptoIcon';

interface PendingTradeCardProps {
  trade: {
    id: string;
    trader_id: string;
    trader_name: string;
    trader_avatar: string;
    pair: string;
    side: 'long' | 'short';
    entry_price: number;
    quantity: number;
    leverage: number;
    margin_used: number;
    margin_percentage: number;
    expires_at: string;
    notes?: string;
  };
  allocatedAmount: number;
  followerLeverage: number;
  onAccept: () => void;
  onDecline: () => void;
  disabled?: boolean;
}

export default function PendingTradeCard({
  trade,
  allocatedAmount,
  followerLeverage,
  onAccept,
  onDecline,
  disabled = false
}: PendingTradeCardProps) {
  const [timeRemaining, setTimeRemaining] = useState<number>(0);
  const [urgencyLevel, setUrgencyLevel] = useState<'safe' | 'warning' | 'critical'>('safe');

  useEffect(() => {
    const calculateTimeRemaining = () => {
      const expiresAt = new Date(trade.expires_at).getTime();
      const now = Date.now();
      const remaining = Math.max(0, expiresAt - now);
      setTimeRemaining(remaining);

      // Determine urgency level for 5-minute window
      const minutes = remaining / 1000 / 60;
      if (minutes <= 1) {
        setUrgencyLevel('critical');
      } else if (minutes <= 3) {
        setUrgencyLevel('warning');
      } else {
        setUrgencyLevel('safe');
      }
    };

    calculateTimeRemaining();
    const interval = setInterval(calculateTimeRemaining, 1000);

    return () => clearInterval(interval);
  }, [trade.expires_at]);

  const formatTimeRemaining = (ms: number): string => {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  const urgencyColors = {
    safe: 'text-emerald-400 bg-emerald-500/20',
    warning: 'text-yellow-400 bg-yellow-500/20',
    critical: 'text-red-400 bg-red-500/20'
  };

  const urgencyBorders = {
    safe: 'border-emerald-500/30',
    warning: 'border-yellow-500/30',
    critical: 'border-red-500/30'
  };

  const symbol = trade.pair.split('/')[0];
  const isExpired = timeRemaining === 0;

  return (
    <div className={`bg-[#181a20] border rounded-xl p-6 transition-all ${
      isExpired ? 'border-gray-800 opacity-50' : urgencyBorders[urgencyLevel]
    }`}>
      {/* Header with Trader Info and Timer */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-[#f0b90b] rounded-full flex items-center justify-center text-xl">
            {trade.trader_avatar}
          </div>
          <div>
            <div className="font-semibold text-white">{trade.trader_name}</div>
            <div className="text-xs text-gray-400">New Trade Signal</div>
          </div>
        </div>

        <div className={`flex items-center gap-2 px-3 py-1.5 rounded-lg ${urgencyColors[urgencyLevel]}`}>
          <Clock className="w-4 h-4" />
          <span className="font-mono font-bold">
            {isExpired ? 'EXPIRED' : formatTimeRemaining(timeRemaining)}
          </span>
        </div>
      </div>

      {/* Trade Details */}
      <div className="bg-[#0b0e11] rounded-lg p-4 mb-4">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-3">
            <CryptoIcon symbol={symbol} size={32} />
            <div>
              <div className="font-bold text-white text-lg">{trade.pair}</div>
              <div className="flex items-center gap-2">
                <Lock className="w-4 h-4 text-gray-500" />
                <span className="text-sm text-gray-500">
                  Strategy Protected
                </span>
                <span className="text-sm text-gray-400">•</span>
                <span className="text-sm font-semibold text-[#f0b90b]">{trade.leverage}x</span>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <div className="text-xs text-gray-400 mb-1">Entry Price</div>
            <div className="text-white font-semibold">
              ${trade.entry_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </div>
          </div>
          <div>
            <div className="text-xs text-gray-400 mb-1">Position Size</div>
            <div className="text-white font-semibold">
              {trade.margin_percentage.toFixed(1)}% of balance
            </div>
          </div>
          <div>
            <div className="text-xs text-gray-400 mb-1">Leverage</div>
            <div className="text-[#f0b90b] font-bold">
              {trade.leverage}x
            </div>
          </div>
          <div>
            <div className="text-xs text-gray-400 mb-1">Your Allocation</div>
            <div className="text-white font-semibold">
              ${allocatedAmount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </div>
          </div>
        </div>

        <div className="mt-3 pt-3 border-t border-gray-800">
          <div className="flex items-start gap-2 text-xs text-gray-400">
            <Lock className="w-3 h-3 mt-0.5 flex-shrink-0" />
            <p>
              Trade direction and details will be revealed after acceptance. You will use {trade.margin_percentage.toFixed(1)}% of your balance, same as the trader.
            </p>
          </div>
        </div>
      </div>

      {/* Risk Warning */}
      {!isExpired && (
        <div className="flex items-start gap-2 mb-4 p-3 bg-yellow-500/10 border border-yellow-500/20 rounded-lg">
          <AlertCircle className="w-4 h-4 text-yellow-400 mt-0.5 flex-shrink-0" />
          <div className="text-xs text-yellow-400">
            Cryptocurrency trading carries significant risk. You may lose part or all of your allocated funds.
          </div>
        </div>
      )}

      {/* Action Buttons */}
      {!isExpired && (
        <div className="flex gap-3">
          <button
            onClick={onAccept}
            disabled={disabled}
            className="flex-1 bg-emerald-600 hover:bg-emerald-700 disabled:bg-gray-700 disabled:cursor-not-allowed text-white font-semibold py-3 rounded-lg transition-colors"
          >
            Accept Trade
          </button>
          <button
            onClick={onDecline}
            disabled={disabled}
            className="flex-1 bg-[#2b3139] hover:bg-[#3b4149] disabled:bg-gray-800 disabled:cursor-not-allowed text-white font-semibold py-3 rounded-lg transition-colors"
          >
            Decline
          </button>
        </div>
      )}

      {isExpired && (
        <div className="text-center py-3 text-gray-500 font-medium">
          This trade opportunity has expired
        </div>
      )}
    </div>
  );
}

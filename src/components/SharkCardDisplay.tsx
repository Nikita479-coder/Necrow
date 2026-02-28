import { CreditCard, Copy, Eye, EyeOff } from 'lucide-react';
import { useState } from 'react';
import CardTransactionsTable from './CardTransactionsTable';

interface SharkCardDisplayProps {
  cardNumber: string;
  cardholderName: string;
  expiryMonth: string;
  expiryYear: string;
  cvv: string;
  cardType: 'standard' | 'gold' | 'platinum';
  walletBalance?: number;
  cardId?: string;
  onCopyNumber?: () => void;
}

export default function SharkCardDisplay({
  cardNumber,
  cardholderName,
  expiryMonth,
  expiryYear,
  cvv,
  cardType,
  walletBalance,
  cardId,
  onCopyNumber
}: SharkCardDisplayProps) {
  const [showFullNumber, setShowFullNumber] = useState(false);
  const [showCVV, setShowCVV] = useState(false);

  const formatCardNumber = (number: string) => {
    if (!showFullNumber) {
      return `•••• •••• •••• ${number.slice(-4)}`;
    }
    return number.match(/.{1,4}/g)?.join(' ') || number;
  };

  const getCardGradient = () => {
    switch (cardType) {
      case 'platinum':
        return 'bg-gradient-to-br from-gray-800 via-gray-700 to-gray-900';
      case 'gold':
        return 'bg-gradient-to-br from-[#f0b90b] via-[#f8d12f] to-[#f0b90b]';
      default:
        return 'bg-gradient-to-br from-blue-600 via-blue-700 to-blue-800';
    }
  };

  const getTextColor = () => {
    return cardType === 'gold' ? 'text-black' : 'text-white';
  };

  const getLabelColor = () => {
    return cardType === 'gold' ? 'text-black/70' : 'text-white/70';
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    if (onCopyNumber) onCopyNumber();
  };

  return (
    <div className="space-y-6">
      <div className={`relative w-full max-w-md aspect-[1.586/1] rounded-2xl ${getCardGradient()} p-6 shadow-2xl transform hover:scale-105 transition-transform duration-300`}>
        <div className="absolute inset-0 bg-gradient-to-br from-white/10 to-transparent rounded-2xl"></div>

        <div className="relative h-full flex flex-col justify-between">
          <div className="flex items-start justify-between">
            <div>
              <div className={`text-xs font-semibold ${getLabelColor()} mb-1`}>SHARK CARD</div>
              <div className={`text-lg font-bold ${getTextColor()} uppercase tracking-wider`}>
                {cardType}
              </div>
            </div>
            <div className={`w-12 h-12 rounded-full ${cardType === 'gold' ? 'bg-black/10' : 'bg-white/10'} flex items-center justify-center`}>
              <CreditCard className={`w-6 h-6 ${getTextColor()}`} />
            </div>
          </div>

          <div className="space-y-4">
            <div>
              <div className={`text-xs ${getLabelColor()} mb-2`}>CARD NUMBER</div>
              <div className={`text-xl md:text-2xl font-mono font-bold ${getTextColor()} tracking-wider`}>
                {formatCardNumber(cardNumber)}
              </div>
            </div>

            <div className="flex items-end justify-between">
              <div>
                <div className={`text-xs ${getLabelColor()} mb-1`}>CARDHOLDER</div>
                <div className={`text-sm md:text-base font-semibold ${getTextColor()} uppercase tracking-wide`}>
                  {cardholderName}
                </div>
              </div>

              <div className="flex gap-6">
                <div>
                  <div className={`text-xs ${getLabelColor()} mb-1`}>EXPIRES</div>
                  <div className={`text-sm md:text-base font-mono font-semibold ${getTextColor()}`}>
                    {expiryMonth}/{expiryYear}
                  </div>
                </div>
                <div>
                  <div className={`text-xs ${getLabelColor()} mb-1`}>CVV</div>
                  <div className={`text-sm md:text-base font-mono font-semibold ${getTextColor()}`}>
                    {showCVV ? cvv : '•••'}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="absolute top-1/2 right-0 w-32 h-32 bg-white/5 rounded-full transform translate-x-16 -translate-y-1/2"></div>
        <div className="absolute bottom-0 left-0 w-24 h-24 bg-white/5 rounded-full transform -translate-x-12 translate-y-12"></div>
      </div>

      {walletBalance !== undefined && (
        <div className="bg-[#1a1d24] border border-gray-800 rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-gray-400 text-sm">Card Wallet Balance</div>
              <div className="text-white text-2xl font-bold">{walletBalance.toLocaleString()} USDT</div>
            </div>
            <div className={`w-12 h-12 rounded-full ${getCardGradient()} flex items-center justify-center`}>
              <CreditCard className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <button
          onClick={() => setShowFullNumber(!showFullNumber)}
          className="flex items-center justify-center gap-2 px-4 py-3 bg-[#1a1d24] hover:bg-[#2b3139] border border-gray-700 rounded-xl text-gray-300 hover:text-white transition-all"
        >
          {showFullNumber ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          <span className="text-sm font-medium">{showFullNumber ? 'Hide' : 'Show'} Number</span>
        </button>

        <button
          onClick={() => setShowCVV(!showCVV)}
          className="flex items-center justify-center gap-2 px-4 py-3 bg-[#1a1d24] hover:bg-[#2b3139] border border-gray-700 rounded-xl text-gray-300 hover:text-white transition-all"
        >
          {showCVV ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          <span className="text-sm font-medium">{showCVV ? 'Hide' : 'Show'} CVV</span>
        </button>

        <button
          onClick={() => copyToClipboard(cardNumber, 'Card number')}
          className="flex items-center justify-center gap-2 px-4 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-xl transition-all"
        >
          <Copy className="w-4 h-4" />
          <span className="text-sm font-medium">Copy Number</span>
        </button>
      </div>

      <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-4">
        <div className="flex items-start gap-3">
          <CreditCard className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
          <div className="text-sm text-yellow-400/90">
            <p className="font-semibold mb-1">Security Notice</p>
            <p className="text-xs">Keep your card details secure. Never share your full card number, CVV, or expiry date with anyone. Shark Trades will never ask for these details via email or chat.</p>
          </div>
        </div>
      </div>

      {cardId && (
        <CardTransactionsTable cardId={cardId} cardNumber={cardNumber} />
      )}
    </div>
  );
}

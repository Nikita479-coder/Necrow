import { useState, useEffect } from 'react';
import { AlertTriangle, X, ExternalLink } from 'lucide-react';
import { useNavigation } from '../App';

function RiskDisclaimerBanner() {
  const [isDismissed, setIsDismissed] = useState(true);
  const { navigateTo } = useNavigation();

  useEffect(() => {
    const dismissed = localStorage.getItem('riskDisclaimerDismissed');
    const dismissedTime = localStorage.getItem('riskDisclaimerDismissedTime');

    if (dismissed === 'true' && dismissedTime) {
      const dismissedDate = new Date(dismissedTime);
      const now = new Date();
      const hoursSinceDismissed = (now.getTime() - dismissedDate.getTime()) / (1000 * 60 * 60);

      if (hoursSinceDismissed < 24) {
        setIsDismissed(true);
        return;
      }
    }

    setIsDismissed(false);
  }, []);

  const handleDismiss = () => {
    setIsDismissed(true);
    localStorage.setItem('riskDisclaimerDismissed', 'true');
    localStorage.setItem('riskDisclaimerDismissedTime', new Date().toISOString());
  };

  if (isDismissed) return null;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 bg-gradient-to-r from-amber-900/95 to-orange-900/95 border-t border-amber-500/30 backdrop-blur-sm">
      <div className="max-w-7xl mx-auto px-4 py-3 sm:py-4">
        <div className="flex items-start sm:items-center gap-3 sm:gap-4">
          <div className="flex-shrink-0 w-8 h-8 sm:w-10 sm:h-10 bg-amber-500/20 rounded-full flex items-center justify-center">
            <AlertTriangle className="w-4 h-4 sm:w-5 sm:h-5 text-amber-400" />
          </div>

          <div className="flex-1 min-w-0">
            <p className="text-white text-xs sm:text-sm font-medium">
              <span className="text-amber-400 font-bold">Risk Warning:</span>{' '}
              <span className="hidden sm:inline">
                Trading cryptocurrencies and derivatives involves significant risk of loss and is not suitable for all investors.
                The value of digital assets can be extremely volatile. Never invest more than you can afford to lose.
                Past performance is not indicative of future results.
              </span>
              <span className="sm:hidden">
                Cryptocurrency trading involves significant risk. Never invest more than you can afford to lose.
              </span>
            </p>

            <div className="flex items-center gap-4 mt-2">
              <button
                onClick={() => navigateTo('legal')}
                className="text-amber-400 hover:text-amber-300 text-xs sm:text-sm font-medium flex items-center gap-1 transition-colors"
              >
                Risk Disclosure
                <ExternalLink className="w-3 h-3" />
              </button>
              <span className="text-amber-500/50 text-xs hidden sm:inline">|</span>
              <span className="text-amber-200/60 text-xs hidden sm:inline">
                18+ only. Services not available in restricted jurisdictions.
              </span>
            </div>
          </div>

          <button
            onClick={handleDismiss}
            className="flex-shrink-0 p-1.5 sm:p-2 hover:bg-white/10 rounded-lg transition-colors"
            aria-label="Dismiss risk warning"
          >
            <X className="w-4 h-4 sm:w-5 sm:h-5 text-white/60 hover:text-white" />
          </button>
        </div>
      </div>
    </div>
  );
}

export default RiskDisclaimerBanner;

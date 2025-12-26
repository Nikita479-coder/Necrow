import React, { useEffect, useRef, useState } from 'react';
import { TOP_CRYPTO_PAIRS, CFD_INSTRUMENTS } from '../../constants/tradingPairs';

interface TradingChartProps {
  pair: string;
}

declare global {
  interface Window {
    TradingView: {
      widget: any;
    };
  }
}

const TradingChart: React.FC<TradingChartProps> = ({ pair }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const widgetRef = useRef<any>(null);

  const formatSymbolForTradingView = (symbol: string) => {
    const cryptoPair = TOP_CRYPTO_PAIRS.find(p => p.symbol === symbol);
    if (cryptoPair) {
      return `BYBIT:${symbol}`;
    }

    if (symbol.endsWith('USDT')) {
      return `BYBIT:${symbol}`;
    }

    const cfdInstrument = CFD_INSTRUMENTS.find(instrument => instrument.symbol === symbol);
    if (cfdInstrument) {
      if (cfdInstrument.type === 'forex') {
        const tvSymbol = symbol.replace('/', '');
        return tvSymbol;
      } else if (cfdInstrument.type === 'stock') {
        return symbol;
      } else if (cfdInstrument.type === 'commodity') {
        switch (symbol) {
          case 'XAUUSD':
          case 'XAU/USD':
            return 'XAUUSD';

          case 'XAGUSD':
          case 'XAG/USD':
            return 'XAGUSD';

          case 'XPTUSD':
          case 'XPT/USD':
            return 'XPTUSD';

          case 'XPDUSD':
          case 'XPD/USD':
            return 'XPDUSD';

          case 'WTICOUSD':
          case 'WTI/USD':
          case 'WTICO/USD':
            return 'OANDA:WTICOUSD';

          case 'BCOUSD':
          case 'Brent Crude':
            return 'TVC:UKOIL';

          case 'NATGASUSD':
          case 'NATGAS/USD':
          case 'Natural Gas':
            return 'OANDA:NATGASUSD';

          case 'CORNUSD':
            return 'ZW1!';

          case 'SOYBNUSD':
          case 'Soybean':
            return 'CBOT:ZS1!';

          default:
            return symbol;
        }
      }
    }

    if (symbol.endsWith('USDT')) {
      return symbol;
    }

    return symbol;
  };

  useEffect(() => {
    if (!pair) {
      setError('No trading pair selected');
      setIsLoading(false);
      return;
    }

    setError(null);
    setIsLoading(false);

    if (widgetRef.current) {
      try {
        widgetRef.current.remove();
      } catch (e) {
        console.warn('Error removing previous widget:', e);
      }
      widgetRef.current = null;
    }

    if (containerRef.current) {
      containerRef.current.innerHTML = '';
    }

    const loadTradingViewWidget = () => {
      if (!containerRef.current) {
        setError('Chart container not available');
        setIsLoading(false);
        return;
      }

      try {
        const tradingViewSymbol = formatSymbolForTradingView(pair);
        console.log('Creating TradingView widget for symbol:', tradingViewSymbol);

        widgetRef.current = new window.TradingView.widget({
          width: '100%',
          height: '100%',
          symbol: tradingViewSymbol,
          interval: '15',
          timezone: 'Etc/UTC',
          theme: 'dark',
          style: '1',
          locale: 'en',
          enable_publishing: false,
          allow_symbol_change: true,
          container_id: containerRef.current.id,
          toolbar_bg: '#0b0e11',
          withdateranges: true,
          hide_side_toolbar: false,
          hide_top_toolbar: false,
          save_image: true,
          studies: ['Volume@tv-basicstudies'],
          show_popup_button: true,
          popup_width: '1000',
          popup_height: '650',
          loading_screen: {
            backgroundColor: '#0b0e11',
            foregroundColor: '#0ecb81'
          },
          overrides: {
            'paneProperties.background': '#0b0e11',
            'paneProperties.backgroundType': 'solid',
            'paneProperties.vertGridProperties.color': '#1a1d22',
            'paneProperties.horzGridProperties.color': '#1a1d22',
            'paneProperties.crossHairProperties.color': 'rgba(255,255,255,0.25)',
            'mainSeriesProperties.candleStyle.upColor': '#0ecb81',
            'mainSeriesProperties.candleStyle.downColor': '#f6465d',
            'mainSeriesProperties.candleStyle.borderUpColor': '#0ecb81',
            'mainSeriesProperties.candleStyle.borderDownColor': '#f6465d',
            'mainSeriesProperties.candleStyle.wickUpColor': '#0ecb81',
            'mainSeriesProperties.candleStyle.wickDownColor': '#f6465d',
            'mainSeriesProperties.showPriceLine': true,
            'scalesProperties.lineColor': '#2b2e35',
            'scalesProperties.textColor': '#787b86',
            'symbolWatermarkProperties.transparency': 90,
          },
          studies_overrides: {
            'volume.volume.color.0': 'rgba(246, 70, 93, 0.6)',
            'volume.volume.color.1': 'rgba(14, 203, 129, 0.6)',
            'volume.volume.transparency': 65,
          },
          onChartReady: () => {
            console.log('TradingView chart ready for', pair);
            setIsLoading(false);
          },
          onLoadError: (error: any) => {
            console.error('TradingView chart load error:', error);
            setError('Failed to load chart');
            setIsLoading(false);
          }
        });

        const fallbackTimeout = setTimeout(() => {
          console.log('TradingView chart fallback timeout - hiding loading state');
          setIsLoading(false);
        }, 2000);

        widgetRef.current._fallbackTimeout = fallbackTimeout;

      } catch (err) {
        console.error('Error creating TradingView widget:', err);
        setError('Failed to create chart widget');
        setIsLoading(false);
      }
    };

    if (window.TradingView) {
      loadTradingViewWidget();
    } else {
      const script = document.createElement('script');
      script.type = 'text/javascript';
      script.src = 'https://s3.tradingview.com/tv.js';
      script.async = true;

      script.onload = () => {
        console.log('TradingView library loaded');
        loadTradingViewWidget();
      };

      script.onerror = () => {
        console.error('Failed to load TradingView library');
        setError('Failed to load TradingView library');
        setIsLoading(false);
      };

      document.head.appendChild(script);
    }

    return () => {
      if (widgetRef.current) {
        try {
          if (widgetRef.current._fallbackTimeout) {
            clearTimeout(widgetRef.current._fallbackTimeout);
          }
          widgetRef.current.remove();
        } catch (e) {
          console.warn('Error cleaning up widget:', e);
        }
        widgetRef.current = null;
      }
    };
  }, [pair]);

  return (
    <div className="bg-[#0b0e11] min-h-[600px] h-full relative overflow-hidden">
      {error && (
        <div className="absolute inset-0 flex items-center justify-center bg-[#0b0e11]/80 z-10">
          <div className="text-[#787b86] text-center">
            <p className="mb-2">{error}</p>
            <p className="text-sm">Please select a valid trading pair</p>
          </div>
        </div>
      )}
      {isLoading && !error && (
        <div className="absolute inset-0 flex items-center justify-center bg-[#0b0e11]/80 z-10">
          <div className="text-[#787b86] text-center">
            <div className="w-8 h-8 border-2 border-[#0ecb81] border-t-transparent rounded-full animate-spin mx-auto mb-2"></div>
            <p>Loading TradingView Chart...</p>
          </div>
        </div>
      )}
      <div
        ref={containerRef}
        id={`tradingview_${pair.replace(/[^a-zA-Z0-9]/g, '_')}_${Date.now()}`}
        className="h-full w-full"
      />
    </div>
  );
};

export default TradingChart;

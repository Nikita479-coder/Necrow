import { supabase } from '../lib/supabase';

type PriceData = {
  symbol: string;
  price: number;
  change24h: number;
  high24h: number;
  low24h: number;
  volume24h: number;
  lastUpdate: number;
};

type Subscriber = (prices: Map<string, PriceData>) => void;

class PriceStore {
  private prices: Map<string, PriceData> = new Map();
  private subscribers: Set<Subscriber> = new Set();
  private ws: WebSocket | null = null;
  private reconnectTimer: number | null = null;
  private subscribedSymbols: Set<string> = new Set();

  constructor() {
    this.loadInitialPrices();
    this.connect();
  }

  private async loadInitialPrices() {
    try {
      const { data, error } = await supabase
        .from('market_prices')
        .select('pair, mark_price');

      if (!error && data) {
        data.forEach(item => {
          const symbol = item.pair.replace('USDT', '');
          const price = parseFloat(item.mark_price);

          const priceData: PriceData = {
            symbol: item.pair,
            price: price,
            change24h: 0,
            high24h: price,
            low24h: price,
            volume24h: 0,
            lastUpdate: Date.now()
          };

          this.prices.set(item.pair, priceData);
          this.prices.set(symbol, priceData);
          this.prices.set(`${symbol}/USDT`, priceData);
        });

        this.notifySubscribers();
      }
    } catch (error) {
      console.error('Error loading initial prices:', error);
    }
  }

  private connect() {
    try {
      this.ws = new WebSocket('wss://stream.bybit.com/v5/public/spot');

      this.ws.onopen = () => {
        console.log('Bybit WebSocket connected');
        this.subscribeToSymbols();
      };

      this.ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);

          if (data.topic && data.topic.startsWith('tickers.')) {
            const tickerData = data.data;
            const symbol = tickerData.symbol.replace('USDT', '/USDT');

            const priceData: PriceData = {
              symbol,
              price: parseFloat(tickerData.lastPrice),
              change24h: parseFloat(tickerData.price24hPcnt) * 100,
              high24h: parseFloat(tickerData.highPrice24h),
              low24h: parseFloat(tickerData.lowPrice24h),
              volume24h: parseFloat(tickerData.volume24h),
              lastUpdate: Date.now()
            };

            const baseSymbol = symbol.split('/')[0];
            this.prices.set(symbol, priceData);
            this.prices.set(baseSymbol, priceData);
            this.prices.set(tickerData.symbol, priceData);
            this.notifySubscribers();
          }
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
        }
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
      };

      this.ws.onclose = () => {
        console.log('WebSocket disconnected, reconnecting...');
        this.reconnectTimer = setTimeout(() => this.connect(), 3000);
      };
    } catch (error) {
      console.error('Error connecting to WebSocket:', error);
      this.reconnectTimer = setTimeout(() => this.connect(), 3000);
    }
  }

  private subscribeToSymbols() {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;

    const symbols = [
      'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT', 'XRPUSDT',
      'ADAUSDT', 'DOGEUSDT', 'MATICUSDT', 'DOTUSDT', 'LINKUSDT',
      'AVAXUSDT', 'UNIUSDT', 'ATOMUSDT', 'LTCUSDT', 'ETCUSDT',
      'ALGOUSDT', 'FTMUSDT', 'NEARUSDT', 'APTUSDT', 'ARBUSDT',
      'OPUSDT', 'INJUSDT', 'SUIUSDT', 'TIAUSDT', 'SEIUSDT',
      'PEPEUSDT', 'SHIBUSDT', 'TRXUSDT', 'TONUSDT', 'ICPUSDT',
      'VETUSDT', 'FILUSDT', 'HBARUSDT', 'STXUSDT', 'IMXUSDT',
      'RUNEUSDT', 'USDCUSDT', 'BCHUSDT', 'AAVEUSDT', 'MKRUSDT',
      'WIFUSDT', 'BONKUSDT', 'FLOKIUSDT', 'SANDUSDT', 'MANAUSDT',
      'AXSUSDT', 'GALAUSDT', 'ENJUSDT', 'FETUSDT', 'RENDERUSDT',
      'AGIXUSDT', 'OCEANUSDT', 'GRTUSDT', 'XLMUSDT', 'XMRUSDT',
      'DASHUSDT', 'ZECUSDT', 'CAKEUSDT', 'BSVUSDT', 'JUPUSDT',
      'RAYUSDT', 'ORCAUSDT', 'LRCUSDT', 'METISUSDT', 'STRKUSDT',
      'KAVAUSDT', 'OSMOUSDT', 'JUNOUSDT', 'KSMUSDT', 'WAVESUSDT',
      'ONEUSDT', 'IOTAUSDT', 'NEOUSDT', 'QTUMUSDT', 'ICXUSDT',
      'ONTUSDT', 'ZENUSDT', 'IOTXUSDT', 'RVNUSDT', 'SCUSDT',
      'STORJUSDT', 'ARUSDT', 'ANKRUSDT', 'CELOUST', 'SKLUSDT',
      'MASKUSDT', 'AUDIOUSDT', 'AMPUSDT', 'CVCUSDT', 'OMGUSDT',
      'BANDUSDT', 'NKNUSDT', 'CTSIUSDT', 'WOOUSDT', 'PEOPLEUSDT',
      'JOEUSDT', 'CVXUSDT', 'SPELLUSDT', 'DYDXUSDT', 'LOOKSUSDT',
      'API3USDT', 'TUSDT', 'GLMUSDT', 'PAXGUSDT', 'RBNUSDT',
      'BNTUSDT', 'PERPUSDT', 'ALCXUSDT', 'TRBUSDT', 'BADGERUSDT',
      'SLPUSDT', 'PLAUSDT', 'BOBAUSDT', 'MPLUSDT', 'RADUSDT',
      'TRIBEUSDT', 'FXSUSDT', 'POLSUSDT', 'DAOUSDT', 'C98USDT',
      'ACAUSDT', 'MOVRUSDT', 'SYNUSDT', 'DPIUSDT', 'FLOWUSDT',
      'EGLDUSDT', 'THETAUSDT', 'CHZUSDT', 'MAGICUSDT', 'PRIMEUSDT',
      'BLURUSDT', 'CRVUSDT', 'SUSHIUSDT', 'COMPUSDT', 'YFIUSDT',
      'SNXUSDT', '1INCHUSDT', 'BALUSDT', 'MINAUSDT', 'ROSEUSDT',
      'ZILUSDT', 'ZRXUSDT', 'BATUSDT', 'ENSUSDT', 'LDOUSDT',
      'RPLUSDT', 'APEUSDT', 'GMTUSDT', 'ILVUSDT', 'XTZUSDT',
      'EOSUSDT', 'REEFUSDT', 'OXTUSDT', 'AUCTIONUSDT', 'PYRUSDT',
      'SUPERUSDT', 'UFTUSDT', 'ACHUSDT', 'ERNUSDT', 'CFXUSDT',
      'BICOUSDT', 'AGLDUSDT', 'RAREUSDT', 'LAZIOUSDT', 'SANTOSUSDT',
      'MCUSDT', 'POWRUSDT', 'VGXUSDT', 'NOAIUSDT', 'VITEUSDT',
      'TVKUSDT', 'PSGUSDT', 'CITYUSDT', 'MBLUSDT', 'JUVUSDT',
      'ACMUSDT', 'ASRUSDT', 'ATMUSDT', 'BARUSDT', 'OGUSDT',
      'PORTOUSDT', 'ALPINEUSDT', 'WHALEUSDT', 'NEXOUSDT'
    ];

    symbols.forEach(symbol => {
      this.subscribedSymbols.add(symbol);
      this.ws?.send(JSON.stringify({
        op: 'subscribe',
        args: [`tickers.${symbol}`]
      }));
    });
  }

  subscribe(callback: Subscriber): () => void {
    this.subscribers.add(callback);
    callback(this.prices);

    return () => {
      this.subscribers.delete(callback);
    };
  }

  private notifySubscribers() {
    this.subscribers.forEach(callback => callback(this.prices));
  }

  getPrice(symbol: string): PriceData | undefined {
    return this.prices.get(symbol);
  }

  getAllPrices(): Map<string, PriceData> {
    return this.prices;
  }

  disconnect() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

export const priceStore = new PriceStore();
export type { PriceData };

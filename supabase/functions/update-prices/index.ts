import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface BybitTicker {
  symbol: string;
  lastPrice: string;
  highPrice24h: string;
  lowPrice24h: string;
  volume24h: string;
  price24hPcnt: string;
}

interface BybitResponse {
  retCode: number;
  retMsg: string;
  result: {
    list: BybitTicker[];
  };
}

const TRADING_PAIRS = [
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

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      throw new Error('Missing Supabase environment variables');
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const updatedPairs: string[] = [];
    const errors: string[] = [];

    for (const pair of TRADING_PAIRS) {
      try {
        const url = `https://api.bybit.com/v5/market/tickers?category=spot&symbol=${pair}`;
        const response = await fetch(url);
        
        if (!response.ok) {
          errors.push(`Failed to fetch ${pair}: ${response.statusText}`);
          continue;
        }

        const data: BybitResponse = await response.json();

        if (data.retCode !== 0 || !data.result?.list || data.result.list.length === 0) {
          errors.push(`No data for ${pair}`);
          continue;
        }

        const ticker = data.result.list[0];
        const price = parseFloat(ticker.lastPrice);
        const volume = parseFloat(ticker.volume24h);

        const { error } = await supabase.rpc('update_market_price', {
          p_pair: pair,
          p_price: price,
          p_mark_price: price,
          p_volume: volume
        });

        if (error) {
          errors.push(`DB error for ${pair}: ${error.message}`);
        } else {
          updatedPairs.push(pair);
        }

        await new Promise(resolve => setTimeout(resolve, 100));
      } catch (error) {
        errors.push(`Error processing ${pair}: ${error.message}`);
      }
    }

    const responseData = {
      success: true,
      updated: updatedPairs.length,
      pairs: updatedPairs,
      errors: errors.length > 0 ? errors : undefined,
      timestamp: new Date().toISOString()
    };

    return new Response(
      JSON.stringify(responseData),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error in update-prices function:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});
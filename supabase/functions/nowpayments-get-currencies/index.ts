const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

const NOWPAYMENTS_API_KEY = Deno.env.get('NOWPAYMENTS_API_KEY') || '4XWP250-J9ZMZQR-Q8HD6B2-8TG7SVK';
const NOWPAYMENTS_API_URL = 'https://api.nowpayments.io/v1';

const SUPPORTED_CURRENCIES = [
  // Major Cryptocurrencies
  'btc',      // Bitcoin
  'eth',      // Ethereum
  'ltc',      // Litecoin
  'xrp',      // Ripple
  'bch',      // Bitcoin Cash
  
  // Stablecoins
  'usdt',     // Tether (multiple networks)
  'usdttrc20', // Tether TRC20
  'usdterc20', // Tether ERC20
  'usdtbsc',  // Tether BSC
  'usdtsol',  // Tether Solana
  'usdc',     // USD Coin
  'usdcerc20', // USD Coin ERC20
  'usdcbsc',  // USD Coin BSC
  'usdcsol',  // USD Coin Solana
  'dai',      // DAI
  'busd',     // Binance USD
  'tusd',     // TrueUSD
  
  // Smart Contract Platforms
  'bnb',      // Binance Coin
  'bnbbsc',   // BNB on BSC
  'sol',      // Solana
  'ada',      // Cardano
  'avax',     // Avalanche
  'avaxc',    // Avalanche C-Chain
  'matic',    // Polygon
  'maticpolygon', // MATIC on Polygon
  'dot',      // Polkadot
  'atom',     // Cosmos
  'near',     // NEAR Protocol
  'ftm',      // Fantom
  'algo',     // Algorand
  'xlm',      // Stellar
  'eos',      // EOS
  'trx',      // Tron
  'etc',      // Ethereum Classic
  'xtz',      // Tezos
  'hbar',     // Hedera
  'icp',      // Internet Computer
  'fil',      // Filecoin
  'vet',      // VeChain
  'egld',     // MultiversX (Elrond)
  'one',      // Harmony
  'kava',     // Kava
  'celo',     // Celo
  
  // Meme & Popular Coins
  'doge',     // Dogecoin
  'shib',     // Shiba Inu
  'shibbsc',  // Shiba on BSC
  'pepe',     // Pepe
  'floki',    // Floki Inu
  'bonk',     // Bonk
  
  // DeFi Tokens
  'link',     // Chainlink
  'uni',      // Uniswap
  'aave',     // Aave
  'mkr',      // Maker
  'crv',      // Curve
  'snx',      // Synthetix
  'comp',     // Compound
  'ldo',      // Lido
  'grt',      // The Graph
  '1inch',    // 1inch
  'sushi',    // SushiSwap
  
  // Layer 2 & Scaling
  'arb',      // Arbitrum
  'op',       // Optimism
  
  // Privacy Coins
  'xmr',      // Monero
  'zec',      // Zcash
  'dash',     // Dash
  
  // Exchange Tokens
  'cro',      // Cronos
  'okb',      // OKB
  'gt',       // Gate Token
  
  // Gaming & Metaverse
  'sand',     // The Sandbox
  'mana',     // Decentraland
  'axs',      // Axie Infinity
  'ape',      // ApeCoin
  'gala',     // Gala
  'enj',      // Enjin
  'imx',      // Immutable X
  
  // Other Popular
  'apt',      // Aptos
  'sui',      // Sui
  'sei',      // Sei
  'inj',      // Injective
  'rune',     // THORChain
  'ksm',      // Kusama
  'zil',      // Zilliqa
  'waves',    // Waves
  'neo',      // NEO
  'xem',      // NEM
  'qtum',     // Qtum
  'iota',     // IOTA
  'kcs',      // KuCoin Token
  'cake',     // PancakeSwap
];

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    console.log('Fetching currencies from NOWPayments...');

    try {
      const nowpaymentsResponse = await fetch(`${NOWPAYMENTS_API_URL}/currencies`, {
        method: 'GET',
        headers: {
          'x-api-key': NOWPAYMENTS_API_KEY,
        },
      });

      if (nowpaymentsResponse.ok) {
        const data = await nowpaymentsResponse.json();
        if (data.currencies && Array.isArray(data.currencies)) {
          const availableCurrencies = data.currencies.filter((c: string) => 
            SUPPORTED_CURRENCIES.includes(c.toLowerCase())
          );
          
          if (availableCurrencies.length > 0) {
            return new Response(
              JSON.stringify({
                success: true,
                currencies: availableCurrencies,
                total: availableCurrencies.length,
              }),
              { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
          }
        }
      }
    } catch (apiError) {
      console.error('NOWPayments API error:', apiError);
    }

    return new Response(
      JSON.stringify({
        success: true,
        currencies: SUPPORTED_CURRENCIES,
        total: SUPPORTED_CURRENCIES.length,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error in nowpayments-get-currencies:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
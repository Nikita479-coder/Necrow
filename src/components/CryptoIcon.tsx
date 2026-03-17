import { useState } from 'react';

interface CryptoIconProps {
  symbol: string;
  className?: string;
  size?: number;
}

const BRAND_COLORS: Record<string, string> = {
  'BTC': '#F7931A',
  'ETH': '#627EEA',
  'BNB': '#F3BA2F',
  'SOL': '#14F195',
  'XRP': '#23292F',
  'ADA': '#0033AD',
  'DOGE': '#C3A634',
  'DOT': '#E6007A',
  'MATIC': '#8247E5',
  'AVAX': '#E84142',
  'LINK': '#2A5ADA',
  'UNI': '#FF007A',
  'ATOM': '#2E3148',
  'LTC': '#345D9D',
  'USDT': '#26A17B',
  'USDC': '#2775CA',
  'SHIB': '#FFA409',
  'TRX': '#FF0013',
  'NEAR': '#00C08B',
  'APT': '#000000',
  'ARB': '#28A0F0',
  'OP': '#FF0420',
  'FTM': '#1969FF',
  'ALGO': '#000000',
  'ICP': '#29ABE2',
  'FIL': '#0090FF',
  'AAVE': '#B6509E',
  'MKR': '#1AAB9B',
  'PEPE': '#479F53',
  'SAND': '#04ADEF',
  'MANA': '#FF2D55',
  'AXS': '#0055D5',
  'GALA': '#000000',
  'FET': '#1D2951',
  'GRT': '#6747ED',
  'XLM': '#000000',
  'XMR': '#FF6600',
  'CAKE': '#D1884F',
  'INJ': '#00F2FE',
  'SUI': '#4DA2FF',
  'SEI': '#9B1C1C',
  'TIA': '#7B2BF9',
  'RUNE': '#33FF99',
  'STX': '#5546FF',
  'FLOW': '#00EF8B',
  'THETA': '#2AB8E6',
  'CHZ': '#CD0124',
  'CRV': '#0000FF',
  'SUSHI': '#FA52A0',
  'SNX': '#00D1FF',
  'ENS': '#5298FF',
  'LDO': '#00A3FF',
  'APE': '#0047FF',
  'DAI': '#F4B731',
  'COMP': '#00D395',
  'YFI': '#006AE3',
  'BAT': '#FF5000',
  'ZRX': '#000000',
  'KSM': '#000000',
  'XTZ': '#2C7DF7',
  'EOS': '#000000',
  'NEO': '#00E599',
  'AR': '#222326',
  'ANKR': '#2E6BED',
  'CELO': '#FCFF52',
  'MASK': '#1C68F3',
  'DYDX': '#6966FF',
  'CFX': '#1A1A1A',
  'NEXO': '#1A4199',
  'MLN': '#0B1529',
  'ALCX': '#F5C09A',
  'TRU': '#1A5AFF',
  'ZBT': '#3B82F6',
  'YB': '#6366F1',
  'ENSO': '#8B5CF6',
  'TON': '#0098EA',
  'EAT': '#F7931A',
  'HBAR': '#3A3A3A',
  'VET': '#15BDFF',
  'IMX': '#1B9EE8',
};

function getImageSources(symbol: string): string[] {
  const lower = symbol.toLowerCase();
  const upper = symbol.toUpperCase();
  const cmcId = getMarketCapId(upper);

  const sources: string[] = [];

  if (cmcId) {
    sources.push(`https://s2.coinmarketcap.com/static/img/coins/64x64/${cmcId}.png`);
  }

  sources.push(
    `https://assets.coincap.io/assets/icons/${lower}@2x.png`,
    `https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/${lower}.png`,
    `https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/128/color/${lower}.png`,
    `https://cryptologos.cc/logos/${getCryptoLogosName(lower)}-${lower}-logo.png`
  );

  return sources;
}

function getCryptoLogosName(symbol: string): string {
  const names: Record<string, string> = {
    'btc': 'bitcoin',
    'eth': 'ethereum',
    'usdt': 'tether',
    'usdc': 'usd-coin',
    'bnb': 'bnb',
    'sol': 'solana',
    'xrp': 'xrp',
    'ada': 'cardano',
    'doge': 'dogecoin',
    'dot': 'polkadot-new',
    'matic': 'polygon',
    'ltc': 'litecoin',
    'avax': 'avalanche',
    'link': 'chainlink',
    'atom': 'cosmos',
    'uni': 'uniswap',
    'shib': 'shiba-inu',
    'trx': 'tron',
    'near': 'near-protocol',
    'apt': 'aptos',
    'arb': 'arbitrum',
    'op': 'optimism',
    'ftm': 'fantom',
    'algo': 'algorand',
    'icp': 'internet-computer',
    'fil': 'filecoin',
    'aave': 'aave',
    'mkr': 'maker',
    'pepe': 'pepe',
    'inj': 'injective',
    'sui': 'sui',
    'sei': 'sei',
    'tia': 'celestia',
    'rune': 'thorchain',
    'stx': 'stacks',
    'ton': 'toncoin',
    'imx': 'immutable-x',
    'hbar': 'hedera',
    'vet': 'vechain',
    'dai': 'multi-collateral-dai',
  };
  return names[symbol] || symbol;
}

const MARKET_CAP_IDS: Record<string, string> = {
  'BTC': '1',
  'ETH': '1027',
  'USDT': '825',
  'BNB': '1839',
  'SOL': '5426',
  'XRP': '52',
  'USDC': '3408',
  'ADA': '2010',
  'DOGE': '74',
  'TRX': '1958',
  'AVAX': '5805',
  'LINK': '1975',
  'DOT': '6636',
  'MATIC': '3890',
  'LTC': '2',
  'SHIB': '5994',
  'BCH': '1831',
  'UNI': '7083',
  'ATOM': '3794',
  'ETC': '1321',
  'NEAR': '6535',
  'APT': '21794',
  'ARB': '11841',
  'OP': '11840',
  'FTM': '3513',
  'ALGO': '4030',
  'VET': '3077',
  'ICP': '8916',
  'FIL': '2280',
  'HBAR': '4642',
  'AAVE': '7278',
  'MKR': '1518',
  'PEPE': '24478',
  'WIF': '28752',
  'BONK': '23095',
  'FLOKI': '10804',
  'SAND': '6210',
  'MANA': '1966',
  'AXS': '6783',
  'GALA': '7080',
  'ENJ': '2130',
  'FET': '3773',
  'RENDER': '5690',
  'AGIX': '2424',
  'OCEAN': '3911',
  'GRT': '6719',
  'XLM': '512',
  'XMR': '328',
  'DASH': '131',
  'ZEC': '1437',
  'CAKE': '7186',
  'JUP': '29210',
  'RAY': '8526',
  'IMX': '10603',
  'LRC': '1934',
  'INJ': '7226',
  'SEI': '23149',
  'SUI': '20947',
  'TIA': '22861',
  'STRK': '22691',
  'RUNE': '4157',
  'KAVA': '4846',
  'STX': '4847',
  'TON': '11419',
  'EAT': '1',
  'FLOW': '4558',
  'EGLD': '6892',
  'THETA': '2416',
  'CHZ': '4066',
  'CRV': '6538',
  'SUSHI': '6758',
  'COMP': '5692',
  'YFI': '5864',
  'SNX': '2586',
  '1INCH': '8104',
  'MINA': '8646',
  'ZIL': '2469',
  'KSM': '5034',
  'ZRX': '1896',
  'BAT': '1697',
  'ENS': '13855',
  'LDO': '8000',
  'APE': '18876',
  'GMT': '18069',
  'XTZ': '2011',
  'EOS': '1765',
  'IOTA': '1720',
  'NEO': '1376',
  'AR': '5632',
  'ANKR': '3783',
  'CELO': '5567',
  'MASK': '8536',
  'DYDX': '11156',
  'CFX': '7334',
  'NEXO': '2694',
  'MLN': '1552',
  'ALCX': '8613',
  'TRU': '7725',
  'DAI': '4943',
};

function getMarketCapId(symbol: string): string {
  return MARKET_CAP_IDS[symbol] || '';
}

function CryptoIcon({ symbol, className = '', size = 32 }: CryptoIconProps) {
  const [currentSourceIndex, setCurrentSourceIndex] = useState(0);
  const [imageError, setImageError] = useState(false);
  const [imageLoaded, setImageLoaded] = useState(false);

  if (!symbol) {
    return (
      <div
        className={`flex items-center justify-center bg-[#2b3139] rounded-full text-[#848e9c] font-semibold ${className}`}
        style={{ width: size, height: size, fontSize: size * 0.4 }}
      >
        ??
      </div>
    );
  }

  const normalizedSymbol = symbol.toUpperCase().replace(/\/USDT$/, '');
  const imageSources = getImageSources(normalizedSymbol);

  if (imageError || currentSourceIndex >= imageSources.length) {
    const bgColor = BRAND_COLORS[normalizedSymbol] || '#2b3139';
    const textColor = ['#F3BA2F', '#14F195', '#C3A634', '#FCFF52', '#00EF8B', '#F4B731', '#F5C09A'].includes(bgColor) ? '#000' : '#fff';

    return (
      <div
        className={`flex items-center justify-center rounded-full font-bold ${className}`}
        style={{
          width: size,
          height: size,
          fontSize: size * 0.35,
          backgroundColor: bgColor,
          color: textColor
        }}
      >
        {normalizedSymbol.slice(0, 3)}
      </div>
    );
  }

  return (
    <div
      className={`relative flex-shrink-0 ${className}`}
      style={{ width: size, height: size }}
    >
      {!imageLoaded && (
        <div
          className="absolute inset-0 flex items-center justify-center text-[#848e9c] font-semibold bg-[#2b3139] rounded-full"
          style={{ fontSize: size * 0.35 }}
        >
          {normalizedSymbol.slice(0, 2)}
        </div>
      )}
      <img
        src={imageSources[currentSourceIndex]}
        alt={normalizedSymbol}
        className={`w-full h-full object-contain transition-opacity duration-200 ${imageLoaded ? 'opacity-100' : 'opacity-0'}`}
        onLoad={() => setImageLoaded(true)}
        onError={() => {
          if (currentSourceIndex < imageSources.length - 1) {
            setCurrentSourceIndex(prev => prev + 1);
          } else {
            setImageError(true);
          }
        }}
      />
    </div>
  );
}

export default CryptoIcon;

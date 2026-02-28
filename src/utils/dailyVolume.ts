function hashDateString(dateStr: string): number {
  let hash = 0;
  for (let i = 0; i < dateStr.length; i++) {
    const char = dateStr.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return Math.abs(hash);
}

function hashToDecimal(hash: number): number {
  const normalized = (hash % 1000000) / 1000000;
  return normalized;
}

export function getDailyPlatformVolume(): number {
  const today = new Date();
  const dateStr = today.toISOString().split('T')[0];
  const hash = hashDateString(dateStr);
  const decimal = hashToDecimal(hash);
  const minVolume = 1.1e9;
  const maxVolume = 1.3e9;
  const volume = minVolume + (decimal * (maxVolume - minVolume));
  return volume;
}

export function formatPlatformVolume(volume: number): string {
  if (volume >= 1e9) {
    return `$${(volume / 1e9).toFixed(1)}B`;
  } else if (volume >= 1e6) {
    return `$${(volume / 1e6).toFixed(1)}M`;
  }
  return `$${volume.toLocaleString()}`;
}

export function getDailyVolumeChange(): number {
  const today = new Date();
  const dateStr = today.toISOString().split('T')[0];
  const hash = hashDateString(dateStr + '-change');
  const decimal = hashToDecimal(hash);
  const minChange = 5;
  const maxChange = 18;
  const change = minChange + (decimal * (maxChange - minChange));
  return change;
}

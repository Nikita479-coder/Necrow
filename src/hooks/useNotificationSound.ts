import { useCallback, useRef, useEffect } from 'react';

const NOTIFICATION_SOUND_DATA = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YVQGAABkAGQAZABkAGQAZABkAGQAZABkAGQAZABjAGIAYQBgAF8AXgBdAFwAWwBaAFkAWABXAFYAVQBUAFMAUgBRAFAAkACQAJAAkACQAJAAkACQAJAAkACQAJAAjwCOAI0AjACLAIoAiQCIAIcAhgCFAIQAgwCCAIEAgAC8ALwAvAC8ALwAvAC8ALwAvAC8ALwAvAC7ALoAuQC4ALcAtgC1ALQAswCyALEAsACvAK4ArQCsAKgAqACnAKcApgClAKQAowCiAKEAoACfAJ4AnQCcAJsAmgCZAJgAlwCWAJUAlACTAJIAkQCRAJAApACkAKMAowCiAKEAoACfAJ4AnQCcAJsAmgCZAJgAlwCWAJUAlACTAJIAkQCQAJAAqQCpAKkAqACnAKcApgClAKQAowCiAKEAoACfAJ4AnQCcAJsAmgCZAJgAlwCWAJUAlACUALQAtAC0ALMAtAC0ALMAtAC0ALMAtAC0ALMAtAC0ALMAtAC0ALMAtAC0ALMAtAC0ALMAtACWAJYAlQCVAJQAkwCSAJEAkACPAI4AjQCMAIsAigCJAIgAhwCGAIUAhACDAIIAgQCAAIAAkgCSAJIAkQCQAI8AjgCNAIwAiwCKAIkAiACHAIYAhQCEAIMAggCBAIAAfwB+AH0AfAB7AHsAigCKAIoAiQCIAIcAhgCFAIQAgwCCAIEAgAB/AH4AfQB8AHsAegB5AHgAdwB2AHUAdABzAHMAggCCAIEAgQCAAH8AfgB9AHwAewB6AHkAeAB3AHYAdQB0AHMAcgBxAHAAcABvAG4AbQBsAGwAfQB8AHsAegB5AHgAdwB2AHUAdABzAHIAcQBwAG8AbgBtAGwAawBqAGkAaABnAGYAZQBlAHkAeAB3AHYAdQB0AHMAcgBxAHAAcABvAG4AbQBsAGsAagBpAGgAZwBmAGUAZABjAGIAYgB3AHYAdQB0AHMAcgBxAHAAcABvAG4AbQBsAGsAagBpAGgAZwBmAGUAZABjAGIAYQBgAGAAeAB3AHYAdQB0AHMAcgBxAHAAcABvAG4AbQBsAGsAagBpAGgAZwBmAGUAZABjAGIAYQBgAGAAfAB7AHoAeQB4AHcAdgB1AHQAcwByAHEAcABwAG8AbgBtAGwAawBqAGkAaABnAGYAZQBkAGQAgwCCAIEAgAB/AH4AfQB8AHsAegB5AHgAdwB2AHUAdABzAHIAcQBwAHAAcABvAG4AbgCMAIsAigCJAIgAhwCGAIUAhACDAIIAgQCAAH8AfgB9AHwAewB6AHkAeAB3AHcAdgB2AJYAlQCUAJMAkgCRAJAAjwCOAI0AjACLAIoAiQCIAIcAhgCFAIQAgwCCAIEAgACAAIAAoACfAJ4AnQCcAJsAmgCZAJgAlwCWAJUAlACTAJIAkQCQAI8AjgCNAIwAiwCKAIoAigCqAKkAqACnAKYApQCkAKMAogChAKAAoACfAJ4AnQCcAJsAmgCZAJgAlwCWAJUAlACUALQAswCyALEAsACvAK4ArQCsAKsAqgCpAKgApwCmAKUApACjAKIAoQCgAKAAnwCeAJ4AvgC9ALwAuwC6ALkAuAC3ALYAtQC0ALMAsQCwAK8ArgCtAKwAqwCqAKkAqACnAKYApgDIAMcAxgDFAMQAwwDCAMEAwAC/AL4AvQC7ALoAuQC4ALcAtgC1ALQAswCyALEAsQDRANAA0ADPAc4BzQHMAcsBygHJAcgBxwHGAcUBwwHCAcEBwAG/Ab4BvQG8AbsBugHZAdgB1wHWAdUB1AHTAdIB0QHQAM8AzgDNAcsBygHJAcgBxwHGAcUBxAHDAcIB4QHgAd8B3gHdAdwB2wHaAdkB2AHXAdYB1QHUAdMB0gHRANAAzwDOAM0AzADLAckB6AHnAeYB5QHkAeMB4gHhAeAB3wHeAd0B3AHbAdoB2QHYAdcB1gHVAdQB0wHSAfAB7wHuAe0B7AHrAeoB6QHoAecB5gHlAeQB4wHiAeEB4AHfAd4B3QHcAdsB2gHZAfQB8wHyAfEB8AHvAe4B7QHsAesB6gHpAegB5wHmAeUB5AHjAeIB4QHgAd8B3gHdAeIB4QHgAd8B3gHdAdwB2wHaAdkB2AHXAdYB1QHUAdMB0gHRAc0BzAHLAckB3gHdAdwB2wHaAdkB2AHXAdYB1QHUAdMB0gHRANAAzwDOAM0AzADLAMoBygHJAcgB1gHVAdQB0wHSANEA0ADPAc4BzQHMAcsBygHJAcgBxwHGAcUBwwHCAcEBwAHNAcwBywHKAdABzwHOAM0AzADLAMoAyQDIAMcAxgDFAMQAwwDCAMEAwAC/AL4AvQC8AL0AvAC7ALoAuQC4ALcAtgC1ALQAswCyALEAsACvAK4ArQCsAKsAqgCpAKgApwCmAKUApACjALQAswCyALEAsACvAK4ArQCsAKsAqgCpAKgApwCmAKUApACjAKIAoQCgAJ8AngCdAJwAmwCrAKoAqQCoAKcApgClAKQAowCiAKEAoACfAJ4AnQCcAJsAmgCZAJgAlwCWAJUAlACTAJIA';

interface UseNotificationSoundOptions {
  enabled?: boolean;
  volume?: number;
}

export function useNotificationSound(options: UseNotificationSoundOptions = {}) {
  const { enabled = true, volume = 0.5 } = options;
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const lastPlayedRef = useRef<number>(0);
  const MIN_INTERVAL = 1000;

  useEffect(() => {
    audioRef.current = new Audio(NOTIFICATION_SOUND_DATA);
    audioRef.current.volume = volume;

    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
    };
  }, [volume]);

  const playSound = useCallback(() => {
    if (!enabled || !audioRef.current) return;

    const now = Date.now();
    if (now - lastPlayedRef.current < MIN_INTERVAL) return;

    lastPlayedRef.current = now;

    audioRef.current.currentTime = 0;
    audioRef.current.play().catch(() => {});
  }, [enabled]);

  return { playSound };
}

export type ConnectionStatus = 'connected' | 'connecting' | 'disconnected';

interface UseRealtimeConnectionOptions {
  onStatusChange?: (status: ConnectionStatus) => void;
}

export function useRealtimeConnection(options: UseRealtimeConnectionOptions = {}) {
  const { onStatusChange } = options;
  const statusRef = useRef<ConnectionStatus>('connecting');

  const updateStatus = useCallback((newStatus: ConnectionStatus) => {
    if (statusRef.current !== newStatus) {
      statusRef.current = newStatus;
      onStatusChange?.(newStatus);
    }
  }, [onStatusChange]);

  return {
    getStatus: () => statusRef.current,
    updateStatus,
  };
}

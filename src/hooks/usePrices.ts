import { useState, useEffect } from 'react';
import { priceStore, PriceData } from '../store/priceStore';

export function usePrices() {
  const [prices, setPrices] = useState<Map<string, PriceData>>(new Map());

  useEffect(() => {
    const unsubscribe = priceStore.subscribe((newPrices) => {
      setPrices(new Map(newPrices));
    });

    return () => {
      unsubscribe();
    };
  }, []);

  return prices;
}

export function usePrice(symbol: string) {
  const prices = usePrices();
  return prices.get(symbol);
}

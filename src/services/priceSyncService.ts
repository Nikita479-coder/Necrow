import { supabase } from '../lib/supabase';
import { priceStore } from '../store/priceStore';

class PriceSyncService {
  private syncInterval: number | null = null;
  private isRunning: boolean = false;
  private consecutiveFailures: number = 0;
  private maxFailures: number = 5;

  start() {
    if (this.isRunning) return;

    this.isRunning = true;
    this.consecutiveFailures = 0;

    this.syncInterval = setInterval(() => {
      this.syncPricesToDatabase();
    }, 5000);

    console.log('Price sync service started');
  }

  stop() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
    this.isRunning = false;
    console.log('Price sync service stopped');
  }

  private async syncPricesToDatabase() {
    if (this.consecutiveFailures >= this.maxFailures) {
      return;
    }

    const prices = priceStore.getAllPrices();

    if (prices.size === 0) {
      return;
    }

    const batchSize = 5;
    const delayBetweenBatches = 100;
    const entries = Array.from(prices.entries());
    let batchFailures = 0;

    for (let i = 0; i < entries.length; i += batchSize) {
      const batch = entries.slice(i, i + batchSize);

      await Promise.all(
        batch.map(async ([symbol, priceData]) => {
          try {
            const pair = symbol.replace('/', '');
            const price = parseFloat(priceData.price);
            const volume = parseFloat(priceData.volume24h);

            if (!isFinite(price) || price <= 0) {
              return;
            }

            if (!isFinite(volume) || volume < 0) {
              return;
            }

            const { error } = await supabase.rpc('update_market_price', {
              p_pair: pair,
              p_price: price,
              p_mark_price: price,
              p_volume: isFinite(volume) ? volume : null
            });

            if (error) {
              batchFailures++;
            }
          } catch (err) {
            batchFailures++;
          }
        })
      );

      if (i + batchSize < entries.length) {
        await new Promise(resolve => setTimeout(resolve, delayBetweenBatches));
      }
    }

    if (batchFailures > entries.length / 2) {
      this.consecutiveFailures++;
    } else {
      this.consecutiveFailures = 0;
    }
  }
}

export const priceSyncService = new PriceSyncService();

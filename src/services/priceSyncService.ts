import { supabase } from '../lib/supabase';
import { priceStore } from '../store/priceStore';

class PriceSyncService {
  private syncInterval: number | null = null;
  private isRunning: boolean = false;
  private consecutiveFailures: number = 0;
  private maxFailures: number = 3;
  private isSyncing: boolean = false;

  start() {
    if (this.isRunning) return;

    this.isRunning = true;
    this.consecutiveFailures = 0;

    // Sync every 60 seconds instead of 5 to reduce load
    this.syncInterval = setInterval(() => {
      this.syncPricesToDatabase();
    }, 60000);

    console.log('Price sync service started (60s interval)');
  }

  stop() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
    this.isRunning = false;
    this.isSyncing = false;
    console.log('Price sync service stopped');
  }

  private async syncPricesToDatabase() {
    // Stop if too many failures or already syncing
    if (this.consecutiveFailures >= this.maxFailures || this.isSyncing) {
      if (this.consecutiveFailures >= this.maxFailures) {
        console.warn('Price sync disabled due to repeated failures');
        this.stop();
      }
      return;
    }

    this.isSyncing = true;

    try {
      const prices = priceStore.getAllPrices();

      if (prices.size === 0) {
        this.isSyncing = false;
        return;
      }

      // Sync only 3 pairs per batch with longer delays
      const batchSize = 3;
      const delayBetweenBatches = 500;
      const entries = Array.from(prices.entries()).slice(0, 30); // Limit to 30 pairs max
      let batchFailures = 0;

      for (let i = 0; i < entries.length; i += batchSize) {
        const batch = entries.slice(i, i + batchSize);

        const results = await Promise.allSettled(
          batch.map(async ([symbol, priceData]) => {
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

            if (error) throw error;
          })
        );

        // Count failures
        batchFailures += results.filter(r => r.status === 'rejected').length;

        // Wait between batches
        if (i + batchSize < entries.length) {
          await new Promise(resolve => setTimeout(resolve, delayBetweenBatches));
        }
      }

      // Update failure counter
      if (batchFailures > entries.length / 2) {
        this.consecutiveFailures++;
      } else {
        this.consecutiveFailures = 0;
      }
    } catch (err) {
      console.error('Price sync error:', err);
      this.consecutiveFailures++;
    } finally {
      this.isSyncing = false;
    }
  }
}

export const priceSyncService = new PriceSyncService();

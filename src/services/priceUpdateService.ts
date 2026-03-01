class PriceUpdateService {
  private intervalId: number | null = null;
  private isRunning: boolean = false;
  private updateInterval: number = 5000;
  private consecutiveFailures: number = 0;
  private maxFailures: number = 3;
  private backoffMultiplier: number = 2;
  private currentInterval: number = 5000;
  private maxInterval: number = 60000;

  start() {
    if (this.isRunning) return;

    this.isRunning = true;
    this.consecutiveFailures = 0;
    this.currentInterval = this.updateInterval;
    this.fetchPrices();

    this.scheduleNext();
    console.log('Price update service started');
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    this.isRunning = false;
    console.log('Price update service stopped');
  }

  private scheduleNext() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }

    if (this.consecutiveFailures >= this.maxFailures) {
      this.currentInterval = Math.min(
        this.currentInterval * this.backoffMultiplier,
        this.maxInterval
      );
    } else {
      this.currentInterval = this.updateInterval;
    }

    this.intervalId = setInterval(() => {
      this.fetchPrices();
    }, this.currentInterval);
  }

  private async fetchPrices() {
    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

      if (!supabaseUrl || !supabaseAnonKey) {
        return;
      }

      const apiUrl = `${supabaseUrl}/functions/v1/update-prices`;

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 8000);

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${supabaseAnonKey}`,
          'Content-Type': 'application/json',
        },
        signal: controller.signal,
      });

      clearTimeout(timeout);

      if (!response.ok) {
        this.consecutiveFailures++;
        this.scheduleNext();
        return;
      }

      const data = await response.json();

      if (data.success) {
        this.consecutiveFailures = 0;
        this.scheduleNext();
      } else {
        this.consecutiveFailures++;
        this.scheduleNext();
      }
    } catch (error) {
      this.consecutiveFailures++;
      this.scheduleNext();
    }
  }
}

export const priceUpdateService = new PriceUpdateService();

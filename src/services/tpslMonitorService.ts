import { supabase } from '../lib/supabase';
import { priceStore, PriceData } from '../store/priceStore';

interface Position {
  position_id: string;
  pair: string;
  side: string;
  entry_price: number;
  take_profit: number | null;
  stop_loss: number | null;
  mark_price: number;
  quantity: number;
  margin_allocated: number;
  leverage: number;
}

export type TPSLCloseEvent = {
  positionId: string;
  pair: string;
  side: string;
  closePrice: number;
  pnl: number;
  reason: 'Take Profit' | 'Stop Loss';
};

type TPSLEventCallback = (event: TPSLCloseEvent) => void;

class TPSLMonitorService {
  private isRunning: boolean = false;
  private userId: string | null = null;
  private processingPositions: Set<string> = new Set();
  private positions: Position[] = [];
  private unsubscribePrices: (() => void) | null = null;
  private positionsRefreshInterval: number | null = null;
  private eventListeners: Set<TPSLEventCallback> = new Set();
  private lastTriggeredTime: Map<string, number> = new Map();

  start(userId: string) {
    if (this.isRunning && this.userId === userId) {
      return;
    }

    this.stop();
    this.userId = userId;
    this.isRunning = true;

    this.loadPositions();

    this.positionsRefreshInterval = setInterval(() => {
      this.loadPositions();
    }, 3000);

    this.unsubscribePrices = priceStore.subscribe((prices) => {
      this.checkAllPositions(prices);
    });
  }

  stop() {
    if (this.unsubscribePrices) {
      this.unsubscribePrices();
      this.unsubscribePrices = null;
    }

    if (this.positionsRefreshInterval) {
      clearInterval(this.positionsRefreshInterval);
      this.positionsRefreshInterval = null;
    }

    this.isRunning = false;
    this.userId = null;
    this.processingPositions.clear();
    this.positions = [];
    this.lastTriggeredTime.clear();
  }

  onTPSLTriggered(callback: TPSLEventCallback): () => void {
    this.eventListeners.add(callback);
    return () => {
      this.eventListeners.delete(callback);
    };
  }

  private emitEvent(event: TPSLCloseEvent) {
    this.eventListeners.forEach(callback => {
      try {
        callback(event);
      } catch (e) {
        console.error('Error in TPSL event listener:', e);
      }
    });
  }

  private async loadPositions() {
    if (!this.userId) return;

    try {
      const { data: positions, error } = await supabase
        .from('futures_positions')
        .select('position_id, pair, side, entry_price, take_profit, stop_loss, mark_price, quantity, margin_allocated, leverage')
        .eq('user_id', this.userId)
        .eq('status', 'open')
        .or('take_profit.not.is.null,stop_loss.not.is.null');

      if (!error && positions) {
        this.positions = positions as Position[];
      }
    } catch (error) {
      console.error('Error loading positions for TPSL:', error);
    }
  }

  private checkAllPositions(prices: Map<string, PriceData>) {
    if (!this.userId || this.positions.length === 0) return;

    for (const position of this.positions) {
      if (this.processingPositions.has(position.position_id)) {
        continue;
      }

      const currentPrice = this.getPriceFromMap(position.pair, prices);
      if (!currentPrice || currentPrice <= 0) continue;

      let shouldClose = false;
      let closeReason: 'Take Profit' | 'Stop Loss' = 'Take Profit';

      if (position.take_profit) {
        if (position.side === 'long' && currentPrice >= position.take_profit) {
          shouldClose = true;
          closeReason = 'Take Profit';
        } else if (position.side === 'short' && currentPrice <= position.take_profit) {
          shouldClose = true;
          closeReason = 'Take Profit';
        }
      }

      if (!shouldClose && position.stop_loss) {
        if (position.side === 'long' && currentPrice <= position.stop_loss) {
          shouldClose = true;
          closeReason = 'Stop Loss';
        } else if (position.side === 'short' && currentPrice >= position.stop_loss) {
          shouldClose = true;
          closeReason = 'Stop Loss';
        }
      }

      if (shouldClose) {
        const now = Date.now();
        const lastTriggered = this.lastTriggeredTime.get(position.position_id) || 0;

        if (now - lastTriggered < 5000) {
          continue;
        }

        this.lastTriggeredTime.set(position.position_id, now);
        this.processingPositions.add(position.position_id);
        this.closePosition(position, currentPrice, closeReason);
      }
    }
  }

  private getPriceFromMap(pair: string, prices: Map<string, PriceData>): number {
    const symbol = pair.replace('USDT', '/USDT');
    let priceData = prices.get(symbol);

    if (priceData && priceData.price > 0) {
      return priceData.price;
    }

    priceData = prices.get(pair);
    if (priceData && priceData.price > 0) {
      return priceData.price;
    }

    const baseSymbol = pair.replace('USDT', '');
    priceData = prices.get(baseSymbol);
    if (priceData && priceData.price > 0) {
      return priceData.price;
    }

    return 0;
  }

  private async closePosition(
    position: Position,
    closePrice: number,
    closeReason: 'Take Profit' | 'Stop Loss'
  ) {
    try {
      const { data, error } = await supabase.rpc('close_position', {
        p_position_id: position.position_id,
        p_close_quantity: null,
        p_close_price: closePrice
      });

      if (error) {
        console.error('Error closing position via TPSL:', error);
        this.processingPositions.delete(position.position_id);
        return;
      }

      if (data && data.success) {
        const pnl = data.pnl || 0;

        this.emitEvent({
          positionId: position.position_id,
          pair: position.pair,
          side: position.side,
          closePrice,
          pnl,
          reason: closeReason
        });

        this.positions = this.positions.filter(p => p.position_id !== position.position_id);

        if (this.userId) {
          const notificationType = closeReason === 'Take Profit' ? 'position_tp_hit' : 'position_sl_hit';

          await supabase.rpc('send_notification', {
            p_user_id: this.userId,
            p_type: notificationType,
            p_title: `${closeReason} Triggered`,
            p_message: `Your ${position.pair} ${position.side.toUpperCase()} position was closed at $${closePrice.toFixed(2)}. P&L: ${pnl >= 0 ? '+' : ''}$${pnl.toFixed(2)}`,
            p_data: {
              position_id: position.position_id,
              pair: position.pair,
              side: position.side,
              close_price: closePrice,
              pnl: pnl,
              reason: closeReason
            }
          });
        }
      }

      this.processingPositions.delete(position.position_id);
    } catch (error) {
      console.error('Error in closePosition:', error);
      this.processingPositions.delete(position.position_id);
    }
  }

  isActive(): boolean {
    return this.isRunning;
  }

  getPositionCount(): number {
    return this.positions.length;
  }
}

export const tpslMonitorService = new TPSLMonitorService();

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface Position {
  position_id: string;
  user_id: string;
  pair: string;
  side: string;
  entry_price: number;
  quantity: number;
  leverage: number;
  take_profit: number | null;
  stop_loss: number | null;
  mark_price: number;
}

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

    // Get all open positions with TP/SL set
    const { data: positions, error: positionsError } = await supabase
      .from('futures_positions')
      .select('position_id, user_id, pair, side, entry_price, quantity, leverage, take_profit, stop_loss, mark_price')
      .eq('status', 'open')
      .or('take_profit.not.is.null,stop_loss.not.is.null');

    if (positionsError) {
      throw new Error(`Failed to fetch positions: ${positionsError.message}`);
    }

    console.log(`Found ${positions?.length || 0} positions with TP/SL set`);

    if (!positions || positions.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No positions with TP/SL found',
          checked: 0,
          triggered: 0,
          timestamp: new Date().toISOString()
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // Get current prices for all relevant pairs
    const pairs = [...new Set(positions.map((p: Position) => p.pair))];
    const { data: prices, error: pricesError } = await supabase
      .from('market_prices')
      .select('pair, mark_price')
      .in('pair', pairs);

    if (pricesError) {
      throw new Error(`Failed to fetch prices: ${pricesError.message}`);
    }

    const priceMap = new Map<string, number>();
    if (prices) {
      prices.forEach((p: { pair: string; mark_price: number }) => {
        priceMap.set(p.pair, p.mark_price);
      });
    }

    const triggeredPositions: string[] = [];
    const errors: string[] = [];
    const checkedPositions: any[] = [];

    // Check each position
    for (const position of positions as Position[]) {
      try {
        const currentPrice = priceMap.get(position.pair) || position.mark_price;
        let shouldClose = false;
        let closeReason = '';

        console.log(`Checking ${position.pair} ${position.side}: Current=$${currentPrice}, Entry=$${position.entry_price}, TP=$${position.take_profit || 'none'}, SL=$${position.stop_loss || 'none'}`);

        // Check Take Profit
        if (position.take_profit) {
          if (position.side === 'long' && currentPrice >= position.take_profit) {
            shouldClose = true;
            closeReason = 'Take Profit';
            console.log(`✅ TP Hit: ${position.side} position, price ${currentPrice} >= ${position.take_profit}`);
          } else if (position.side === 'short' && currentPrice <= position.take_profit) {
            shouldClose = true;
            closeReason = 'Take Profit';
            console.log(`✅ TP Hit: ${position.side} position, price ${currentPrice} <= ${position.take_profit}`);
          }
        }

        // Check Stop Loss (only if TP not triggered)
        if (!shouldClose && position.stop_loss) {
          if (position.side === 'long' && currentPrice <= position.stop_loss) {
            shouldClose = true;
            closeReason = 'Stop Loss';
            console.log(`⚠️ SL Hit: ${position.side} position, price ${currentPrice} <= ${position.stop_loss}`);
          } else if (position.side === 'short' && currentPrice >= position.stop_loss) {
            shouldClose = true;
            closeReason = 'Stop Loss';
            console.log(`⚠️ SL Hit: ${position.side} position, price ${currentPrice} >= ${position.stop_loss}`);
          }
        }

        checkedPositions.push({
          pair: position.pair,
          side: position.side,
          currentPrice,
          entry: position.entry_price,
          tp: position.take_profit,
          sl: position.stop_loss,
          shouldClose,
          closeReason
        });

        if (shouldClose) {
          // Close the position
          const { data: closeResult, error: closeError } = await supabase
            .rpc('close_position', {
              p_position_id: position.position_id,
              p_close_quantity: null,
              p_close_price: currentPrice
            });

          if (closeError) {
            const errorMsg = `Failed to close ${position.position_id}: ${closeError.message}`;
            console.error(errorMsg);
            errors.push(errorMsg);
          } else if (closeResult && closeResult.success) {
            const triggerMsg = `${position.pair} ${position.side.toUpperCase()} - ${closeReason} at $${currentPrice}`;
            triggeredPositions.push(triggerMsg);

            // Log the TP/SL execution
            console.log(`✅ Position closed: ${triggerMsg}, P&L: $${closeResult.pnl}`);

            // Send notification to user
            const notificationType = closeReason === 'Take Profit' ? 'position_tp_hit' : 'position_sl_hit';
            const pnl = closeResult.pnl || 0;
            const pnlFormatted = pnl >= 0 ? `+$${pnl.toFixed(2)}` : `-$${Math.abs(pnl).toFixed(2)}`;

            await supabase.rpc('send_notification', {
              p_user_id: position.user_id,
              p_type: notificationType,
              p_title: `${closeReason} Triggered`,
              p_message: `Your ${position.pair} ${position.side.toUpperCase()} position was closed at $${currentPrice.toFixed(2)}. P&L: ${pnlFormatted}`,
              p_data: {
                position_id: position.position_id,
                pair: position.pair,
                side: position.side,
                close_price: currentPrice,
                pnl: pnl,
                reason: closeReason
              }
            });
          } else {
            const errorMsg = `Close failed for ${position.position_id}: ${closeResult?.error || 'Unknown error'}`;
            console.error(errorMsg);
            errors.push(errorMsg);
          }
        }

        // Small delay to prevent overwhelming the database
        await new Promise(resolve => setTimeout(resolve, 50));
      } catch (error) {
        errors.push(`Error processing ${position.position_id}: ${error.message}`);
      }
    }

    const responseData = {
      success: true,
      checked: positions.length,
      triggered: triggeredPositions.length,
      triggeredPositions: triggeredPositions,
      checkedPositions: checkedPositions,
      errors: errors.length > 0 ? errors : undefined,
      timestamp: new Date().toISOString()
    };

    console.log(`Monitor complete: ${positions.length} checked, ${triggeredPositions.length} triggered, ${errors.length} errors`);

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
    console.error('Error in monitor-tpsl function:', error);

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

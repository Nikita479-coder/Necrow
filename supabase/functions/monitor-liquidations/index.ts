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
  mark_price: number;
  liquidation_price: number;
  margin_mode: string;
  margin_allocated: number;
  unrealized_pnl: number;
  maintenance_margin_rate: number;
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

    // Get all open positions
    const { data: positions, error: positionsError } = await supabase
      .from('futures_positions')
      .select('position_id, user_id, pair, side, entry_price, quantity, leverage, mark_price, liquidation_price, margin_mode, margin_allocated, unrealized_pnl, maintenance_margin_rate')
      .eq('status', 'open');

    if (positionsError) {
      throw new Error(`Failed to fetch positions: ${positionsError.message}`);
    }

    console.log(`Found ${positions?.length || 0} open positions to check`);

    if (!positions || positions.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No open positions found',
          checked: 0,
          liquidated: 0,
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

    const liquidatedPositions: any[] = [];
    const errors: string[] = [];
    const checkedPositions: any[] = [];

    // Check for cross margin positions that need liquidation
    const crossMarginUsers = new Map<string, Position[]>();
    for (const position of positions as Position[]) {
      if (position.margin_mode === 'cross') {
        if (!crossMarginUsers.has(position.user_id)) {
          crossMarginUsers.set(position.user_id, []);
        }
        crossMarginUsers.get(position.user_id)!.push(position);
      }
    }

    // Check each position
    for (const position of positions as Position[]) {
      try {
        const currentPrice = priceMap.get(position.pair) || position.mark_price;
        let shouldLiquidate = false;
        let liquidationReason = '';

        if (position.margin_mode === 'isolated') {
          // Check isolated margin liquidation
          if (position.side === 'long' && currentPrice <= position.liquidation_price) {
            shouldLiquidate = true;
            liquidationReason = `Price ${currentPrice} <= Liquidation Price ${position.liquidation_price}`;
          } else if (position.side === 'short' && currentPrice >= position.liquidation_price) {
            shouldLiquidate = true;
            liquidationReason = `Price ${currentPrice} >= Liquidation Price ${position.liquidation_price}`;
          }
        } else {
          // Check cross margin liquidation
          const userPositions = crossMarginUsers.get(position.user_id) || [];
          let totalMargin = 0;
          let totalUnrealizedPnl = 0;
          let totalMaintenance = 0;

          for (const pos of userPositions) {
            const posPrice = priceMap.get(pos.pair) || pos.mark_price;
            totalMargin += pos.margin_allocated;
            
            // Calculate unrealized PnL
            const priceDiff = pos.side === 'long' 
              ? posPrice - pos.entry_price 
              : pos.entry_price - posPrice;
            const unrealizedPnl = priceDiff * pos.quantity;
            totalUnrealizedPnl += unrealizedPnl;
            
            // Calculate maintenance margin
            totalMaintenance += pos.quantity * posPrice * pos.maintenance_margin_rate;
          }

          const equity = totalMargin + totalUnrealizedPnl;
          if (equity <= totalMaintenance) {
            shouldLiquidate = true;
            liquidationReason = `Cross Margin: Equity ${equity.toFixed(2)} <= Maintenance ${totalMaintenance.toFixed(2)}`;
          }
        }

        checkedPositions.push({
          pair: position.pair,
          side: position.side,
          currentPrice,
          liquidationPrice: position.liquidation_price,
          marginMode: position.margin_mode,
          shouldLiquidate,
          reason: liquidationReason || 'Safe'
        });

        if (shouldLiquidate) {
          console.log(`🚨 LIQUIDATING: ${position.pair} ${position.side.toUpperCase()} - ${liquidationReason}`);

          // Execute liquidation
          const { data: liquidationResult, error: liquidationError } = await supabase
            .rpc('execute_liquidation', {
              p_position_id: position.position_id
            });

          if (liquidationError) {
            const errorMsg = `Failed to liquidate ${position.position_id}: ${liquidationError.message}`;
            console.error(errorMsg);
            errors.push(errorMsg);
          } else if (liquidationResult && liquidationResult.success) {
            liquidatedPositions.push({
              pair: position.pair,
              side: position.side,
              currentPrice,
              liquidationPrice: position.liquidation_price,
              marginLost: position.margin_allocated,
              liquidationFee: liquidationResult.liquidation_fee || 0,
              reason: liquidationReason
            });

            console.log(`✅ Liquidated: ${position.pair} ${position.side.toUpperCase()} - Lost: $${position.margin_allocated}`);

            // Send notification to user
            await supabase.rpc('send_notification', {
              p_user_id: position.user_id,
              p_type: 'position_liquidated',
              p_title: 'Position Liquidated',
              p_message: `Your ${position.pair} ${position.side.toUpperCase()} ${position.leverage}x position was liquidated at $${currentPrice.toFixed(2)}. Margin lost: $${position.margin_allocated.toFixed(2)}`,
              p_data: {
                position_id: position.position_id,
                pair: position.pair,
                side: position.side,
                leverage: position.leverage,
                liquidation_price: currentPrice,
                margin_lost: position.margin_allocated,
                liquidation_fee: liquidationResult.liquidation_fee || 0
              }
            });
          } else {
            const errorMsg = `Liquidation failed for ${position.position_id}: ${liquidationResult?.error || 'Unknown error'}`;
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
      liquidated: liquidatedPositions.length,
      liquidatedPositions: liquidatedPositions,
      checkedPositions: checkedPositions.filter(p => p.shouldLiquidate || checkedPositions.length <= 10),
      errors: errors.length > 0 ? errors : undefined,
      timestamp: new Date().toISOString()
    };

    console.log(`Monitor complete: ${positions.length} checked, ${liquidatedPositions.length} liquidated, ${errors.length} errors`);

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
    console.error('Error in monitor-liquidations function:', error);

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

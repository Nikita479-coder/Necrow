import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const TRADING_PAIRS = [
  'BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'BNB/USDT', 'XRP/USDT',
  'ADA/USDT', 'DOGE/USDT', 'MATIC/USDT', 'DOT/USDT', 'LTC/USDT'
];

interface RequestBody {
  trader_id: string;
  target_percentage: number;
  trader_balance: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { trader_id, target_percentage, trader_balance }: RequestBody = await req.json();

    if (!trader_id || target_percentage === undefined || !trader_balance) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid request parameters' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const randomPair = TRADING_PAIRS[Math.floor(Math.random() * TRADING_PAIRS.length)];
    const randomSide: 'long' | 'short' = Math.random() > 0.5 ? 'long' : 'short';
    const leverage = 10;

    const marginPercentage = 20;
    const marginUsed = (trader_balance * marginPercentage) / 100;

    const basePrices: Record<string, number> = {
      'BTC/USDT': 95000,
      'ETH/USDT': 3500,
      'SOL/USDT': 220,
      'BNB/USDT': 650,
      'XRP/USDT': 2.5,
      'ADA/USDT': 1.1,
      'DOGE/USDT': 0.38,
      'MATIC/USDT': 1.15,
      'DOT/USDT': 9.5,
      'LTC/USDT': 105
    };

    const entryPrice = basePrices[randomPair] || 100;

    const priceChangePercent = target_percentage / leverage;

    let exitPrice: number;
    if (randomSide === 'long') {
      exitPrice = entryPrice * (1 + priceChangePercent / 100);
    } else {
      exitPrice = entryPrice * (1 - priceChangePercent / 100);
    }

    const positionValue = marginUsed * leverage;
    const quantity = positionValue / entryPrice;

    const tradeId = crypto.randomUUID();
    const now = new Date().toISOString();

    const { error: insertError } = await supabase
      .from('trader_trades')
      .insert({
        id: tradeId,
        trader_id: trader_id,
        symbol: randomPair,
        side: randomSide,
        entry_price: entryPrice,
        exit_price: exitPrice,
        quantity: quantity,
        leverage: leverage,
        margin_used: marginUsed,
        pnl: (marginUsed * target_percentage / 100),
        pnl_percent: target_percentage,
        status: 'closed',
        opened_at: now,
        closed_at: now,
        created_at: now,
        updated_at: now
      });

    if (insertError) {
      throw new Error(`Failed to create trade: ${insertError.message}`);
    }

    const { data: followers, error: followersError } = await supabase
      .from('copy_relationships')
      .select('follower_id, current_balance')
      .eq('trader_id', trader_id)
      .eq('is_active', true);

    if (followersError) {
      console.error('Error fetching followers:', followersError);
    }

    if (followers && followers.length > 0) {
      for (const follower of followers) {
        const followerBalance = parseFloat(follower.current_balance || '0');
        const pnlAmount = followerBalance * (target_percentage / 100);
        const newBalance = followerBalance + pnlAmount;

        const { data: currentRel } = await supabase
          .from('copy_relationships')
          .select('cumulative_pnl')
          .eq('follower_id', follower.follower_id)
          .eq('trader_id', trader_id)
          .single();

        const newCumulativePnl = (parseFloat(currentRel?.cumulative_pnl || '0')) + pnlAmount;

        await supabase
          .from('copy_relationships')
          .update({
            current_balance: newBalance.toString(),
            cumulative_pnl: newCumulativePnl.toString()
          })
          .eq('follower_id', follower.follower_id)
          .eq('trader_id', trader_id);

        await supabase
          .from('copy_trade_allocations')
          .insert({
            user_id: follower.follower_id,
            trader_id: trader_id,
            trade_id: tradeId,
            symbol: randomPair,
            side: randomSide,
            entry_price: entryPrice,
            exit_price: exitPrice,
            allocated_margin: (followerBalance * marginPercentage) / 100,
            leverage: leverage,
            pnl: pnlAmount,
            pnl_percentage: target_percentage,
            status: 'closed',
            created_at: now,
            closed_at: now
          });

        if (target_percentage !== 0) {
          const message = target_percentage > 0
            ? `Your copy trade with ${randomPair} closed with a profit of +${target_percentage}% ($${Math.abs(pnlAmount).toFixed(2)})`
            : `Your copy trade with ${randomPair} closed with a loss of ${target_percentage}% ($${Math.abs(pnlAmount).toFixed(2)})`;

          await supabase
            .from('notifications')
            .insert({
              user_id: follower.follower_id,
              title: target_percentage > 0 ? 'Trade Profit' : 'Trade Loss',
              message: message,
              type: 'copy_trade_pnl',
              status: 'unread',
              created_at: now
            });
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        pair: randomPair,
        side: randomSide,
        entry_price: entryPrice,
        exit_price: exitPrice,
        pnl_percentage: target_percentage,
        followers_updated: followers?.length || 0
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('Execute percentage trade error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
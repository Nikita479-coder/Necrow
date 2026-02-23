import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface ResetRequest {
  email: string;
  keepKyc?: boolean;
  bonusAmount?: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user: adminUser }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !adminUser) {
      throw new Error('Unauthorized');
    }

    const { data: adminProfile } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', adminUser.id)
      .single();

    if (!adminProfile?.is_admin) {
      throw new Error('Only admins can reset accounts');
    }

    const { email, keepKyc = true, bonusAmount = 0 }: ResetRequest = await req.json();

    if (!email) {
      throw new Error('Email is required');
    }

    const { data: targetUser, error: userError } = await supabase.auth.admin.listUsers();
    const user = targetUser?.users?.find((u) => u.email === email);

    if (!user) {
      throw new Error(`User not found: ${email}`);
    }

    const userId = user.id;

    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();

    await supabase.from('futures_positions').delete().eq('user_id', userId);
    await supabase.from('trades').delete().eq('user_id', userId);
    await supabase.from('trader_trades').delete().eq('trader_id', userId);
    await supabase.from('copy_trade_allocations').delete().eq('follower_id', userId);
    await supabase.from('copy_relationships')
      .update({ active: false, sync_status: 'stopped', updated_at: new Date().toISOString() })
      .eq('follower_id', userId);
    await supabase.from('pending_copy_trades').delete().eq('follower_id', userId);
    await supabase.from('staking_positions').delete().eq('user_id', userId);
    await supabase.from('swap_orders').delete().eq('user_id', userId);
    await supabase.from('transactions').delete().eq('user_id', userId);
    await supabase.from('referral_commissions').delete().eq('referrer_id', userId);
    await supabase.from('affiliate_commissions').delete().eq('affiliate_id', userId);
    await supabase.from('locked_bonuses').delete().eq('user_id', userId);
    await supabase.from('locked_withdrawal_balances').delete().eq('user_id', userId);
    await supabase.from('user_rewards').delete().eq('user_id', userId);
    await supabase.from('notifications').delete().eq('user_id', userId);
    await supabase.from('user_fee_rebates').delete().eq('user_id', userId);
    await supabase.from('shark_card_applications').delete().eq('user_id', userId);
    await supabase.from('card_transactions').delete().eq('user_id', userId);

    await supabase.from('wallets')
      .update({
        balance: 0,
        available_balance: 0,
        total_deposited: 0,
        total_withdrawn: 0,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    await supabase.from('futures_margin_wallets')
      .update({
        balance: 0,
        available_balance: 0,
        used_margin: 0,
        locked_bonus_balance: 0,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    const { count: referralCount } = await supabase
      .from('user_profiles')
      .select('*', { count: 'exact', head: true })
      .eq('referred_by', userId);

    await supabase.from('referral_stats')
      .update({
        total_commission: 0,
        total_volume_30d: 0,
        total_volume_all_time: 0,
        vip_level: 1,
        total_referrals: referralCount || 0,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (!keepKyc) {
      await supabase.from('user_profiles')
        .update({
          kyc_status: 'unverified',
          kyc_level: 0,
          updated_at: new Date().toISOString(),
        })
        .eq('id', userId);
      await supabase.from('kyc_documents').delete().eq('user_id', userId);
    }

    if (bonusAmount > 0) {
      let bonusTypeId;
      const { data: bonusType } = await supabase
        .from('bonus_types')
        .select('id')
        .eq('name', 'Account Reset Bonus')
        .single();

      if (bonusType) {
        bonusTypeId = bonusType.id;
      } else {
        const { data: newBonusType } = await supabase
          .from('bonus_types')
          .insert({
            name: 'Account Reset Bonus',
            description: 'Bonus awarded after account reset',
            amount: bonusAmount,
            bonus_percentage: 0,
            is_active: true,
          })
          .select()
          .single();
        bonusTypeId = newBonusType?.id;
      }

      const { data: mainWallet } = await supabase
        .from('wallets')
        .select('id')
        .eq('user_id', userId)
        .eq('wallet_type', 'main')
        .single();

      if (mainWallet) {
        await supabase.from('locked_bonuses').insert({
          user_id: userId,
          bonus_type_id: bonusTypeId,
          amount: bonusAmount,
          locked_amount: bonusAmount,
          status: 'active',
          awarded_by: adminUser.id,
          awarded_at: new Date().toISOString(),
        });

        await supabase.from('wallets')
          .update({
            balance: bonusAmount,
            available_balance: bonusAmount,
            updated_at: new Date().toISOString(),
          })
          .eq('id', mainWallet.id);

        await supabase.from('transactions').insert({
          user_id: userId,
          wallet_id: mainWallet.id,
          transaction_type: 'bonus',
          amount: bonusAmount,
          status: 'completed',
          details: { description: 'Account Reset Bonus', bonus_amount: bonusAmount },
        });

        await supabase.from('notifications').insert({
          user_id: userId,
          title: 'Account Reset Complete',
          message: `Your account has been reset and you have received a $${bonusAmount} bonus.`,
          notification_type: 'bonus',
          read: false,
        });
      }
    }

    await supabase.from('admin_action_logs').insert({
      admin_id: adminUser.id,
      action_type: 'reset_account',
      target_user_id: userId,
      action_description: `Reset account for user ${userProfile?.full_name} (${email})`,
      changes: {
        kept_kyc: keepKyc,
        bonus_amount: bonusAmount,
        reset_at: new Date().toISOString(),
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        user_id: userId,
        email,
        kept_kyc: keepKyc,
        bonus_awarded: bonusAmount,
        message: 'Account reset successfully',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

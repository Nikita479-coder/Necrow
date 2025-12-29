import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const userEmail = process.argv[2] || 'atobiam247@gmail.com';
const keepKyc = true;
const bonusAmount = 20;

async function resetUser() {
  console.log(`Resetting account for: ${userEmail}`);
  console.log(`Keep KYC: ${keepKyc}`);
  console.log(`Bonus Amount: $${bonusAmount}`);
  console.log('');

  try {
    const { data: targetUser } = await supabase.auth.admin.listUsers();
    const user = targetUser?.users?.find((u) => u.email === userEmail);

    if (!user) {
      console.error(`User not found: ${userEmail}`);
      process.exit(1);
    }

    const userId = user.id;
    console.log(`Found user ID: ${userId}`);

    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();

    console.log(`User: ${userProfile?.full_name || 'Unknown'}`);
    console.log('');

    console.log('Deleting trading data...');
    await supabase.from('futures_positions').delete().eq('user_id', userId);
    await supabase.from('trades').delete().eq('user_id', userId);
    await supabase.from('trader_trades').delete().eq('trader_id', userId);
    await supabase.from('copy_trade_allocations').delete().eq('follower_id', userId);
    await supabase.from('pending_copy_trades').delete().eq('follower_id', userId);
    await supabase.from('staking_positions').delete().eq('user_id', userId);
    await supabase.from('swap_orders').delete().eq('user_id', userId);

    console.log('Stopping copy trading relationships...');
    await supabase.from('copy_relationships')
      .update({ active: false, sync_status: 'stopped', updated_at: new Date().toISOString() })
      .eq('follower_id', userId);

    console.log('Deleting financial records...');
    await supabase.from('transactions').delete().eq('user_id', userId);
    await supabase.from('referral_commissions').delete().eq('referrer_id', userId);
    await supabase.from('affiliate_commissions').delete().eq('affiliate_id', userId);
    await supabase.from('locked_bonuses').delete().eq('user_id', userId);
    await supabase.from('locked_withdrawal_balances').delete().eq('user_id', userId);
    await supabase.from('user_rewards').delete().eq('user_id', userId);
    await supabase.from('user_fee_rebates').delete().eq('user_id', userId);
    await supabase.from('shark_card_applications').delete().eq('user_id', userId);
    await supabase.from('card_transactions').delete().eq('user_id', userId);

    console.log('Clearing notifications...');
    await supabase.from('notifications').delete().eq('user_id', userId);

    console.log('Resetting wallet balances...');
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

    console.log('Resetting referral stats...');
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
      console.log('Resetting KYC status...');
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
      console.log(`Awarding $${bonusAmount} bonus...`);

      let bonusTypeId;
      const { data: bonusType } = await supabase
        .from('bonus_types')
        .select('id')
        .eq('name', 'Account Reset Bonus')
        .single();

      if (bonusType) {
        bonusTypeId = bonusType.id;
      } else {
        const { data: newBonusType, error: bonusError } = await supabase
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

        if (bonusError) {
          console.error('Error creating bonus type:', bonusError);
        }
        bonusTypeId = newBonusType?.id;
      }

      const { data: mainWallet } = await supabase
        .from('wallets')
        .select('id')
        .eq('user_id', userId)
        .eq('wallet_type', 'main')
        .single();

      if (mainWallet && bonusTypeId) {
        await supabase.from('locked_bonuses').insert({
          user_id: userId,
          bonus_type_id: bonusTypeId,
          amount: bonusAmount,
          locked_amount: bonusAmount,
          status: 'active',
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

    console.log('');
    console.log('✅ Account reset successfully!');
    console.log(`   Email: ${userEmail}`);
    console.log(`   User ID: ${userId}`);
    console.log(`   KYC Status: ${keepKyc ? 'Preserved' : 'Reset'}`);
    console.log(`   Bonus Awarded: $${bonusAmount}`);
  } catch (error) {
    console.error('Error resetting account:', error);
    process.exit(1);
  }
}

resetUser();

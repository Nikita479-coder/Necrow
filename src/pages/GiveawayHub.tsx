import { useState, useEffect } from 'react';
import { Gift, Ticket, Trophy, Clock, DollarSign, Users, Sparkles, ChevronRight, CheckCircle, AlertCircle, Star, Zap, Award, Timer, ArrowRight, ExternalLink } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';

interface Campaign {
  id: string;
  name: string;
  description: string | null;
  start_date: string;
  end_date: string;
  draw_date: string;
  status: 'active' | 'completed';
  holding_period_days: number;
  total_prize_value: number;
}

interface TicketTier {
  id: string;
  tier_name: string;
  min_deposit: number;
  max_deposit: number | null;
  base_tickets: number;
  bonus_percentage: number;
  guaranteed_bonus_amount: number;
}

interface Prize {
  id: string;
  name: string;
  prize_type: 'cash' | 'fee_voucher';
  prize_category: 'grand' | 'major' | 'mass';
  amount: number;
  quantity: number;
  remaining_quantity: number;
}

interface UserTicket {
  ticket_id: string;
  campaign_id: string;
  campaign_name: string;
  ticket_count: number;
  deposit_amount: number;
  tier_name: string;
  guaranteed_bonus_awarded: number;
  awarded_at: string;
  eligible_at: string;
  is_eligible: boolean;
  days_until_eligible: number;
}

interface UserSummary {
  total_tickets: number;
  eligible_tickets: number;
  pending_tickets: number;
  total_deposits: number;
  total_deposited: number;
  guaranteed_bonuses: number;
  next_eligible_at: string | null;
}

interface UserWin {
  winner_id: string;
  prize_name: string;
  prize_type: string;
  prize_amount: number;
  prize_category: string;
  won_at: string;
  credit_status: string;
}

export default function GiveawayHub() {
  const { user } = useAuth();
  const { navigateTo } = useNavigation();

  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [tiers, setTiers] = useState<TicketTier[]>([]);
  const [prizes, setPrizes] = useState<Prize[]>([]);
  const [userTickets, setUserTickets] = useState<UserTicket[]>([]);
  const [userSummary, setUserSummary] = useState<UserSummary | null>(null);
  const [userWins, setUserWins] = useState<UserWin[]>([]);
  const [loading, setLoading] = useState(true);
  const [countdown, setCountdown] = useState({ days: 0, hours: 0, minutes: 0, seconds: 0 });

  useEffect(() => {
    loadGiveawayData();
  }, [user]);

  useEffect(() => {
    if (!campaign) return;

    const targetDate = new Date(campaign.status === 'active' ? campaign.draw_date : campaign.end_date);

    const updateCountdown = () => {
      const now = new Date();
      const diff = targetDate.getTime() - now.getTime();

      if (diff <= 0) {
        setCountdown({ days: 0, hours: 0, minutes: 0, seconds: 0 });
        return;
      }

      setCountdown({
        days: Math.floor(diff / (1000 * 60 * 60 * 24)),
        hours: Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)),
        minutes: Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60)),
        seconds: Math.floor((diff % (1000 * 60)) / 1000)
      });
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);
    return () => clearInterval(interval);
  }, [campaign]);

  const loadGiveawayData = async () => {
    setLoading(true);
    try {
      const { data: campaigns, error: campaignError } = await supabase
        .from('giveaway_campaigns')
        .select('*')
        .in('status', ['active', 'completed'])
        .order('created_at', { ascending: false })
        .limit(1);

      if (campaignError) throw campaignError;

      if (campaigns && campaigns.length > 0) {
        const activeCampaign = campaigns[0];
        setCampaign(activeCampaign);

        const [tiersRes, prizesRes] = await Promise.all([
          supabase.from('giveaway_ticket_tiers').select('*').eq('campaign_id', activeCampaign.id).order('sort_order'),
          supabase.from('giveaway_prizes').select('*').eq('campaign_id', activeCampaign.id).order('sort_order')
        ]);

        setTiers(tiersRes.data || []);
        setPrizes(prizesRes.data || []);

        if (user) {
          const [ticketsRes, summaryRes, winsRes] = await Promise.all([
            supabase.rpc('get_user_giveaway_tickets', { p_user_id: user.id, p_campaign_id: activeCampaign.id }),
            supabase.rpc('get_user_giveaway_summary', { p_user_id: user.id, p_campaign_id: activeCampaign.id }),
            supabase.rpc('get_campaign_winners', { p_campaign_id: activeCampaign.id })
          ]);

          setUserTickets(ticketsRes.data || []);
          setUserSummary(summaryRes.data as UserSummary);

          const myWins = (winsRes.data || []).filter((w: any) => w.user_id === user.id);
          setUserWins(myWins);
        }
      }
    } catch (err) {
      console.error('Error loading giveaway:', err);
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(amount);
  };

  const calculateWinProbability = () => {
    if (!userSummary || userSummary.total_tickets === 0) return 0;
    const totalPrizes = prizes.reduce((sum, p) => sum + p.quantity, 0);
    return Math.min(100, (userSummary.total_tickets / 10000) * totalPrizes).toFixed(2);
  };

  const getTierColor = (tierName: string) => {
    switch (tierName.toLowerCase()) {
      case 'bronze': return 'from-orange-600 to-orange-800';
      case 'silver': return 'from-gray-400 to-gray-600';
      case 'gold': return 'from-yellow-400 to-yellow-600';
      case 'platinum': return 'from-cyan-400 to-blue-500';
      default: return 'from-gray-500 to-gray-700';
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0b0e11]">
        <Navbar />
        <div className="flex items-center justify-center h-[60vh]">
          <div className="w-12 h-12 border-4 border-yellow-500 border-t-transparent rounded-full animate-spin" />
        </div>
      </div>
    );
  }

  if (!campaign) {
    return (
      <div className="min-h-screen bg-[#0b0e11]">
        <Navbar />
        <div className="max-w-4xl mx-auto px-4 py-16 text-center">
          <Gift className="w-20 h-20 text-gray-600 mx-auto mb-6" />
          <h1 className="text-3xl font-bold text-white mb-4">No Active Giveaway</h1>
          <p className="text-gray-400 mb-8">Check back soon for exciting giveaway opportunities!</p>
          <button
            onClick={() => navigateTo('home')}
            className="px-6 py-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-medium rounded-lg hover:opacity-90"
          >
            Return Home
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-yellow-500/10 via-orange-500/5 to-transparent" />
        <div className="absolute top-10 left-10 w-72 h-72 bg-yellow-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-10 right-10 w-96 h-96 bg-orange-500/10 rounded-full blur-3xl" />

        <div className="relative max-w-6xl mx-auto px-4 py-12">
          <div className="text-center mb-8">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-yellow-500/20 rounded-full text-yellow-400 text-sm mb-4">
              <Sparkles className="w-4 h-4" />
              {campaign.status === 'active' ? 'Event Live Now' : 'Event Completed'}
            </div>
            <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">
              {campaign.name}
            </h1>
            <p className="text-xl text-gray-400 max-w-2xl mx-auto">
              {campaign.description}
            </p>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            <div className="bg-[#1a1d21]/80 backdrop-blur rounded-2xl p-6 border border-gray-800 text-center">
              <div className="text-4xl font-bold text-white mb-1">{countdown.days}</div>
              <div className="text-gray-400 text-sm">Days</div>
            </div>
            <div className="bg-[#1a1d21]/80 backdrop-blur rounded-2xl p-6 border border-gray-800 text-center">
              <div className="text-4xl font-bold text-white mb-1">{countdown.hours}</div>
              <div className="text-gray-400 text-sm">Hours</div>
            </div>
            <div className="bg-[#1a1d21]/80 backdrop-blur rounded-2xl p-6 border border-gray-800 text-center">
              <div className="text-4xl font-bold text-white mb-1">{countdown.minutes}</div>
              <div className="text-gray-400 text-sm">Minutes</div>
            </div>
            <div className="bg-[#1a1d21]/80 backdrop-blur rounded-2xl p-6 border border-gray-800 text-center">
              <div className="text-4xl font-bold text-white mb-1">{countdown.seconds}</div>
              <div className="text-gray-400 text-sm">Seconds</div>
            </div>
          </div>

          <div className="text-center text-gray-400 text-sm">
            {campaign.status === 'active' ? 'Until Draw' : 'Event Ended'} - Draw Date: {new Date(campaign.draw_date).toLocaleDateString()}
          </div>
        </div>
      </div>

      {user && userSummary && (
        <div className="max-w-6xl mx-auto px-4 py-8">
          <div className="bg-gradient-to-br from-yellow-500/10 to-orange-500/10 rounded-2xl p-6 border border-yellow-500/20 mb-8">
            <div className="flex flex-col md:flex-row items-center justify-between gap-6">
              <div className="flex items-center gap-6">
                <div className="w-20 h-20 bg-gradient-to-br from-yellow-500 to-orange-500 rounded-2xl flex items-center justify-center">
                  <Ticket className="w-10 h-10 text-black" />
                </div>
                <div>
                  <p className="text-gray-400 text-sm mb-1">Your Total Tickets</p>
                  <p className="text-5xl font-bold text-white">{userSummary.total_tickets.toLocaleString()}</p>
                  <p className="text-sm text-gray-500 mt-1">
                    {userSummary.eligible_tickets.toLocaleString()} eligible
                    {userSummary.pending_tickets > 0 && ` / ${userSummary.pending_tickets.toLocaleString()} pending`}
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-8 text-center">
                <div>
                  <p className="text-2xl font-bold text-white">{userSummary.total_deposits}</p>
                  <p className="text-gray-400 text-sm">Deposits</p>
                </div>
                <div>
                  <p className="text-2xl font-bold text-green-400">{formatCurrency(userSummary.total_deposited)}</p>
                  <p className="text-gray-400 text-sm">Total Deposited</p>
                </div>
                <div>
                  <p className="text-2xl font-bold text-yellow-400">{calculateWinProbability()}%</p>
                  <p className="text-gray-400 text-sm">Win Chance</p>
                </div>
              </div>

              {campaign.status === 'active' && (
                <button
                  onClick={() => navigateTo('deposit')}
                  className="px-8 py-4 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-bold rounded-xl hover:opacity-90 transition-opacity flex items-center gap-2 whitespace-nowrap"
                >
                  <Zap className="w-5 h-5" />
                  Deposit Now
                </button>
              )}
            </div>

            {userSummary.guaranteed_bonuses > 0 && (
              <div className="mt-4 pt-4 border-t border-yellow-500/20 flex items-center gap-2 text-green-400">
                <CheckCircle className="w-5 h-5" />
                <span>You've received {formatCurrency(userSummary.guaranteed_bonuses)} in guaranteed bonuses!</span>
              </div>
            )}
          </div>

          {userWins.length > 0 && (
            <div className="bg-gradient-to-br from-green-500/10 to-emerald-500/10 rounded-2xl p-6 border border-green-500/20 mb-8">
              <div className="flex items-center gap-3 mb-4">
                <Trophy className="w-6 h-6 text-green-400" />
                <h2 className="text-xl font-bold text-white">Congratulations! You Won!</h2>
              </div>
              <div className="grid gap-3">
                {userWins.map(win => (
                  <div key={win.winner_id} className="flex items-center justify-between bg-green-500/10 rounded-lg p-4">
                    <div className="flex items-center gap-3">
                      <Award className="w-5 h-5 text-green-400" />
                      <div>
                        <p className="text-white font-medium">{win.prize_name}</p>
                        <p className="text-sm text-gray-400">
                          {win.prize_type === 'fee_voucher' ? 'Fee Voucher' : 'Cash Prize'}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-xl font-bold text-green-400">{formatCurrency(win.prize_amount)}</p>
                      <p className="text-xs text-gray-500">
                        {win.credit_status === 'credited' ? 'Credited to account' : 'Processing...'}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      <div className="max-w-6xl mx-auto px-4 py-8">
        <h2 className="text-2xl font-bold text-white mb-6 flex items-center gap-3">
          <Star className="w-6 h-6 text-yellow-400" />
          Deposit Tiers
        </h2>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-12">
          {tiers.map((tier, index) => (
            <div
              key={tier.id}
              className={`relative bg-[#1a1d21] rounded-2xl p-6 border border-gray-800 overflow-hidden ${
                index === tiers.length - 1 ? 'ring-2 ring-yellow-500/50' : ''
              }`}
            >
              <div className={`absolute top-0 left-0 right-0 h-1 bg-gradient-to-r ${getTierColor(tier.tier_name)}`} />

              {tier.guaranteed_bonus_amount > 0 && (
                <div className="absolute top-3 right-3 px-2 py-1 bg-green-500/20 rounded text-xs text-green-400">
                  +{formatCurrency(tier.guaranteed_bonus_amount)} Bonus
                </div>
              )}

              <h3 className="text-lg font-bold text-white mb-2">{tier.tier_name}</h3>
              <p className="text-gray-400 text-sm mb-4">
                {formatCurrency(tier.min_deposit)}
                {tier.max_deposit ? ` - ${formatCurrency(tier.max_deposit)}` : '+'}
              </p>

              <div className="flex items-baseline gap-2 mb-2">
                <span className="text-3xl font-bold text-white">
                  {tier.base_tickets + Math.floor(tier.base_tickets * tier.bonus_percentage / 100)}
                </span>
                <span className="text-gray-400">tickets</span>
              </div>

              {tier.bonus_percentage > 0 && (
                <div className="text-sm text-yellow-400">
                  +{tier.bonus_percentage}% bonus tickets
                </div>
              )}
            </div>
          ))}
        </div>

        <h2 className="text-2xl font-bold text-white mb-6 flex items-center gap-3">
          <Trophy className="w-6 h-6 text-yellow-400" />
          Prize Pool - {formatCurrency(campaign.total_prize_value)}
        </h2>

        <div className="space-y-6 mb-12">
          {['grand', 'major', 'mass'].map(category => {
            const categoryPrizes = prizes.filter(p => p.prize_category === category);
            if (categoryPrizes.length === 0) return null;

            return (
              <div key={category}>
                <h3 className="text-lg font-semibold text-gray-400 uppercase mb-3">
                  {category === 'grand' ? 'Grand Prizes' : category === 'major' ? 'Major Prizes' : 'Mass Rewards'}
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                  {categoryPrizes.map(prize => (
                    <div
                      key={prize.id}
                      className={`bg-[#1a1d21] rounded-xl p-4 border ${
                        category === 'grand'
                          ? 'border-yellow-500/30 bg-gradient-to-br from-yellow-500/5 to-transparent'
                          : 'border-gray-800'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          {category === 'grand' ? (
                            <div className="w-10 h-10 bg-gradient-to-br from-yellow-500 to-orange-500 rounded-lg flex items-center justify-center">
                              <Trophy className="w-5 h-5 text-black" />
                            </div>
                          ) : prize.prize_type === 'fee_voucher' ? (
                            <div className="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center">
                              <Ticket className="w-5 h-5 text-blue-400" />
                            </div>
                          ) : (
                            <div className="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
                              <DollarSign className="w-5 h-5 text-green-400" />
                            </div>
                          )}
                          <div>
                            <p className="text-white font-medium">{prize.name}</p>
                            {prize.prize_type === 'fee_voucher' && (
                              <p className="text-xs text-blue-400">Trading Fee Voucher</p>
                            )}
                          </div>
                        </div>
                        <div className="text-right">
                          <p className={`font-bold ${category === 'grand' ? 'text-xl text-yellow-400' : 'text-white'}`}>
                            {formatCurrency(prize.amount)}
                          </p>
                          <p className="text-xs text-gray-500">
                            {campaign.status === 'completed'
                              ? `${prize.quantity - prize.remaining_quantity}/${prize.quantity} awarded`
                              : `${prize.quantity} available`
                            }
                          </p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>

        <div className="bg-[#1a1d21] rounded-2xl p-8 border border-gray-800 mb-12">
          <h2 className="text-2xl font-bold text-white mb-6 flex items-center gap-3">
            <AlertCircle className="w-6 h-6 text-yellow-400" />
            How It Works
          </h2>

          <div className="grid md:grid-cols-4 gap-6">
            <div className="text-center">
              <div className="w-16 h-16 bg-gradient-to-br from-yellow-500/20 to-orange-500/20 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <DollarSign className="w-8 h-8 text-yellow-400" />
              </div>
              <h3 className="text-white font-semibold mb-2">1. Deposit</h3>
              <p className="text-gray-400 text-sm">
                Make a deposit during the event period. Higher deposits = more tickets!
              </p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 bg-gradient-to-br from-yellow-500/20 to-orange-500/20 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <Ticket className="w-8 h-8 text-yellow-400" />
              </div>
              <h3 className="text-white font-semibold mb-2">2. Earn Tickets</h3>
              <p className="text-gray-400 text-sm">
                Tickets are awarded automatically based on your deposit tier.
              </p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 bg-gradient-to-br from-yellow-500/20 to-orange-500/20 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <Clock className="w-8 h-8 text-yellow-400" />
              </div>
              <h3 className="text-white font-semibold mb-2">3. Hold {campaign.holding_period_days} Days</h3>
              <p className="text-gray-400 text-sm">
                Keep your deposit for {campaign.holding_period_days} days to make tickets eligible for the draw.
              </p>
            </div>

            <div className="text-center">
              <div className="w-16 h-16 bg-gradient-to-br from-yellow-500/20 to-orange-500/20 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <Trophy className="w-8 h-8 text-yellow-400" />
              </div>
              <h3 className="text-white font-semibold mb-2">4. Win Prizes</h3>
              <p className="text-gray-400 text-sm">
                Winners drawn randomly. More tickets = higher chance to win!
              </p>
            </div>
          </div>

          <div className="mt-8 p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-xl">
            <div className="flex items-start gap-3">
              <Sparkles className="w-5 h-5 text-yellow-400 mt-0.5" />
              <div>
                <h4 className="text-yellow-400 font-semibold mb-1">Platinum Bonus</h4>
                <p className="text-gray-400 text-sm">
                  Deposit $1,000 or more and receive an instant {formatCurrency(20)} USDT bonus credited immediately to your account - no waiting required!
                </p>
              </div>
            </div>
          </div>
        </div>

        {user && userTickets.length > 0 && (
          <div className="bg-[#1a1d21] rounded-2xl p-6 border border-gray-800">
            <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-3">
              <Ticket className="w-5 h-5 text-yellow-400" />
              Your Ticket History
            </h2>

            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="text-left text-gray-400 text-sm border-b border-gray-800">
                    <th className="pb-3 pr-4">Deposit</th>
                    <th className="pb-3 pr-4">Tier</th>
                    <th className="pb-3 pr-4">Tickets</th>
                    <th className="pb-3 pr-4">Bonus</th>
                    <th className="pb-3 pr-4">Status</th>
                    <th className="pb-3">Date</th>
                  </tr>
                </thead>
                <tbody className="text-sm">
                  {userTickets.map(ticket => (
                    <tr key={ticket.ticket_id} className="border-b border-gray-800/50">
                      <td className="py-3 pr-4 text-white font-medium">
                        {formatCurrency(ticket.deposit_amount)}
                      </td>
                      <td className="py-3 pr-4">
                        <span className={`px-2 py-1 rounded text-xs bg-gradient-to-r ${getTierColor(ticket.tier_name)} text-white`}>
                          {ticket.tier_name}
                        </span>
                      </td>
                      <td className="py-3 pr-4 text-yellow-400 font-bold">
                        {ticket.ticket_count.toLocaleString()}
                      </td>
                      <td className="py-3 pr-4">
                        {ticket.guaranteed_bonus_awarded > 0 ? (
                          <span className="text-green-400">+{formatCurrency(ticket.guaranteed_bonus_awarded)}</span>
                        ) : (
                          <span className="text-gray-500">-</span>
                        )}
                      </td>
                      <td className="py-3 pr-4">
                        {ticket.is_eligible ? (
                          <span className="flex items-center gap-1 text-green-400">
                            <CheckCircle className="w-4 h-4" />
                            Eligible
                          </span>
                        ) : (
                          <span className="text-yellow-400 text-xs">
                            Eligible {new Date(ticket.eligible_at).toLocaleDateString()}
                          </span>
                        )}
                      </td>
                      <td className="py-3 text-gray-400">
                        {new Date(ticket.awarded_at).toLocaleDateString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {!user && (
          <div className="bg-gradient-to-br from-yellow-500/10 to-orange-500/10 rounded-2xl p-8 border border-yellow-500/20 text-center">
            <Gift className="w-16 h-16 text-yellow-400 mx-auto mb-4" />
            <h2 className="text-2xl font-bold text-white mb-2">Join the Giveaway!</h2>
            <p className="text-gray-400 mb-6">
              Sign in or create an account to participate in this exciting giveaway and win big prizes!
            </p>
            <div className="flex justify-center gap-4">
              <button
                onClick={() => navigateTo('signin')}
                className="px-6 py-3 bg-gray-800 text-white rounded-lg hover:bg-gray-700 transition-colors"
              >
                Sign In
              </button>
              <button
                onClick={() => navigateTo('signup')}
                className="px-6 py-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-medium rounded-lg hover:opacity-90 transition-opacity"
              >
                Create Account
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

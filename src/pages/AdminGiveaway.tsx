import { useEffect, useState } from 'react';
import { ArrowLeft, Gift, Trophy, Users, Ticket, Calendar, Play, CheckCircle, AlertCircle, RefreshCw, Download, Search, Filter, DollarSign, Percent, Clock, Target, Sparkles, X, ChevronDown, ChevronRight, Eye, BarChart3, Award, Loader } from 'lucide-react';
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
  status: 'draft' | 'active' | 'drawing' | 'completed' | 'cancelled';
  holding_period_days: number;
  total_prize_value: number;
  created_at: string;
}

interface TicketTier {
  id: string;
  campaign_id: string;
  tier_name: string;
  min_deposit: number;
  max_deposit: number | null;
  base_tickets: number;
  bonus_percentage: number;
  guaranteed_bonus_amount: number;
  sort_order: number;
}

interface Prize {
  id: string;
  campaign_id: string;
  name: string;
  prize_type: 'cash' | 'fee_voucher';
  prize_category: 'grand' | 'major' | 'mass';
  amount: number;
  quantity: number;
  remaining_quantity: number;
  sort_order: number;
}

interface Winner {
  winner_id: string;
  user_id: string;
  user_email: string;
  prize_name: string;
  prize_type: string;
  prize_amount: number;
  prize_category: string;
  won_at: string;
  credit_status: string;
  credited_at: string | null;
}

interface Participant {
  ticket_id: string;
  user_id: string;
  ticket_count: number;
  deposit_amount: number;
  tier_name: string;
  guaranteed_bonus_awarded: number;
  awarded_at: string;
  eligible_at: string;
  is_eligible: boolean;
}

interface CampaignStats {
  total_participants: number;
  total_deposits: number;
  total_deposit_amount: number;
  total_tickets: number;
  eligible_tickets: number;
  pending_tickets: number;
  guaranteed_bonuses_awarded: number;
  prizes_awarded: number;
  prizes_credited: number;
}

const DEFAULT_TIERS: Omit<TicketTier, 'id' | 'campaign_id'>[] = [
  { tier_name: 'Bronze', min_deposit: 10, max_deposit: 99.99, base_tickets: 10, bonus_percentage: 0, guaranteed_bonus_amount: 0, sort_order: 0 },
  { tier_name: 'Silver', min_deposit: 100, max_deposit: 499.99, base_tickets: 100, bonus_percentage: 20, guaranteed_bonus_amount: 0, sort_order: 1 },
  { tier_name: 'Gold', min_deposit: 500, max_deposit: 999.99, base_tickets: 500, bonus_percentage: 40, guaranteed_bonus_amount: 0, sort_order: 2 },
  { tier_name: 'Platinum', min_deposit: 1000, max_deposit: null, base_tickets: 1000, bonus_percentage: 60, guaranteed_bonus_amount: 20, sort_order: 3 },
];

const DEFAULT_PRIZES: Omit<Prize, 'id' | 'campaign_id'>[] = [
  { name: '$10,000 Grand Prize', prize_type: 'cash', prize_category: 'grand', amount: 10000, quantity: 1, remaining_quantity: 1, sort_order: 0 },
  { name: '$5,000 Prize', prize_type: 'cash', prize_category: 'grand', amount: 5000, quantity: 2, remaining_quantity: 2, sort_order: 1 },
  { name: '$1,000 Prize', prize_type: 'cash', prize_category: 'grand', amount: 1000, quantity: 5, remaining_quantity: 5, sort_order: 2 },
  { name: '$250 Prize', prize_type: 'cash', prize_category: 'major', amount: 250, quantity: 20, remaining_quantity: 20, sort_order: 3 },
  { name: '$100 Prize', prize_type: 'cash', prize_category: 'major', amount: 100, quantity: 50, remaining_quantity: 50, sort_order: 4 },
  { name: '$50 Prize', prize_type: 'cash', prize_category: 'major', amount: 50, quantity: 100, remaining_quantity: 100, sort_order: 5 },
  { name: '$10 Prize', prize_type: 'cash', prize_category: 'mass', amount: 10, quantity: 1000, remaining_quantity: 1000, sort_order: 6 },
  { name: '$5 Prize', prize_type: 'cash', prize_category: 'mass', amount: 5, quantity: 2000, remaining_quantity: 2000, sort_order: 7 },
  { name: '$5 Fee Voucher', prize_type: 'fee_voucher', prize_category: 'mass', amount: 5, quantity: 5000, remaining_quantity: 5000, sort_order: 8 },
];

export default function AdminGiveaway() {
  const { user, canAccessAdmin, profile, staffInfo, loading: authLoading } = useAuth();
  const { navigateTo } = useNavigation();
  const [hasAccess, setHasAccess] = useState(false);
  const [activeTab, setActiveTab] = useState<'campaigns' | 'draw' | 'winners' | 'participants'>('campaigns');

  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [selectedCampaign, setSelectedCampaign] = useState<Campaign | null>(null);
  const [campaignStats, setCampaignStats] = useState<CampaignStats | null>(null);
  const [tiers, setTiers] = useState<TicketTier[]>([]);
  const [prizes, setPrizes] = useState<Prize[]>([]);
  const [winners, setWinners] = useState<Winner[]>([]);
  const [participants, setParticipants] = useState<Participant[]>([]);

  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [showCreateForm, setShowCreateForm] = useState(false);
  const [formData, setFormData] = useState({
    name: 'New Year Deposit Giveaway 2025',
    description: 'Deposit during the event period to earn tickets and win big prizes!',
    start_date: '',
    end_date: '',
    draw_date: '',
    holding_period_days: 7
  });

  const [showDrawConfirm, setShowDrawConfirm] = useState(false);
  const [drawProgress, setDrawProgress] = useState<{running: boolean; message: string; results: any | null}>({
    running: false,
    message: '',
    results: null
  });

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      navigateTo('signin');
      return;
    }
    if (canAccessAdmin() && (profile?.is_admin || staffInfo?.is_super_admin)) {
      setHasAccess(true);
    } else {
      navigateTo('admin');
    }
  }, [user, profile, staffInfo, authLoading]);

  useEffect(() => {
    if (hasAccess) {
      loadCampaigns();
    }
  }, [hasAccess]);

  useEffect(() => {
    if (selectedCampaign) {
      loadCampaignDetails(selectedCampaign.id);
    }
  }, [selectedCampaign]);

  const loadCampaigns = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('giveaway_campaigns')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setCampaigns(data || []);
      if (data && data.length > 0 && !selectedCampaign) {
        setSelectedCampaign(data[0]);
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadCampaignDetails = async (campaignId: string) => {
    try {
      const [tiersRes, prizesRes, statsRes] = await Promise.all([
        supabase.from('giveaway_ticket_tiers').select('*').eq('campaign_id', campaignId).order('sort_order'),
        supabase.from('giveaway_prizes').select('*').eq('campaign_id', campaignId).order('sort_order'),
        supabase.rpc('get_giveaway_campaign_stats', { p_campaign_id: campaignId })
      ]);

      if (tiersRes.error) throw tiersRes.error;
      if (prizesRes.error) throw prizesRes.error;

      setTiers(tiersRes.data || []);
      setPrizes(prizesRes.data || []);
      setCampaignStats(statsRes.data as CampaignStats);
    } catch (err: any) {
      console.error('Error loading campaign details:', err);
    }
  };

  const loadWinners = async () => {
    if (!selectedCampaign) return;
    try {
      const { data, error } = await supabase.rpc('get_campaign_winners', {
        p_campaign_id: selectedCampaign.id
      });
      if (error) throw error;
      setWinners(data || []);
    } catch (err: any) {
      console.error('Error loading winners:', err);
    }
  };

  const loadParticipants = async () => {
    if (!selectedCampaign) return;
    try {
      const { data, error } = await supabase
        .from('giveaway_tickets')
        .select('*')
        .eq('campaign_id', selectedCampaign.id)
        .order('awarded_at', { ascending: false });
      if (error) throw error;
      setParticipants(data || []);
    } catch (err: any) {
      console.error('Error loading participants:', err);
    }
  };

  useEffect(() => {
    if (activeTab === 'winners' && selectedCampaign) {
      loadWinners();
    } else if (activeTab === 'participants' && selectedCampaign) {
      loadParticipants();
    }
  }, [activeTab, selectedCampaign]);

  const createCampaign = async () => {
    setActionLoading(true);
    setError(null);
    try {
      const { data: campaign, error: campaignError } = await supabase
        .from('giveaway_campaigns')
        .insert({
          name: formData.name,
          description: formData.description,
          start_date: formData.start_date,
          end_date: formData.end_date,
          draw_date: formData.draw_date,
          holding_period_days: formData.holding_period_days,
          status: 'draft',
          created_by: user?.id
        })
        .select()
        .single();

      if (campaignError) throw campaignError;

      const tiersToInsert = DEFAULT_TIERS.map(t => ({
        ...t,
        campaign_id: campaign.id
      }));
      const { error: tiersError } = await supabase
        .from('giveaway_ticket_tiers')
        .insert(tiersToInsert);
      if (tiersError) throw tiersError;

      const prizesToInsert = DEFAULT_PRIZES.map(p => ({
        ...p,
        campaign_id: campaign.id
      }));
      const { error: prizesError } = await supabase
        .from('giveaway_prizes')
        .insert(prizesToInsert);
      if (prizesError) throw prizesError;

      setSuccess('Campaign created successfully!');
      setShowCreateForm(false);
      loadCampaigns();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setActionLoading(false);
    }
  };

  const updateCampaignStatus = async (status: Campaign['status']) => {
    if (!selectedCampaign) return;
    setActionLoading(true);
    try {
      const { error } = await supabase
        .from('giveaway_campaigns')
        .update({ status })
        .eq('id', selectedCampaign.id);
      if (error) throw error;
      setSuccess(`Campaign ${status === 'active' ? 'activated' : status}!`);
      loadCampaigns();
      setSelectedCampaign({ ...selectedCampaign, status });
    } catch (err: any) {
      setError(err.message);
    } finally {
      setActionLoading(false);
    }
  };

  const executeDraw = async () => {
    if (!selectedCampaign) return;
    setShowDrawConfirm(false);
    setDrawProgress({ running: true, message: 'Starting draw...', results: null });

    try {
      setDrawProgress({ running: true, message: 'Updating ticket eligibility...', results: null });
      await supabase.rpc('update_giveaway_ticket_eligibility');

      setDrawProgress({ running: true, message: 'Executing weighted random draw...', results: null });
      const { data, error } = await supabase.rpc('execute_campaign_draw', {
        p_campaign_id: selectedCampaign.id
      });

      if (error) throw error;

      if (!data.success) {
        throw new Error(data.error || 'Draw failed');
      }

      setDrawProgress({ running: true, message: 'Crediting prizes to winners...', results: null });
      const { error: creditError } = await supabase.rpc('credit_all_pending_prizes', {
        p_campaign_id: selectedCampaign.id
      });

      if (creditError) console.error('Some prizes failed to credit:', creditError);

      setDrawProgress({ running: false, message: 'Draw completed!', results: data });
      setSuccess(`Draw completed! ${data.prizes_drawn} prizes awarded to ${data.unique_winners} unique winners.`);
      loadCampaigns();
      loadWinners();
    } catch (err: any) {
      setError(err.message);
      setDrawProgress({ running: false, message: '', results: null });
    }
  };

  const retryCredit = async (winnerId: string) => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('retry_credit_prize', {
        p_winner_id: winnerId
      });
      if (error) throw error;
      if (!data.success) throw new Error(data.error);
      setSuccess('Prize credited successfully!');
      loadWinners();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setActionLoading(false);
    }
  };

  const exportWinners = () => {
    if (winners.length === 0) return;
    const csv = [
      ['Email', 'Prize', 'Type', 'Amount', 'Category', 'Won At', 'Status', 'Credited At'],
      ...winners.map(w => [
        w.user_email,
        w.prize_name,
        w.prize_type,
        w.prize_amount,
        w.prize_category,
        new Date(w.won_at).toLocaleString(),
        w.credit_status,
        w.credited_at ? new Date(w.credited_at).toLocaleString() : ''
      ])
    ].map(row => row.join(',')).join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `giveaway-winners-${selectedCampaign?.name || 'export'}.csv`;
    a.click();
  };

  const getStatusBadge = (status: Campaign['status']) => {
    const styles = {
      draft: 'bg-gray-500/20 text-gray-400',
      active: 'bg-green-500/20 text-green-400',
      drawing: 'bg-yellow-500/20 text-yellow-400',
      completed: 'bg-blue-500/20 text-blue-400',
      cancelled: 'bg-red-500/20 text-red-400'
    };
    return (
      <span className={`px-2 py-1 rounded text-xs font-medium ${styles[status]}`}>
        {status.charAt(0).toUpperCase() + status.slice(1)}
      </span>
    );
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
  };

  if (!hasAccess) return null;

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('admin')}
          className="flex items-center gap-2 text-gray-400 hover:text-white mb-6 transition-colors"
        >
          <ArrowLeft className="w-5 h-5" />
          Back to Dashboard
        </button>

        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-gradient-to-br from-yellow-500/20 to-orange-500/20 rounded-xl">
              <Gift className="w-8 h-8 text-yellow-400" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">Giveaway Management</h1>
              <p className="text-gray-400">Create and manage deposit giveaway campaigns</p>
            </div>
          </div>
          <button
            onClick={() => setShowCreateForm(true)}
            className="px-4 py-2 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-medium rounded-lg hover:opacity-90 transition-opacity flex items-center gap-2"
          >
            <Sparkles className="w-4 h-4" />
            New Campaign
          </button>
        </div>

        {error && (
          <div className="mb-4 p-4 bg-red-500/10 border border-red-500/20 rounded-lg flex items-center gap-3">
            <AlertCircle className="w-5 h-5 text-red-400" />
            <span className="text-red-400">{error}</span>
            <button onClick={() => setError(null)} className="ml-auto text-red-400 hover:text-red-300">
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        {success && (
          <div className="mb-4 p-4 bg-green-500/10 border border-green-500/20 rounded-lg flex items-center gap-3">
            <CheckCircle className="w-5 h-5 text-green-400" />
            <span className="text-green-400">{success}</span>
            <button onClick={() => setSuccess(null)} className="ml-auto text-green-400 hover:text-green-300">
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          <div className="lg:col-span-1 space-y-4">
            <div className="bg-[#1a1d21] rounded-xl p-4 border border-gray-800">
              <h3 className="text-sm font-medium text-gray-400 mb-3">Campaigns</h3>
              {loading ? (
                <div className="flex items-center justify-center py-8">
                  <Loader className="w-6 h-6 text-yellow-400 animate-spin" />
                </div>
              ) : campaigns.length === 0 ? (
                <p className="text-gray-500 text-sm text-center py-4">No campaigns yet</p>
              ) : (
                <div className="space-y-2">
                  {campaigns.map(campaign => (
                    <button
                      key={campaign.id}
                      onClick={() => setSelectedCampaign(campaign)}
                      className={`w-full text-left p-3 rounded-lg transition-colors ${
                        selectedCampaign?.id === campaign.id
                          ? 'bg-yellow-500/10 border border-yellow-500/30'
                          : 'bg-gray-800/50 hover:bg-gray-800 border border-transparent'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-white font-medium text-sm truncate">{campaign.name}</span>
                        {getStatusBadge(campaign.status)}
                      </div>
                      <div className="text-xs text-gray-500">
                        {formatCurrency(campaign.total_prize_value)} prize pool
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div className="lg:col-span-3 space-y-6">
            {selectedCampaign ? (
              <>
                <div className="bg-[#1a1d21] rounded-xl p-6 border border-gray-800">
                  <div className="flex items-start justify-between mb-6">
                    <div>
                      <div className="flex items-center gap-3 mb-2">
                        <h2 className="text-xl font-bold text-white">{selectedCampaign.name}</h2>
                        {getStatusBadge(selectedCampaign.status)}
                      </div>
                      <p className="text-gray-400 text-sm">{selectedCampaign.description}</p>
                    </div>
                    <div className="flex gap-2">
                      {selectedCampaign.status === 'draft' && (
                        <button
                          onClick={() => updateCampaignStatus('active')}
                          disabled={actionLoading}
                          className="px-4 py-2 bg-green-500/20 text-green-400 rounded-lg hover:bg-green-500/30 transition-colors flex items-center gap-2"
                        >
                          <Play className="w-4 h-4" />
                          Activate
                        </button>
                      )}
                      {selectedCampaign.status === 'active' && (
                        <button
                          onClick={() => setShowDrawConfirm(true)}
                          disabled={actionLoading}
                          className="px-4 py-2 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-medium rounded-lg hover:opacity-90 transition-opacity flex items-center gap-2"
                        >
                          <Trophy className="w-4 h-4" />
                          Run Draw
                        </button>
                      )}
                    </div>
                  </div>

                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                    <div className="bg-gray-800/50 rounded-lg p-4">
                      <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
                        <Calendar className="w-4 h-4" />
                        Start Date
                      </div>
                      <p className="text-white font-medium">
                        {new Date(selectedCampaign.start_date).toLocaleDateString()}
                      </p>
                    </div>
                    <div className="bg-gray-800/50 rounded-lg p-4">
                      <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
                        <Calendar className="w-4 h-4" />
                        End Date
                      </div>
                      <p className="text-white font-medium">
                        {new Date(selectedCampaign.end_date).toLocaleDateString()}
                      </p>
                    </div>
                    <div className="bg-gray-800/50 rounded-lg p-4">
                      <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
                        <Trophy className="w-4 h-4" />
                        Draw Date
                      </div>
                      <p className="text-white font-medium">
                        {new Date(selectedCampaign.draw_date).toLocaleDateString()}
                      </p>
                    </div>
                    <div className="bg-gray-800/50 rounded-lg p-4">
                      <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
                        <Clock className="w-4 h-4" />
                        Holding Period
                      </div>
                      <p className="text-white font-medium">{selectedCampaign.holding_period_days} days</p>
                    </div>
                  </div>

                  {campaignStats && (
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div className="bg-gradient-to-br from-blue-500/10 to-blue-600/5 rounded-lg p-4 border border-blue-500/20">
                        <div className="flex items-center gap-2 text-blue-400 text-sm mb-1">
                          <Users className="w-4 h-4" />
                          Participants
                        </div>
                        <p className="text-2xl font-bold text-white">{campaignStats.total_participants}</p>
                      </div>
                      <div className="bg-gradient-to-br from-green-500/10 to-green-600/5 rounded-lg p-4 border border-green-500/20">
                        <div className="flex items-center gap-2 text-green-400 text-sm mb-1">
                          <Ticket className="w-4 h-4" />
                          Total Tickets
                        </div>
                        <p className="text-2xl font-bold text-white">{campaignStats.total_tickets.toLocaleString()}</p>
                        <p className="text-xs text-gray-500">
                          {campaignStats.eligible_tickets.toLocaleString()} eligible
                        </p>
                      </div>
                      <div className="bg-gradient-to-br from-yellow-500/10 to-yellow-600/5 rounded-lg p-4 border border-yellow-500/20">
                        <div className="flex items-center gap-2 text-yellow-400 text-sm mb-1">
                          <DollarSign className="w-4 h-4" />
                          Total Deposited
                        </div>
                        <p className="text-2xl font-bold text-white">
                          {formatCurrency(campaignStats.total_deposit_amount)}
                        </p>
                      </div>
                      <div className="bg-gradient-to-br from-purple-500/10 to-purple-600/5 rounded-lg p-4 border border-purple-500/20">
                        <div className="flex items-center gap-2 text-purple-400 text-sm mb-1">
                          <Award className="w-4 h-4" />
                          Prizes Credited
                        </div>
                        <p className="text-2xl font-bold text-white">
                          {campaignStats.prizes_credited}/{campaignStats.prizes_awarded}
                        </p>
                      </div>
                    </div>
                  )}
                </div>

                <div className="flex gap-2 border-b border-gray-800">
                  {(['campaigns', 'draw', 'winners', 'participants'] as const).map(tab => (
                    <button
                      key={tab}
                      onClick={() => setActiveTab(tab)}
                      className={`px-4 py-3 font-medium transition-colors ${
                        activeTab === tab
                          ? 'text-yellow-400 border-b-2 border-yellow-400'
                          : 'text-gray-400 hover:text-white'
                      }`}
                    >
                      {tab === 'campaigns' ? 'Tiers & Prizes' : tab.charAt(0).toUpperCase() + tab.slice(1)}
                    </button>
                  ))}
                </div>

                {activeTab === 'campaigns' && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="bg-[#1a1d21] rounded-xl p-6 border border-gray-800">
                      <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                        <Ticket className="w-5 h-5 text-yellow-400" />
                        Ticket Tiers
                      </h3>
                      <div className="space-y-3">
                        {tiers.map(tier => (
                          <div key={tier.id} className="bg-gray-800/50 rounded-lg p-4">
                            <div className="flex items-center justify-between mb-2">
                              <span className="text-white font-medium">{tier.tier_name}</span>
                              <span className="text-yellow-400 font-bold">
                                {tier.base_tickets + Math.floor(tier.base_tickets * tier.bonus_percentage / 100)} tickets
                              </span>
                            </div>
                            <div className="text-sm text-gray-400">
                              {formatCurrency(tier.min_deposit)} - {tier.max_deposit ? formatCurrency(tier.max_deposit) : 'No limit'}
                            </div>
                            {tier.guaranteed_bonus_amount > 0 && (
                              <div className="mt-2 text-sm text-green-400">
                                + {formatCurrency(tier.guaranteed_bonus_amount)} instant bonus
                              </div>
                            )}
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="bg-[#1a1d21] rounded-xl p-6 border border-gray-800">
                      <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                        <Trophy className="w-5 h-5 text-yellow-400" />
                        Prize Pool ({formatCurrency(selectedCampaign.total_prize_value)})
                      </h3>
                      <div className="space-y-4">
                        {['grand', 'major', 'mass'].map(category => {
                          const categoryPrizes = prizes.filter(p => p.prize_category === category);
                          if (categoryPrizes.length === 0) return null;
                          return (
                            <div key={category}>
                              <h4 className="text-sm font-medium text-gray-400 uppercase mb-2">
                                {category} Prizes
                              </h4>
                              <div className="space-y-2">
                                {categoryPrizes.map(prize => (
                                  <div key={prize.id} className="flex items-center justify-between bg-gray-800/50 rounded-lg p-3">
                                    <div>
                                      <span className="text-white">{prize.name}</span>
                                      {prize.prize_type === 'fee_voucher' && (
                                        <span className="ml-2 text-xs bg-blue-500/20 text-blue-400 px-2 py-0.5 rounded">
                                          Fee Voucher
                                        </span>
                                      )}
                                    </div>
                                    <div className="text-right">
                                      <span className="text-gray-400">
                                        {prize.remaining_quantity}/{prize.quantity}
                                      </span>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                )}

                {activeTab === 'draw' && (
                  <div className="bg-[#1a1d21] rounded-xl p-6 border border-gray-800">
                    <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
                      <Target className="w-5 h-5 text-yellow-400" />
                      Draw Execution
                    </h3>

                    {drawProgress.running && (
                      <div className="mb-6 p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-lg">
                        <div className="flex items-center gap-3">
                          <Loader className="w-5 h-5 text-yellow-400 animate-spin" />
                          <span className="text-yellow-400">{drawProgress.message}</span>
                        </div>
                      </div>
                    )}

                    {drawProgress.results && (
                      <div className="mb-6 p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
                        <h4 className="text-green-400 font-medium mb-2">Draw Results</h4>
                        <div className="grid grid-cols-3 gap-4 text-sm">
                          <div>
                            <span className="text-gray-400">Total Tickets:</span>
                            <span className="text-white ml-2">{drawProgress.results.total_tickets?.toLocaleString()}</span>
                          </div>
                          <div>
                            <span className="text-gray-400">Prizes Drawn:</span>
                            <span className="text-white ml-2">{drawProgress.results.prizes_drawn}</span>
                          </div>
                          <div>
                            <span className="text-gray-400">Unique Winners:</span>
                            <span className="text-white ml-2">{drawProgress.results.unique_winners}</span>
                          </div>
                        </div>
                      </div>
                    )}

                    <div className="space-y-4">
                      <div className="bg-gray-800/50 rounded-lg p-4">
                        <h4 className="text-white font-medium mb-3">Pre-Draw Checklist</h4>
                        <div className="space-y-2">
                          <div className="flex items-center gap-3">
                            {selectedCampaign.status === 'active' ? (
                              <CheckCircle className="w-5 h-5 text-green-400" />
                            ) : (
                              <AlertCircle className="w-5 h-5 text-red-400" />
                            )}
                            <span className="text-gray-300">Campaign is active</span>
                          </div>
                          <div className="flex items-center gap-3">
                            {new Date(selectedCampaign.end_date) <= new Date() ? (
                              <CheckCircle className="w-5 h-5 text-green-400" />
                            ) : (
                              <AlertCircle className="w-5 h-5 text-yellow-400" />
                            )}
                            <span className="text-gray-300">
                              Campaign end date passed ({new Date(selectedCampaign.end_date).toLocaleDateString()})
                            </span>
                          </div>
                          <div className="flex items-center gap-3">
                            {campaignStats && campaignStats.total_tickets > 0 ? (
                              <CheckCircle className="w-5 h-5 text-green-400" />
                            ) : (
                              <AlertCircle className="w-5 h-5 text-red-400" />
                            )}
                            <span className="text-gray-300">
                              Participants available ({campaignStats?.total_participants || 0})
                            </span>
                          </div>
                          <div className="flex items-center gap-3">
                            {prizes.some(p => p.remaining_quantity > 0) ? (
                              <CheckCircle className="w-5 h-5 text-green-400" />
                            ) : (
                              <AlertCircle className="w-5 h-5 text-red-400" />
                            )}
                            <span className="text-gray-300">
                              Prizes configured ({prizes.reduce((sum, p) => sum + p.remaining_quantity, 0)} remaining)
                            </span>
                          </div>
                        </div>
                      </div>

                      {selectedCampaign.status === 'active' && (
                        <button
                          onClick={() => setShowDrawConfirm(true)}
                          disabled={actionLoading || drawProgress.running}
                          className="w-full py-4 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-bold rounded-xl hover:opacity-90 transition-opacity flex items-center justify-center gap-2"
                        >
                          <Trophy className="w-5 h-5" />
                          Execute Draw
                        </button>
                      )}

                      {selectedCampaign.status === 'completed' && (
                        <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg text-center">
                          <CheckCircle className="w-8 h-8 text-blue-400 mx-auto mb-2" />
                          <p className="text-blue-400">Draw has been completed for this campaign</p>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {activeTab === 'winners' && (
                  <div className="bg-[#1a1d21] rounded-xl p-6 border border-gray-800">
                    <div className="flex items-center justify-between mb-6">
                      <h3 className="text-lg font-semibold text-white flex items-center gap-2">
                        <Award className="w-5 h-5 text-yellow-400" />
                        Winners ({winners.length})
                      </h3>
                      {winners.length > 0 && (
                        <button
                          onClick={exportWinners}
                          className="px-4 py-2 bg-gray-800 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors flex items-center gap-2"
                        >
                          <Download className="w-4 h-4" />
                          Export CSV
                        </button>
                      )}
                    </div>

                    {winners.length === 0 ? (
                      <div className="text-center py-8 text-gray-500">
                        No winners yet. Run the draw to select winners.
                      </div>
                    ) : (
                      <div className="overflow-x-auto">
                        <table className="w-full">
                          <thead>
                            <tr className="text-left text-gray-400 text-sm border-b border-gray-800">
                              <th className="pb-3 pr-4">User</th>
                              <th className="pb-3 pr-4">Prize</th>
                              <th className="pb-3 pr-4">Type</th>
                              <th className="pb-3 pr-4">Amount</th>
                              <th className="pb-3 pr-4">Status</th>
                              <th className="pb-3">Action</th>
                            </tr>
                          </thead>
                          <tbody className="text-sm">
                            {winners.map(winner => (
                              <tr key={winner.winner_id} className="border-b border-gray-800/50">
                                <td className="py-3 pr-4 text-white">{winner.user_email}</td>
                                <td className="py-3 pr-4 text-gray-300">{winner.prize_name}</td>
                                <td className="py-3 pr-4">
                                  <span className={`px-2 py-1 rounded text-xs ${
                                    winner.prize_type === 'cash'
                                      ? 'bg-green-500/20 text-green-400'
                                      : 'bg-blue-500/20 text-blue-400'
                                  }`}>
                                    {winner.prize_type === 'cash' ? 'Cash' : 'Fee Voucher'}
                                  </span>
                                </td>
                                <td className="py-3 pr-4 text-yellow-400 font-medium">
                                  {formatCurrency(winner.prize_amount)}
                                </td>
                                <td className="py-3 pr-4">
                                  <span className={`px-2 py-1 rounded text-xs ${
                                    winner.credit_status === 'credited'
                                      ? 'bg-green-500/20 text-green-400'
                                      : winner.credit_status === 'failed'
                                      ? 'bg-red-500/20 text-red-400'
                                      : 'bg-yellow-500/20 text-yellow-400'
                                  }`}>
                                    {winner.credit_status}
                                  </span>
                                </td>
                                <td className="py-3">
                                  {winner.credit_status === 'failed' && (
                                    <button
                                      onClick={() => retryCredit(winner.winner_id)}
                                      disabled={actionLoading}
                                      className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded text-xs hover:bg-yellow-500/30 transition-colors"
                                    >
                                      <RefreshCw className="w-3 h-3" />
                                    </button>
                                  )}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                )}

                {activeTab === 'participants' && (
                  <div className="bg-[#1a1d21] rounded-xl p-6 border border-gray-800">
                    <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
                      <Users className="w-5 h-5 text-yellow-400" />
                      Participants ({participants.length})
                    </h3>

                    {participants.length === 0 ? (
                      <div className="text-center py-8 text-gray-500">
                        No participants yet.
                      </div>
                    ) : (
                      <div className="overflow-x-auto">
                        <table className="w-full">
                          <thead>
                            <tr className="text-left text-gray-400 text-sm border-b border-gray-800">
                              <th className="pb-3 pr-4">Deposit</th>
                              <th className="pb-3 pr-4">Tier</th>
                              <th className="pb-3 pr-4">Tickets</th>
                              <th className="pb-3 pr-4">Bonus</th>
                              <th className="pb-3 pr-4">Eligible</th>
                              <th className="pb-3">Awarded</th>
                            </tr>
                          </thead>
                          <tbody className="text-sm">
                            {participants.map(p => (
                              <tr key={p.ticket_id} className="border-b border-gray-800/50">
                                <td className="py-3 pr-4 text-white font-medium">
                                  {formatCurrency(p.deposit_amount)}
                                </td>
                                <td className="py-3 pr-4 text-gray-300">{p.tier_name}</td>
                                <td className="py-3 pr-4 text-yellow-400 font-medium">
                                  {p.ticket_count.toLocaleString()}
                                </td>
                                <td className="py-3 pr-4">
                                  {p.guaranteed_bonus_awarded > 0 ? (
                                    <span className="text-green-400">
                                      +{formatCurrency(p.guaranteed_bonus_awarded)}
                                    </span>
                                  ) : (
                                    <span className="text-gray-500">-</span>
                                  )}
                                </td>
                                <td className="py-3 pr-4">
                                  {p.is_eligible ? (
                                    <span className="text-green-400 flex items-center gap-1">
                                      <CheckCircle className="w-4 h-4" />
                                      Yes
                                    </span>
                                  ) : (
                                    <span className="text-yellow-400 text-xs">
                                      {new Date(p.eligible_at).toLocaleDateString()}
                                    </span>
                                  )}
                                </td>
                                <td className="py-3 text-gray-400">
                                  {new Date(p.awarded_at).toLocaleDateString()}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                )}
              </>
            ) : (
              <div className="bg-[#1a1d21] rounded-xl p-12 border border-gray-800 text-center">
                <Gift className="w-16 h-16 text-gray-600 mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-white mb-2">No Campaign Selected</h3>
                <p className="text-gray-400 mb-6">Select a campaign from the list or create a new one</p>
                <button
                  onClick={() => setShowCreateForm(true)}
                  className="px-6 py-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-medium rounded-lg hover:opacity-90 transition-opacity"
                >
                  Create New Campaign
                </button>
              </div>
            )}
          </div>
        </div>

        {showCreateForm && (
          <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
            <div className="bg-[#1a1d21] rounded-xl max-w-lg w-full p-6 border border-gray-800">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-white">Create New Campaign</h3>
                <button onClick={() => setShowCreateForm(false)} className="text-gray-400 hover:text-white">
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Campaign Name</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={e => setFormData({ ...formData, name: e.target.value })}
                    className="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:border-yellow-500 focus:outline-none"
                    placeholder="New Year Giveaway 2025"
                  />
                </div>

                <div>
                  <label className="block text-sm text-gray-400 mb-2">Description</label>
                  <textarea
                    value={formData.description}
                    onChange={e => setFormData({ ...formData, description: e.target.value })}
                    className="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:border-yellow-500 focus:outline-none"
                    rows={2}
                    placeholder="Deposit to earn tickets..."
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Start Date</label>
                    <input
                      type="datetime-local"
                      value={formData.start_date}
                      onChange={e => setFormData({ ...formData, start_date: e.target.value })}
                      className="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:border-yellow-500 focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">End Date</label>
                    <input
                      type="datetime-local"
                      value={formData.end_date}
                      onChange={e => setFormData({ ...formData, end_date: e.target.value })}
                      className="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:border-yellow-500 focus:outline-none"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Draw Date</label>
                    <input
                      type="datetime-local"
                      value={formData.draw_date}
                      onChange={e => setFormData({ ...formData, draw_date: e.target.value })}
                      className="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:border-yellow-500 focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Holding Period (days)</label>
                    <input
                      type="number"
                      value={formData.holding_period_days}
                      onChange={e => setFormData({ ...formData, holding_period_days: parseInt(e.target.value) || 7 })}
                      className="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:border-yellow-500 focus:outline-none"
                      min={1}
                    />
                  </div>
                </div>

                <div className="bg-gray-800/50 rounded-lg p-4 text-sm text-gray-400">
                  <p className="mb-2">Default configuration will be applied:</p>
                  <ul className="list-disc list-inside space-y-1">
                    <li>4 deposit tiers: Bronze ($10+), Silver ($100+), Gold ($500+), Platinum ($1000+)</li>
                    <li>Prize pool: $10K grand + majors + 5,000 fee vouchers</li>
                    <li>Platinum tier receives $20 instant bonus</li>
                  </ul>
                </div>
              </div>

              <div className="flex justify-end gap-3 mt-6">
                <button
                  onClick={() => setShowCreateForm(false)}
                  className="px-6 py-3 bg-gray-800 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={createCampaign}
                  disabled={actionLoading || !formData.name || !formData.start_date || !formData.end_date || !formData.draw_date}
                  className="px-6 py-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-medium rounded-lg hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  {actionLoading ? (
                    <Loader className="w-4 h-4 animate-spin" />
                  ) : (
                    <Sparkles className="w-4 h-4" />
                  )}
                  Create Campaign
                </button>
              </div>
            </div>
          </div>
        )}

        {showDrawConfirm && (
          <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
            <div className="bg-[#1a1d21] rounded-xl max-w-md w-full p-6 border border-gray-800">
              <div className="text-center mb-6">
                <div className="w-16 h-16 bg-gradient-to-br from-yellow-500/20 to-orange-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
                  <Trophy className="w-8 h-8 text-yellow-400" />
                </div>
                <h3 className="text-xl font-bold text-white mb-2">Confirm Draw Execution</h3>
                <p className="text-gray-400">
                  This will execute the weighted random draw for all {campaignStats?.eligible_tickets.toLocaleString()} eligible tickets.
                  This action cannot be undone.
                </p>
              </div>

              <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4 mb-6">
                <div className="flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-yellow-400 mt-0.5" />
                  <div className="text-sm text-yellow-400">
                    <p className="font-medium mb-1">Before proceeding:</p>
                    <ul className="list-disc list-inside space-y-1 text-yellow-400/80">
                      <li>Verify the campaign end date has passed</li>
                      <li>Ensure all tickets have met holding period</li>
                      <li>Confirm prize pool is correctly configured</li>
                    </ul>
                  </div>
                </div>
              </div>

              <div className="flex justify-end gap-3">
                <button
                  onClick={() => setShowDrawConfirm(false)}
                  className="px-6 py-3 bg-gray-800 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={executeDraw}
                  className="px-6 py-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-black font-bold rounded-lg hover:opacity-90 transition-opacity flex items-center gap-2"
                >
                  <Play className="w-4 h-4" />
                  Execute Draw
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

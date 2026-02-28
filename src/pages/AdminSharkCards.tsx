import { useState, useEffect } from 'react';
import { CreditCard, CheckCircle, XCircle, Send, Calendar, DollarSign, User, Globe, Clock, Filter, ArrowLeft, Edit3, Plus, Receipt, Lock, Unlock, Wallet } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import { useNavigation } from '../App';

interface SharkCardApplication {
  application_id: string;
  user_id: string;
  full_name: string;
  country: string;
  requested_limit: number;
  locked_amount: number;
  status: string;
  application_date: string;
  reviewed_at: string | null;
  reviewed_by: string | null;
  rejection_reason: string | null;
  notes: string | null;
  user_email?: string;
}

interface SharkCard {
  card_id: string;
  user_id: string;
  card_number: string;
  card_holder_name: string;
  credit_limit: number;
  available_credit: number;
  used_credit: number;
  cashback_rate: number;
  issue_date: string;
  expiry_date: string;
  status: string;
  card_type: string;
  user_email?: string;
}

export default function AdminSharkCards() {
  const { navigateTo } = useNavigation();
  const [activeTab, setActiveTab] = useState<'applications' | 'cards'>('applications');
  const [applications, setApplications] = useState<SharkCardApplication[]>([]);
  const [cards, setCards] = useState<SharkCard[]>([]);
  const [filteredApplications, setFilteredApplications] = useState<SharkCardApplication[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string>('all');
  const [isLoading, setIsLoading] = useState(true);
  const [selectedApplication, setSelectedApplication] = useState<SharkCardApplication | null>(null);
  const [selectedCard, setSelectedCard] = useState<SharkCard | null>(null);
  const [approvalModal, setApprovalModal] = useState(false);
  const [declineModal, setDeclineModal] = useState(false);
  const [issueModal, setIssueModal] = useState(false);
  const [editBalanceModal, setEditBalanceModal] = useState(false);
  const [addTransactionModal, setAddTransactionModal] = useState(false);
  const [approvedLimit, setApprovedLimit] = useState(0);
  const [newBalance, setNewBalance] = useState(0);
  const [txDescription, setTxDescription] = useState('');
  const [txAmount, setTxAmount] = useState('');
  const [txMerchant, setTxMerchant] = useState('');
  const [txType, setTxType] = useState<'purchase' | 'fee' | 'refund' | 'adjustment' | 'cashback'>('purchase');
  const [txStatus, setTxStatus] = useState<'approved' | 'declined' | 'pending'>('approved');
  const [cardType, setCardType] = useState('gold');
  const [cashbackRate, setCashbackRate] = useState(1.0);
  const [declineReason, setDeclineReason] = useState('');
  const [cardNumber, setCardNumber] = useState('');
  const [cardholderName, setCardholderName] = useState('');
  const [expiryMonth, setExpiryMonth] = useState('');
  const [expiryYear, setExpiryYear] = useState('');
  const [cvv, setCvv] = useState('');
  const { showToast } = useToast();

  useEffect(() => {
    fetchApplications();
    fetchCards();
  }, []);

  useEffect(() => {
    if (selectedStatus === 'all') {
      setFilteredApplications(applications);
    } else {
      setFilteredApplications(applications.filter(app => app.status === selectedStatus));
    }
  }, [selectedStatus, applications]);

  const fetchApplications = async () => {
    try {
      const { data, error } = await supabase
        .from('shark_card_applications')
        .select('*')
        .order('application_date', { ascending: false });

      if (error) throw error;

      const { data: userData } = await supabase.auth.admin.listUsers();
      const userEmails = new Map(userData?.users.map(u => [u.id, u.email]) || []);

      const formattedData = data?.map((app: any) => ({
        ...app,
        locked_amount: app.locked_amount || app.requested_limit,
        user_email: userEmails.get(app.user_id) || 'Unknown'
      })) || [];

      setApplications(formattedData);
      setFilteredApplications(formattedData);
    } catch (error: any) {
      showToast(error.message, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchCards = async () => {
    try {
      const { data, error } = await supabase
        .from('shark_cards')
        .select('*')
        .order('issue_date', { ascending: false });

      if (error) throw error;

      const { data: userData } = await supabase.auth.admin.listUsers();
      const userEmails = new Map(userData?.users.map(u => [u.id, u.email]) || []);

      const formattedData = data?.map((card: any) => ({
        ...card,
        user_email: userEmails.get(card.user_id) || 'Unknown'
      })) || [];

      setCards(formattedData);
    } catch (error: any) {
      showToast(error.message, 'error');
    }
  };

  const handleApprove = async () => {
    if (!selectedApplication) return;

    try {
      const { data, error } = await supabase.rpc('approve_shark_card_application', {
        p_application_id: selectedApplication.application_id,
        p_approved_limit: approvedLimit,
        p_card_type: cardType,
        p_cashback_rate: cashbackRate
      });

      if (error) throw error;

      if (data?.success) {
        showToast(`Application approved! ${approvedLimit.toLocaleString()} USDT transferred to card wallet.`, 'success');
        setApprovalModal(false);
        fetchApplications();
      } else {
        throw new Error(data?.error || 'Failed to approve application');
      }
    } catch (error: any) {
      showToast(error.message, 'error');
    }
  };

  const handleDecline = async () => {
    if (!selectedApplication) return;

    try {
      const { data, error } = await supabase.rpc('decline_shark_card_application', {
        p_application_id: selectedApplication.application_id,
        p_reason: declineReason
      });

      if (error) throw error;

      if (data?.success) {
        showToast(`Application declined. ${data.unlocked_amount?.toLocaleString() || selectedApplication.locked_amount.toLocaleString()} USDT unlocked.`, 'success');
        setDeclineModal(false);
        setDeclineReason('');
        fetchApplications();
      } else {
        throw new Error(data?.error || 'Failed to decline application');
      }
    } catch (error: any) {
      showToast(error.message, 'error');
    }
  };

  const handleIssueCard = async () => {
    if (!selectedApplication) return;

    if (!cardNumber || !cardholderName || !expiryMonth || !expiryYear || !cvv) {
      showToast('Please fill in all card details', 'error');
      return;
    }

    if (cardNumber.length !== 16) {
      showToast('Card number must be 16 digits', 'error');
      return;
    }

    if (cvv.length !== 3) {
      showToast('CVV must be 3 digits', 'error');
      return;
    }

    try {
      const { data, error } = await supabase.rpc('admin_issue_shark_card', {
        p_application_id: selectedApplication.application_id,
        p_card_number: cardNumber,
        p_cardholder_name: cardholderName,
        p_expiry_month: expiryMonth,
        p_expiry_year: expiryYear,
        p_cvv: cvv,
        p_card_type: cardType
      });

      if (error) throw error;

      if (data?.success) {
        showToast('Card issued successfully!', 'success');
        setIssueModal(false);
        setCardNumber('');
        setCardholderName('');
        setExpiryMonth('');
        setExpiryYear('');
        setCvv('');
        fetchApplications();
        fetchCards();
      } else {
        throw new Error(data?.error || 'Failed to issue card');
      }
    } catch (error: any) {
      showToast(error.message, 'error');
    }
  };

  const handleAdjustBalance = async () => {
    if (!selectedCard) return;

    if (newBalance < 0) {
      showToast('Balance cannot be negative', 'error');
      return;
    }

    try {
      const { data, error } = await supabase.rpc('admin_adjust_card_balance', {
        p_card_id: selectedCard.card_id,
        p_new_balance: newBalance
      });

      if (error) throw error;

      if (data?.success) {
        showToast(`Balance updated from $${data.old_balance} to $${data.new_balance} USDT`, 'success');
        setEditBalanceModal(false);
        fetchCards();
      } else {
        throw new Error(data?.error || 'Failed to adjust balance');
      }
    } catch (error: any) {
      showToast(error.message, 'error');
    }
  };

  const handleAddTransaction = async () => {
    if (!selectedCard) return;

    if (!txDescription || !txAmount) {
      showToast('Please fill in description and amount', 'error');
      return;
    }

    try {
      const { data, error } = await supabase.rpc('create_card_transaction', {
        p_user_id: selectedCard.user_id,
        p_description: txDescription,
        p_amount: parseFloat(txAmount),
        p_transaction_type: txType,
        p_status: txStatus,
        p_merchant: txMerchant || null
      });

      if (error) throw error;

      const result = data as { success: boolean; error?: string };
      if (!result.success) {
        throw new Error(result.error || 'Failed to create transaction');
      }

      showToast('Transaction created successfully', 'success');
      setAddTransactionModal(false);
      setTxDescription('');
      setTxAmount('');
      setTxMerchant('');
      setTxType('purchase');
      setTxStatus('approved');
      fetchCards();
    } catch (error: any) {
      showToast(error.message, 'error');
    }
  };

  const getStatusBadge = (status: string) => {
    const styles = {
      pending: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/30',
      approved: 'bg-green-500/20 text-green-300 border-green-500/30',
      declined: 'bg-red-500/20 text-red-300 border-red-500/30',
      issued: 'bg-blue-500/20 text-blue-300 border-blue-500/30',
      cancelled: 'bg-slate-500/20 text-slate-300 border-slate-500/30',
    };

    return (
      <span className={`px-3 py-1 rounded-full text-xs font-medium border ${styles[status as keyof typeof styles] || styles.pending}`}>
        {status.charAt(0).toUpperCase() + status.slice(1)}
      </span>
    );
  };

  const getCardTypeBadge = (type: string) => {
    const styles = {
      standard: 'bg-slate-500/20 text-slate-300',
      gold: 'bg-amber-500/20 text-amber-300',
      platinum: 'bg-slate-300/20 text-slate-100',
    };

    return (
      <span className={`px-3 py-1 rounded-lg text-xs font-medium ${styles[type as keyof typeof styles]}`}>
        {type.charAt(0).toUpperCase() + type.slice(1)}
      </span>
    );
  };

  const stats = {
    total: applications.length,
    pending: applications.filter(app => app.status === 'pending').length,
    approved: applications.filter(app => app.status === 'approved').length,
    issued: applications.filter(app => app.status === 'issued').length,
    declined: applications.filter(app => app.status === 'declined').length,
  };

  const totalLockedAmount = applications
    .filter(app => app.status === 'pending')
    .reduce((sum, app) => sum + (app.locked_amount || 0), 0);

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        <button
          onClick={() => navigateTo('admindashboard')}
          className="flex items-center gap-2 text-slate-400 hover:text-white transition-colors mb-4"
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Back to Dashboard</span>
        </button>

        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="bg-gradient-to-br from-amber-500 to-orange-600 p-3 rounded-xl">
              <CreditCard className="w-8 h-8 text-white" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-white">Shark Card Management</h1>
              <p className="text-slate-400">Manage credit card applications and issued cards</p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-6 gap-4">
          <div className="bg-slate-800/50 border border-slate-700 rounded-xl p-4">
            <div className="text-slate-400 text-sm mb-1">Total Applications</div>
            <div className="text-3xl font-bold text-white">{stats.total}</div>
          </div>
          <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-xl p-4">
            <div className="text-yellow-400 text-sm mb-1">Pending</div>
            <div className="text-3xl font-bold text-yellow-300">{stats.pending}</div>
          </div>
          <div className="bg-green-500/10 border border-green-500/20 rounded-xl p-4">
            <div className="text-green-400 text-sm mb-1">Approved</div>
            <div className="text-3xl font-bold text-green-300">{stats.approved}</div>
          </div>
          <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl p-4">
            <div className="text-blue-400 text-sm mb-1">Issued</div>
            <div className="text-3xl font-bold text-blue-300">{stats.issued}</div>
          </div>
          <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4">
            <div className="text-red-400 text-sm mb-1">Declined</div>
            <div className="text-3xl font-bold text-red-300">{stats.declined}</div>
          </div>
          <div className="bg-amber-500/10 border border-amber-500/20 rounded-xl p-4">
            <div className="text-amber-400 text-sm mb-1 flex items-center gap-1">
              <Lock className="w-3 h-3" />
              Total Locked
            </div>
            <div className="text-2xl font-bold text-amber-300">${totalLockedAmount.toLocaleString()}</div>
          </div>
        </div>

        <div className="flex gap-2 border-b border-slate-700">
          <button
            onClick={() => setActiveTab('applications')}
            className={`px-6 py-3 font-medium transition-colors border-b-2 ${
              activeTab === 'applications'
                ? 'text-amber-500 border-amber-500'
                : 'text-slate-400 border-transparent hover:text-white'
            }`}
          >
            Applications ({applications.length})
          </button>
          <button
            onClick={() => setActiveTab('cards')}
            className={`px-6 py-3 font-medium transition-colors border-b-2 ${
              activeTab === 'cards'
                ? 'text-amber-500 border-amber-500'
                : 'text-slate-400 border-transparent hover:text-white'
            }`}
          >
            Issued Cards ({cards.length})
          </button>
        </div>

        {activeTab === 'applications' && (
          <>
            <div className="flex items-center gap-3 bg-slate-800/50 border border-slate-700 rounded-xl p-4">
              <Filter className="w-5 h-5 text-amber-500" />
              <select
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-amber-500/50"
              >
                <option value="all">All Statuses</option>
                <option value="pending">Pending</option>
                <option value="approved">Approved</option>
                <option value="declined">Declined</option>
                <option value="issued">Issued</option>
                <option value="cancelled">Cancelled</option>
              </select>
            </div>

            <div className="space-y-3">
              {filteredApplications.map((app) => (
                <div key={app.application_id} className="bg-slate-800/50 border border-slate-700 rounded-xl p-6 hover:border-amber-500/30 transition-colors">
                  <div className="flex items-start justify-between">
                    <div className="flex-1 space-y-3">
                      <div className="flex items-center gap-4">
                        <div className="flex items-center gap-2">
                          <User className="w-4 h-4 text-amber-500" />
                          <span className="text-white font-semibold">{app.full_name}</span>
                        </div>
                        {getStatusBadge(app.status)}
                        {app.status === 'pending' && (
                          <div className="flex items-center gap-1 px-2 py-1 bg-amber-500/10 border border-amber-500/20 rounded-lg">
                            <Lock className="w-3 h-3 text-amber-400" />
                            <span className="text-xs text-amber-400 font-medium">${app.locked_amount?.toLocaleString() || app.requested_limit.toLocaleString()} Locked</span>
                          </div>
                        )}
                        {app.status === 'approved' && (
                          <div className="flex items-center gap-1 px-2 py-1 bg-green-500/10 border border-green-500/20 rounded-lg">
                            <Wallet className="w-3 h-3 text-green-400" />
                            <span className="text-xs text-green-400 font-medium">Funds in Card Wallet</span>
                          </div>
                        )}
                      </div>

                      <div className="grid grid-cols-2 md:grid-cols-5 gap-4 text-sm">
                        <div>
                          <div className="text-slate-400 mb-1">Email</div>
                          <div className="text-white">{app.user_email}</div>
                        </div>
                        <div>
                          <div className="text-slate-400 mb-1 flex items-center gap-1">
                            <Globe className="w-3 h-3" />
                            Country
                          </div>
                          <div className="text-white">{app.country}</div>
                        </div>
                        <div>
                          <div className="text-slate-400 mb-1 flex items-center gap-1">
                            <DollarSign className="w-3 h-3" />
                            Requested
                          </div>
                          <div className="text-white font-semibold">${app.requested_limit.toLocaleString()} USDT</div>
                        </div>
                        <div>
                          <div className="text-slate-400 mb-1 flex items-center gap-1">
                            <Lock className="w-3 h-3" />
                            Locked
                          </div>
                          <div className={`font-semibold ${app.status === 'pending' ? 'text-amber-400' : app.status === 'declined' || app.status === 'cancelled' ? 'text-slate-500' : 'text-green-400'}`}>
                            ${(app.locked_amount || app.requested_limit).toLocaleString()} USDT
                          </div>
                        </div>
                        <div>
                          <div className="text-slate-400 mb-1 flex items-center gap-1">
                            <Clock className="w-3 h-3" />
                            Applied
                          </div>
                          <div className="text-white">{new Date(app.application_date).toLocaleDateString()}</div>
                        </div>
                      </div>

                      {app.rejection_reason && (
                        <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                          <div className="text-red-400 text-sm font-medium mb-1">Decline Reason</div>
                          <div className="text-slate-300 text-sm">{app.rejection_reason}</div>
                        </div>
                      )}

                      {(app.status === 'declined' || app.status === 'cancelled') && (
                        <div className="bg-slate-700/30 border border-slate-600/30 rounded-lg p-3">
                          <div className="flex items-center gap-2 text-slate-400 text-sm">
                            <Unlock className="w-4 h-4" />
                            <span>Funds unlocked and returned to user's main wallet</span>
                          </div>
                        </div>
                      )}
                    </div>

                    {app.status === 'pending' && (
                      <div className="flex gap-2">
                        <button
                          onClick={() => {
                            setSelectedApplication(app);
                            setApprovedLimit(app.locked_amount || app.requested_limit);
                            setApprovalModal(true);
                          }}
                          className="px-4 py-2 bg-green-500/20 text-green-300 rounded-lg hover:bg-green-500/30 transition-colors flex items-center gap-2"
                        >
                          <CheckCircle className="w-4 h-4" />
                          Approve
                        </button>
                        <button
                          onClick={() => {
                            setSelectedApplication(app);
                            setDeclineModal(true);
                          }}
                          className="px-4 py-2 bg-red-500/20 text-red-300 rounded-lg hover:bg-red-500/30 transition-colors flex items-center gap-2"
                        >
                          <XCircle className="w-4 h-4" />
                          Decline
                        </button>
                      </div>
                    )}

                    {app.status === 'approved' && (
                      <button
                        onClick={() => {
                          setSelectedApplication(app);
                          setCardholderName(app.full_name);
                          setIssueModal(true);
                        }}
                        className="px-4 py-2 bg-blue-500/20 text-blue-300 rounded-lg hover:bg-blue-500/30 transition-colors flex items-center gap-2"
                      >
                        <Send className="w-4 h-4" />
                        Issue Card
                      </button>
                    )}
                  </div>
                </div>
              ))}

              {filteredApplications.length === 0 && (
                <div className="text-center py-12 text-slate-400">
                  No applications found
                </div>
              )}
            </div>
          </>
        )}

        {activeTab === 'cards' && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {cards.map((card) => (
              <div key={card.card_id} className="relative">
                <div className={`bg-gradient-to-br rounded-2xl p-6 shadow-xl ${
                  card.card_type === 'platinum' ? 'from-slate-700 via-slate-600 to-slate-700' :
                  card.card_type === 'gold' ? 'from-amber-600 via-amber-500 to-orange-600' :
                  'from-slate-800 via-slate-700 to-slate-800'
                }`}>
                  <div className="flex justify-between items-start mb-8">
                    <div className="text-white/80 font-medium">SHARK CARD</div>
                    {getCardTypeBadge(card.card_type)}
                  </div>

                  <div className="space-y-4">
                    <div className="text-2xl font-mono text-white tracking-wider">
                      **** **** **** {card.card_number}
                    </div>

                    <div className="flex justify-between items-end">
                      <div>
                        <div className="text-white/60 text-xs mb-1">CARDHOLDER</div>
                        <div className="text-white font-medium">{card.card_holder_name}</div>
                      </div>
                      <div>
                        <div className="text-white/60 text-xs mb-1">EXPIRES</div>
                        <div className="text-white font-medium">{new Date(card.expiry_date).toLocaleDateString('en-US', { month: '2-digit', year: '2-digit' })}</div>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="mt-3 bg-slate-800/50 border border-slate-700 rounded-xl p-4 space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-400">Credit Limit</span>
                    <span className="text-white font-semibold">${card.credit_limit.toLocaleString()} USDT</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-400">Available</span>
                    <span className="text-green-400 font-semibold">${card.available_credit.toLocaleString()} USDT</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-400">Used</span>
                    <span className="text-red-400 font-semibold">${card.used_credit.toLocaleString()} USDT</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-400">Cashback Rate</span>
                    <span className="text-amber-400 font-semibold">{card.cashback_rate}%</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-400">User</span>
                    <span className="text-white">{card.user_email}</span>
                  </div>

                  <div className="flex gap-2 mt-3">
                    <button
                      onClick={() => {
                        setSelectedCard(card);
                        setNewBalance(card.available_credit);
                        setEditBalanceModal(true);
                      }}
                      className="flex-1 px-4 py-2 bg-gradient-to-r from-amber-500 to-orange-600 text-white rounded-lg hover:from-amber-600 hover:to-orange-700 transition-all flex items-center justify-center gap-2"
                    >
                      <Edit3 className="w-4 h-4" />
                      Edit Balance
                    </button>
                    <button
                      onClick={() => {
                        setSelectedCard(card);
                        setAddTransactionModal(true);
                      }}
                      className="flex-1 px-4 py-2 bg-blue-500/20 text-blue-300 border border-blue-500/30 rounded-lg hover:bg-blue-500/30 transition-all flex items-center justify-center gap-2"
                    >
                      <Plus className="w-4 h-4" />
                      Add Transaction
                    </button>
                  </div>
                </div>
              </div>
            ))}

            {cards.length === 0 && (
              <div className="col-span-full text-center py-12 text-slate-400">
                No cards issued yet
              </div>
            )}
          </div>
        )}
      </div>

      {approvalModal && selectedApplication && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-slate-900 rounded-xl max-w-md w-full p-6 border border-green-500/20">
            <h3 className="text-xl font-bold text-white mb-4">Approve Application</h3>
            <p className="text-slate-400 mb-4">
              Approve card application for <span className="text-white font-semibold">{selectedApplication.full_name}</span>
            </p>

            <div className="bg-amber-500/10 border border-amber-500/20 rounded-lg p-4 mb-4">
              <div className="flex items-center gap-2 text-amber-400 text-sm mb-2">
                <Lock className="w-4 h-4" />
                <span className="font-semibold">Locked Amount: ${(selectedApplication.locked_amount || selectedApplication.requested_limit).toLocaleString()} USDT</span>
              </div>
              <p className="text-xs text-amber-300/80">
                Upon approval, funds will be transferred from the user's locked balance to their card wallet.
              </p>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm text-slate-400 mb-2">Approved Credit Limit (USDT)</label>
                <input
                  type="number"
                  value={approvedLimit}
                  onChange={(e) => setApprovedLimit(Number(e.target.value))}
                  max={selectedApplication.locked_amount || selectedApplication.requested_limit}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                />
                {approvedLimit > (selectedApplication.locked_amount || selectedApplication.requested_limit) && (
                  <p className="text-xs text-red-400 mt-1">Cannot exceed locked amount</p>
                )}
                {approvedLimit < (selectedApplication.locked_amount || selectedApplication.requested_limit) && approvedLimit > 0 && (
                  <p className="text-xs text-amber-400 mt-1">
                    ${((selectedApplication.locked_amount || selectedApplication.requested_limit) - approvedLimit).toLocaleString()} USDT will be unlocked and returned
                  </p>
                )}
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">Card Type</label>
                <select
                  value={cardType}
                  onChange={(e) => setCardType(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                >
                  <option value="standard">Standard</option>
                  <option value="gold">Gold</option>
                  <option value="platinum">Platinum</option>
                </select>
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">Cashback Rate (%)</label>
                <input
                  type="number"
                  step="0.1"
                  value={cashbackRate}
                  onChange={(e) => setCashbackRate(Number(e.target.value))}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setApprovalModal(false)}
                className="flex-1 px-4 py-2 bg-slate-800 text-slate-300 rounded-lg hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleApprove}
                disabled={approvedLimit > (selectedApplication.locked_amount || selectedApplication.requested_limit) || approvedLimit <= 0}
                className="flex-1 px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Approve & Transfer Funds
              </button>
            </div>
          </div>
        </div>
      )}

      {declineModal && selectedApplication && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-slate-900 rounded-xl max-w-md w-full p-6 border border-red-500/20">
            <h3 className="text-xl font-bold text-white mb-4">Decline Application</h3>
            <p className="text-slate-400 mb-4">
              Decline card application for <span className="text-white font-semibold">{selectedApplication.full_name}</span>
            </p>

            <div className="bg-amber-500/10 border border-amber-500/20 rounded-lg p-4 mb-4">
              <div className="flex items-center gap-2 text-amber-400 text-sm">
                <Unlock className="w-4 h-4" />
                <span><span className="font-semibold">${(selectedApplication.locked_amount || selectedApplication.requested_limit).toLocaleString()} USDT</span> will be unlocked and returned to the user</span>
              </div>
            </div>

            <div>
              <label className="block text-sm text-slate-400 mb-2">Reason for Decline</label>
              <textarea
                value={declineReason}
                onChange={(e) => setDeclineReason(e.target.value)}
                rows={4}
                className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white resize-none"
                placeholder="Enter reason..."
              />
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => {
                  setDeclineModal(false);
                  setDeclineReason('');
                }}
                className="flex-1 px-4 py-2 bg-slate-800 text-slate-300 rounded-lg hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleDecline}
                disabled={!declineReason}
                className="flex-1 px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 disabled:opacity-50"
              >
                Decline & Unlock Funds
              </button>
            </div>
          </div>
        </div>
      )}

      {issueModal && selectedApplication && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] border border-gray-800 rounded-xl max-w-2xl w-full p-6 max-h-[90vh] overflow-y-auto">
            <h3 className="text-xl font-bold text-white mb-2">Issue Shark Card</h3>
            <p className="text-slate-400 text-sm mb-6">
              Issue a physical card for <span className="text-white font-semibold">{selectedApplication.full_name}</span>
            </p>

            <div className="space-y-4">
              <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4 mb-4">
                <div className="flex items-start gap-3">
                  <Wallet className="w-5 h-5 text-green-400 flex-shrink-0 mt-0.5" />
                  <div className="text-sm text-green-400/90">
                    <p className="font-semibold mb-1">Funds Already Transferred</p>
                    <p className="text-xs">${(selectedApplication.locked_amount || selectedApplication.requested_limit).toLocaleString()} USDT is already in the user's card wallet from the approval step. Enter the physical card details to complete issuance.</p>
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">Card Number (16 digits)</label>
                <input
                  type="text"
                  placeholder="1234567890123456"
                  maxLength={16}
                  value={cardNumber}
                  onChange={(e) => setCardNumber(e.target.value.replace(/\D/g, ''))}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white font-mono"
                />
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">Cardholder Name</label>
                <input
                  type="text"
                  placeholder="JOHN DOE"
                  value={cardholderName}
                  onChange={(e) => setCardholderName(e.target.value.toUpperCase())}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white uppercase"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">Expiry Month</label>
                  <select
                    value={expiryMonth}
                    onChange={(e) => setExpiryMonth(e.target.value)}
                    className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                  >
                    <option value="">Select month</option>
                    {Array.from({ length: 12 }, (_, i) => {
                      const month = (i + 1).toString().padStart(2, '0');
                      return <option key={month} value={month}>{month}</option>;
                    })}
                  </select>
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-2">Expiry Year</label>
                  <select
                    value={expiryYear}
                    onChange={(e) => setExpiryYear(e.target.value)}
                    className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                  >
                    <option value="">Select year</option>
                    {Array.from({ length: 10 }, (_, i) => {
                      const year = (new Date().getFullYear() + i).toString().slice(-2);
                      return <option key={year} value={year}>{year}</option>;
                    })}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">CVV (3 digits)</label>
                <input
                  type="text"
                  placeholder="123"
                  maxLength={3}
                  value={cvv}
                  onChange={(e) => setCvv(e.target.value.replace(/\D/g, ''))}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white font-mono"
                />
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">Card Type</label>
                <select
                  value={cardType}
                  onChange={(e) => setCardType(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                >
                  <option value="standard">Standard (1% Cashback)</option>
                  <option value="gold">Gold (2% Cashback)</option>
                  <option value="platinum">Platinum (3% Cashback)</option>
                </select>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => {
                  setIssueModal(false);
                  setCardNumber('');
                  setCardholderName('');
                  setExpiryMonth('');
                  setExpiryYear('');
                  setCvv('');
                }}
                className="flex-1 px-4 py-2 bg-slate-800 text-slate-300 rounded-lg hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleIssueCard}
                className="flex-1 px-4 py-2 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] text-black font-bold rounded-lg hover:from-[#f8d12f] hover:to-[#f0b90b] transition-all"
              >
                Issue Card
              </button>
            </div>
          </div>
        </div>
      )}

      {editBalanceModal && selectedCard && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-slate-900 rounded-xl max-w-md w-full p-6 border border-amber-500/20">
            <h3 className="text-xl font-bold text-white mb-2">Edit Card Balance</h3>
            <p className="text-slate-400 mb-4">
              Adjust the balance for card ending in <span className="text-white font-semibold">{selectedCard.card_number}</span>
            </p>

            <div className="bg-slate-800/50 border border-slate-700 rounded-lg p-4 mb-4">
              <div className="flex justify-between text-sm mb-2">
                <span className="text-slate-400">Current Balance</span>
                <span className="text-white font-semibold">${selectedCard.available_credit.toLocaleString()} USDT</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-slate-400">Cardholder</span>
                <span className="text-white">{selectedCard.card_holder_name}</span>
              </div>
            </div>

            <div>
              <label className="block text-sm text-slate-400 mb-2">New Balance (USDT)</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={newBalance}
                onChange={(e) => setNewBalance(Number(e.target.value))}
                className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white text-lg font-semibold"
              />
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => {
                  setEditBalanceModal(false);
                  setSelectedCard(null);
                }}
                className="flex-1 px-4 py-2 bg-slate-800 text-slate-300 rounded-lg hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleAdjustBalance}
                className="flex-1 px-4 py-2 bg-gradient-to-r from-amber-500 to-orange-600 text-white rounded-lg hover:from-amber-600 hover:to-orange-700"
              >
                Update Balance
              </button>
            </div>
          </div>
        </div>
      )}

      {addTransactionModal && selectedCard && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-slate-900 rounded-xl max-w-md w-full p-6 border border-blue-500/20">
            <div className="flex items-center gap-3 mb-4">
              <div className="bg-blue-500/20 p-2 rounded-lg">
                <Receipt className="w-5 h-5 text-blue-400" />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white">Add Card Transaction</h3>
                <p className="text-slate-400 text-sm">
                  For card ending in {selectedCard.card_number}
                </p>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm text-slate-400 mb-2">Description *</label>
                <input
                  type="text"
                  value={txDescription}
                  onChange={(e) => setTxDescription(e.target.value)}
                  placeholder="e.g., Netflix Subscription"
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                />
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">Merchant (Optional)</label>
                <input
                  type="text"
                  value={txMerchant}
                  onChange={(e) => setTxMerchant(e.target.value)}
                  placeholder="e.g., NETFLIX.COM"
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                />
              </div>

              <div>
                <label className="block text-sm text-slate-400 mb-2">Amount (USD) *</label>
                <input
                  type="number"
                  step="0.01"
                  value={txAmount}
                  onChange={(e) => setTxAmount(e.target.value)}
                  placeholder="0.00"
                  className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                />
                <p className="text-xs text-slate-500 mt-1">Use negative for debits (e.g., -25.00)</p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">Type</label>
                  <select
                    value={txType}
                    onChange={(e) => setTxType(e.target.value as any)}
                    className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                  >
                    <option value="purchase">Purchase</option>
                    <option value="fee">Fee</option>
                    <option value="refund">Refund</option>
                    <option value="cashback">Cashback</option>
                    <option value="adjustment">Adjustment</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-2">Status</label>
                  <select
                    value={txStatus}
                    onChange={(e) => setTxStatus(e.target.value as any)}
                    className="w-full bg-slate-800 border border-slate-700 rounded-lg px-4 py-2 text-white"
                  >
                    <option value="approved">Approved</option>
                    <option value="declined">Declined</option>
                    <option value="pending">Pending</option>
                  </select>
                </div>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => {
                  setAddTransactionModal(false);
                  setTxDescription('');
                  setTxAmount('');
                  setTxMerchant('');
                  setTxType('purchase');
                  setTxStatus('approved');
                }}
                className="flex-1 px-4 py-2 bg-slate-800 text-slate-300 rounded-lg hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleAddTransaction}
                disabled={!txDescription || !txAmount}
                className="flex-1 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Add Transaction
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

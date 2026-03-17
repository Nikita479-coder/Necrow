import { useState, useEffect } from 'react';
import { Search, Users, ChevronLeft, ChevronRight, Filter, X, Phone, TrendingUp, Copy, Circle } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface CopyTradingInfo {
  trader_name: string;
  trader_id: string;
  is_mock: boolean;
  current_balance: number;
  cumulative_pnl: number;
}

interface TreeUser {
  user_id: string;
  tree_depth: number;
  username: string | null;
  full_name: string | null;
  email: string;
  kyc_status: string;
  kyc_level: number;
  country: string | null;
  phone: string | null;
  created_at: string;
  total_deposits: number;
  total_withdrawals: number;
  main_balance: number;
  is_online: boolean;
  last_activity: string | null;
  open_positions: number;
  copy_trading: CopyTradingInfo[];
}

export default function PromoterUsers() {
  const [users, setUsers] = useState<TreeUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [showFilters, setShowFilters] = useState(false);
  const [filterLevel, setFilterLevel] = useState<string>('all');
  const [filterKyc, setFilterKyc] = useState<string>('all');
  const [filterOnline, setFilterOnline] = useState<string>('all');
  const [filterTrading, setFilterTrading] = useState<string>('all');
  const pageSize = 50;

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search), 400);
    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    setPage(0);
  }, [debouncedSearch]);

  useEffect(() => {
    loadUsers();
  }, [page, debouncedSearch]);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('promoter_get_users_list', {
        p_limit: pageSize,
        p_offset: page * pageSize,
        p_search: debouncedSearch || null,
      });
      if (error) throw error;
      if (data?.success) {
        setUsers(data.users || []);
        setTotal(data.total || 0);
      }
    } catch (err) {
      console.error('Failed to load users:', err);
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = users.filter(u => {
    if (filterLevel !== 'all' && u.tree_depth !== parseInt(filterLevel)) return false;
    if (filterKyc !== 'all' && u.kyc_status !== filterKyc) return false;
    if (filterOnline === 'online' && !u.is_online) return false;
    if (filterOnline === 'offline' && u.is_online) return false;
    if (filterTrading === 'active' && u.open_positions === 0 && u.copy_trading.length === 0) return false;
    if (filterTrading === 'live' && u.open_positions === 0) return false;
    if (filterTrading === 'copy' && u.copy_trading.length === 0) return false;
    if (filterTrading === 'none' && (u.open_positions > 0 || u.copy_trading.length > 0)) return false;
    return true;
  });

  const getTimeAgo = (dateStr: string | null) => {
    if (!dateStr) return 'Never';
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'Just now';
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  };

  const getKycBadge = (status: string) => {
    switch (status) {
      case 'verified': return 'bg-emerald-500/20 text-emerald-400';
      case 'pending': return 'bg-yellow-500/20 text-yellow-400';
      case 'rejected': return 'bg-red-500/20 text-red-400';
      default: return 'bg-gray-500/20 text-gray-400';
    }
  };

  const totalPages = Math.ceil(total / pageSize);
  const uniqueLevels = [...new Set(users.map(u => u.tree_depth))].sort((a, b) => a - b);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-white">Users</h2>
          <p className="text-sm text-gray-400">{total} users in your referral tree</p>
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-colors ${
            showFilters ? 'bg-[#f0b90b] text-black' : 'bg-[#1a1d24] text-gray-400 hover:text-white border border-gray-800'
          }`}
        >
          {showFilters ? <X className="w-4 h-4" /> : <Filter className="w-4 h-4" />}
          Filters
        </button>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
        <input
          type="text"
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search by name, username, or email..."
          className="w-full pl-10 pr-4 py-3 bg-[#1a1d24] border border-gray-800 rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b]/50"
        />
      </div>

      {showFilters && (
        <div className="bg-[#1a1d24] border border-gray-800 rounded-xl p-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="text-xs text-gray-400 mb-1 block">Tree Level</label>
              <select
                value={filterLevel}
                onChange={e => setFilterLevel(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
              >
                <option value="all">All Levels</option>
                {uniqueLevels.map(l => (
                  <option key={l} value={l}>Level {l}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-400 mb-1 block">KYC Status</label>
              <select
                value={filterKyc}
                onChange={e => setFilterKyc(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
              >
                <option value="all">All Statuses</option>
                <option value="none">None</option>
                <option value="pending">Pending</option>
                <option value="verified">Verified</option>
                <option value="rejected">Rejected</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-400 mb-1 block">Online Status</label>
              <select
                value={filterOnline}
                onChange={e => setFilterOnline(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
              >
                <option value="all">All</option>
                <option value="online">Online</option>
                <option value="offline">Offline</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-400 mb-1 block">Trading Activity</label>
              <select
                value={filterTrading}
                onChange={e => setFilterTrading(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
              >
                <option value="all">All</option>
                <option value="active">Any Trading</option>
                <option value="live">Live Trading</option>
                <option value="copy">Copy Trading</option>
                <option value="none">No Trading</option>
              </select>
            </div>
          </div>
        </div>
      )}

      {loading ? (
        <div className="text-center py-12">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
        </div>
      ) : filteredUsers.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <Users className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No users found</p>
        </div>
      ) : (
        <div className="bg-[#1a1d24] rounded-xl border border-gray-800 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-800">
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">User</th>
                  <th className="text-center py-3 px-3 text-xs font-medium text-gray-400 uppercase">Status</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Phone</th>
                  <th className="text-left py-3 px-3 text-xs font-medium text-gray-400 uppercase">Level</th>
                  <th className="text-left py-3 px-3 text-xs font-medium text-gray-400 uppercase">KYC</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Trading</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Copy Trading</th>
                  <th className="text-right py-3 px-4 text-xs font-medium text-gray-400 uppercase">Deposits</th>
                  <th className="text-right py-3 px-4 text-xs font-medium text-gray-400 uppercase">Withdrawals</th>
                  <th className="text-right py-3 px-4 text-xs font-medium text-gray-400 uppercase">Balance</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Joined</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map(u => {
                  const realCopies = (u.copy_trading || []).filter(ct => !ct.is_mock);
                  return (
                    <tr key={u.user_id} className="border-b border-gray-800/50 hover:bg-[#0b0e11] transition-colors">
                      <td className="py-3 px-4">
                        <div className="text-sm text-white font-medium">{u.full_name || u.username || 'N/A'}</div>
                        <div className="text-xs text-gray-500">{u.email}</div>
                      </td>
                      <td className="py-3 px-3 text-center">
                        <div className="flex flex-col items-center gap-1">
                          <Circle
                            className={`w-3 h-3 ${u.is_online ? 'text-emerald-400 fill-emerald-400' : 'text-gray-600 fill-gray-600'}`}
                          />
                          <span className={`text-[10px] ${u.is_online ? 'text-emerald-400' : 'text-gray-500'}`}>
                            {u.is_online ? 'Online' : getTimeAgo(u.last_activity)}
                          </span>
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        {u.phone ? (
                          <div className="flex items-center gap-1.5">
                            <Phone className="w-3 h-3 text-gray-500 shrink-0" />
                            <span className="text-xs text-gray-300 whitespace-nowrap">{u.phone}</span>
                          </div>
                        ) : (
                          <span className="text-xs text-gray-600">--</span>
                        )}
                      </td>
                      <td className="py-3 px-3">
                        <span className="text-xs bg-blue-500/15 text-blue-400 px-2 py-1 rounded-md font-medium">
                          L{u.tree_depth}
                        </span>
                      </td>
                      <td className="py-3 px-3">
                        <span className={`text-xs px-2 py-1 rounded-md font-medium ${getKycBadge(u.kyc_status)}`}>
                          {u.kyc_status || 'none'}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        {u.open_positions > 0 ? (
                          <div className="flex items-center gap-1.5">
                            <TrendingUp className="w-3.5 h-3.5 text-emerald-400" />
                            <span className="text-xs text-emerald-400 font-medium">
                              {u.open_positions} open
                            </span>
                          </div>
                        ) : (
                          <span className="text-xs text-gray-600">None</span>
                        )}
                      </td>
                      <td className="py-3 px-4">
                        {realCopies.length > 0 ? (
                          <div className="space-y-1">
                            {realCopies.map((ct, i) => (
                              <div key={i} className="flex items-center gap-1.5">
                                <Copy className="w-3 h-3 text-[#f0b90b] shrink-0" />
                                <span className="text-xs text-[#f0b90b] font-medium truncate max-w-[120px]">
                                  {ct.trader_name}
                                </span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <span className="text-xs text-gray-600">None</span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-right">
                        <span className="text-sm text-emerald-400">${Number(u.total_deposits).toFixed(2)}</span>
                      </td>
                      <td className="py-3 px-4 text-right">
                        <span className="text-sm text-red-400">${Number(u.total_withdrawals).toFixed(2)}</span>
                      </td>
                      <td className="py-3 px-4 text-right">
                        <span className="text-sm text-white">${Number(u.main_balance).toFixed(2)}</span>
                      </td>
                      <td className="py-3 px-4">
                        <span className="text-xs text-gray-400">{new Date(u.created_at).toLocaleDateString()}</span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {totalPages > 1 && (
            <div className="flex items-center justify-between px-4 py-3 border-t border-gray-800">
              <span className="text-sm text-gray-400">
                Page {page + 1} of {totalPages}
              </span>
              <div className="flex gap-2">
                <button
                  onClick={() => setPage(p => Math.max(0, p - 1))}
                  disabled={page === 0}
                  className="p-2 rounded-lg bg-[#0b0e11] text-gray-400 hover:text-white disabled:opacity-30 transition-colors"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}
                  disabled={page >= totalPages - 1}
                  className="p-2 rounded-lg bg-[#0b0e11] text-gray-400 hover:text-white disabled:opacity-30 transition-colors"
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

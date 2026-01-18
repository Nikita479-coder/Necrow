import { useState, useEffect, useCallback } from 'react';
import { Search, Filter, Download, RefreshCw, Users, DollarSign, TrendingUp, Layers, ChevronDown, X, Eye, EyeOff } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { DepositorTreeNode } from './DepositorTreeNode';

interface TreeNodeData {
  user_id: string;
  email: string;
  full_name: string | null;
  username: string | null;
  parent_id: string | null;
  level: number;
  total_deposits: number;
  deposit_count: number;
  first_deposit_date: string | null;
  last_deposit_date: string | null;
  has_deposits: boolean;
  referral_code: string | null;
  created_at: string;
  children?: TreeNodeData[];
}

interface TreeStats {
  total_users: number;
  total_depositors: number;
  total_deposit_volume: number;
  avg_deposit_per_user: number;
  max_depth: number;
  level_1_depositors: number;
  level_1_volume: number;
  level_2_depositors: number;
  level_2_volume: number;
  level_3_depositors: number;
  level_3_volume: number;
  level_4_depositors: number;
  level_4_volume: number;
  level_5_plus_depositors: number;
  level_5_plus_volume: number;
}

interface SearchResult {
  user_id: string;
  email: string;
  full_name: string | null;
  username: string | null;
  referral_code: string | null;
  total_referrals: number;
  has_depositors: boolean;
}

export function DepositorReferralTree() {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [selectedUserName, setSelectedUserName] = useState<string>('');
  const [treeData, setTreeData] = useState<TreeNodeData | null>(null);
  const [treeStats, setTreeStats] = useState<TreeStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [searchLoading, setSearchLoading] = useState(false);
  const [includeNonDepositors, setIncludeNonDepositors] = useState(false);
  const [minDepositAmount, setMinDepositAmount] = useState(0);
  const [showFilters, setShowFilters] = useState(false);
  const [navigationHistory, setNavigationHistory] = useState<{ id: string; name: string }[]>([]);

  const searchUsers = useCallback(async (term: string) => {
    if (term.length < 2) {
      setSearchResults([]);
      return;
    }

    setSearchLoading(true);
    try {
      const { data, error } = await supabase.rpc('search_users_for_tree', {
        p_search_term: term,
        p_limit: 20
      });

      if (error) throw error;
      setSearchResults(data || []);
      setShowSearchResults(true);
    } catch (err) {
      console.error('Search error:', err);
    } finally {
      setSearchLoading(false);
    }
  }, []);

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      searchUsers(searchTerm);
    }, 300);

    return () => clearTimeout(timeoutId);
  }, [searchTerm, searchUsers]);

  const buildTree = (flatData: TreeNodeData[]): TreeNodeData | null => {
    if (flatData.length === 0) return null;

    const nodeMap = new Map<string, TreeNodeData>();
    flatData.forEach(node => {
      nodeMap.set(node.user_id, { ...node, children: [] });
    });

    let root: TreeNodeData | null = null;

    flatData.forEach(node => {
      const treeNode = nodeMap.get(node.user_id)!;
      if (node.parent_id === null || node.level === 0) {
        root = treeNode;
      } else {
        const parent = nodeMap.get(node.parent_id);
        if (parent) {
          parent.children = parent.children || [];
          parent.children.push(treeNode);
        }
      }
    });

    return root;
  };

  const loadTree = async (userId: string, userName: string) => {
    setLoading(true);
    setSelectedUserId(userId);
    setSelectedUserName(userName);
    setShowSearchResults(false);
    setSearchTerm('');

    try {
      const [treeResult, statsResult] = await Promise.all([
        supabase.rpc('get_depositor_referral_tree', {
          p_root_user_id: userId,
          p_include_non_depositors: includeNonDepositors,
          p_min_deposit_amount: minDepositAmount
        }),
        supabase.rpc('get_depositor_tree_stats', {
          p_root_user_id: userId
        })
      ]);

      if (treeResult.error) throw treeResult.error;
      if (statsResult.error) throw statsResult.error;

      const tree = buildTree(treeResult.data || []);
      setTreeData(tree);
      setTreeStats(statsResult.data?.[0] || null);
    } catch (err) {
      console.error('Error loading tree:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectUser = (userId: string) => {
    if (selectedUserId) {
      setNavigationHistory(prev => [...prev, { id: selectedUserId, name: selectedUserName }]);
    }

    const findUserInTree = (node: TreeNodeData | null): TreeNodeData | null => {
      if (!node) return null;
      if (node.user_id === userId) return node;
      for (const child of node.children || []) {
        const found = findUserInTree(child);
        if (found) return found;
      }
      return null;
    };

    const user = findUserInTree(treeData);
    if (user) {
      loadTree(userId, user.full_name || user.username || user.email.split('@')[0]);
    }
  };

  const handleBackNavigation = (index: number) => {
    const target = navigationHistory[index];
    setNavigationHistory(prev => prev.slice(0, index));
    loadTree(target.id, target.name);
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const exportToCSV = () => {
    if (!treeData) return;

    const flattenTree = (node: TreeNodeData, rows: any[] = []): any[] => {
      rows.push({
        level: node.level,
        name: node.full_name || node.username || '',
        email: node.email,
        referral_code: node.referral_code || '',
        total_deposits: node.total_deposits,
        deposit_count: node.deposit_count,
        first_deposit: node.first_deposit_date || '',
        last_deposit: node.last_deposit_date || '',
        has_deposits: node.has_deposits ? 'Yes' : 'No'
      });
      node.children?.forEach(child => flattenTree(child, rows));
      return rows;
    };

    const rows = flattenTree(treeData);
    const headers = Object.keys(rows[0]).join(',');
    const csv = [headers, ...rows.map(r => Object.values(r).join(','))].join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `depositor_tree_${selectedUserName}_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col lg:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            onFocus={() => searchTerm.length >= 2 && setShowSearchResults(true)}
            placeholder="Search by name, email, or referral code..."
            className="w-full pl-10 pr-4 py-3 bg-[#111] border border-[#222] rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
          />
          {searchLoading && (
            <RefreshCw className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500 animate-spin" />
          )}

          {showSearchResults && searchResults.length > 0 && (
            <div className="absolute top-full left-0 right-0 mt-2 bg-[#111] border border-[#222] rounded-lg shadow-xl z-50 max-h-80 overflow-y-auto">
              {searchResults.map((user) => (
                <button
                  key={user.user_id}
                  onClick={() => loadTree(user.user_id, user.full_name || user.username || user.email.split('@')[0])}
                  className="w-full px-4 py-3 text-left hover:bg-[#1a1a1a] transition-colors border-b border-[#222] last:border-b-0"
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-medium text-white">
                        {user.full_name || user.username || user.email.split('@')[0]}
                      </div>
                      <div className="text-sm text-gray-500">{user.email}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm text-gray-400">{user.total_referrals} referrals</div>
                      {user.has_depositors && (
                        <span className="text-xs text-emerald-400">Has depositors</span>
                      )}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="flex gap-2">
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`flex items-center gap-2 px-4 py-3 rounded-lg transition-colors ${
              showFilters ? 'bg-blue-500 text-white' : 'bg-[#111] border border-[#222] text-gray-400 hover:text-white'
            }`}
          >
            <Filter className="w-5 h-5" />
            <span>Filters</span>
            <ChevronDown className={`w-4 h-4 transition-transform ${showFilters ? 'rotate-180' : ''}`} />
          </button>

          {treeData && (
            <>
              <button
                onClick={() => loadTree(selectedUserId!, selectedUserName)}
                className="flex items-center gap-2 px-4 py-3 bg-[#111] border border-[#222] rounded-lg text-gray-400 hover:text-white transition-colors"
              >
                <RefreshCw className="w-5 h-5" />
              </button>
              <button
                onClick={exportToCSV}
                className="flex items-center gap-2 px-4 py-3 bg-[#111] border border-[#222] rounded-lg text-gray-400 hover:text-white transition-colors"
              >
                <Download className="w-5 h-5" />
              </button>
            </>
          )}
        </div>
      </div>

      {showFilters && (
        <div className="flex flex-wrap gap-4 p-4 bg-[#111] border border-[#222] rounded-lg">
          <div className="flex items-center gap-3">
            <button
              onClick={() => setIncludeNonDepositors(!includeNonDepositors)}
              className={`flex items-center gap-2 px-3 py-2 rounded-lg transition-colors ${
                includeNonDepositors ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30' : 'bg-[#1a1a1a] text-gray-400 border border-[#2a2a2a]'
              }`}
            >
              {includeNonDepositors ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
              <span>Show non-depositors</span>
            </button>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-sm text-gray-400">Min deposit:</span>
            <select
              value={minDepositAmount}
              onChange={(e) => setMinDepositAmount(Number(e.target.value))}
              className="px-3 py-2 bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg text-white focus:outline-none focus:border-blue-500"
            >
              <option value={0}>All amounts</option>
              <option value={100}>$100+</option>
              <option value={500}>$500+</option>
              <option value={1000}>$1,000+</option>
              <option value={5000}>$5,000+</option>
              <option value={10000}>$10,000+</option>
            </select>
          </div>

          {selectedUserId && (
            <button
              onClick={() => loadTree(selectedUserId, selectedUserName)}
              className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
            >
              Apply Filters
            </button>
          )}
        </div>
      )}

      {navigationHistory.length > 0 && (
        <div className="flex items-center gap-2 text-sm">
          {navigationHistory.map((item, index) => (
            <div key={item.id} className="flex items-center gap-2">
              <button
                onClick={() => handleBackNavigation(index)}
                className="text-blue-400 hover:text-blue-300 transition-colors"
              >
                {item.name}
              </button>
              <span className="text-gray-600">/</span>
            </div>
          ))}
          <span className="text-white font-medium">{selectedUserName}</span>
          <button
            onClick={() => {
              setNavigationHistory([]);
              setTreeData(null);
              setTreeStats(null);
              setSelectedUserId(null);
              setSelectedUserName('');
            }}
            className="ml-2 p-1 text-gray-500 hover:text-white transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {treeStats && (
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
            <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
              <Users className="w-4 h-4" />
              <span>Total Referrals</span>
            </div>
            <div className="text-2xl font-bold text-white">{treeStats.total_users}</div>
          </div>

          <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
            <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
              <DollarSign className="w-4 h-4" />
              <span>Depositors</span>
            </div>
            <div className="text-2xl font-bold text-emerald-400">{treeStats.total_depositors}</div>
          </div>

          <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
            <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
              <TrendingUp className="w-4 h-4" />
              <span>Total Volume</span>
            </div>
            <div className="text-2xl font-bold text-white">{formatCurrency(treeStats.total_deposit_volume)}</div>
          </div>

          <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
            <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
              <DollarSign className="w-4 h-4" />
              <span>Avg. Deposit</span>
            </div>
            <div className="text-2xl font-bold text-white">{formatCurrency(treeStats.avg_deposit_per_user)}</div>
          </div>

          <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
            <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
              <Layers className="w-4 h-4" />
              <span>Max Depth</span>
            </div>
            <div className="text-2xl font-bold text-white">{treeStats.max_depth} levels</div>
          </div>

          <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
            <div className="flex items-center gap-2 text-gray-400 text-sm mb-1">
              <TrendingUp className="w-4 h-4" />
              <span>Conversion</span>
            </div>
            <div className="text-2xl font-bold text-white">
              {treeStats.total_users > 0 ? Math.round((treeStats.total_depositors / treeStats.total_users) * 100) : 0}%
            </div>
          </div>
        </div>
      )}

      {treeStats && (
        <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
          <h3 className="text-sm font-medium text-gray-400 mb-4">Deposits by Level</h3>
          <div className="grid grid-cols-5 gap-4">
            {[
              { level: 1, depositors: treeStats.level_1_depositors, volume: treeStats.level_1_volume },
              { level: 2, depositors: treeStats.level_2_depositors, volume: treeStats.level_2_volume },
              { level: 3, depositors: treeStats.level_3_depositors, volume: treeStats.level_3_volume },
              { level: 4, depositors: treeStats.level_4_depositors, volume: treeStats.level_4_volume },
              { level: '5+', depositors: treeStats.level_5_plus_depositors, volume: treeStats.level_5_plus_volume },
            ].map((item) => (
              <div key={item.level} className="text-center">
                <div className="text-xs text-gray-500 mb-1">Level {item.level}</div>
                <div className="text-lg font-bold text-white">{item.depositors}</div>
                <div className="text-xs text-emerald-400">{formatCurrency(item.volume)}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <RefreshCw className="w-8 h-8 text-gray-500 animate-spin" />
        </div>
      ) : treeData ? (
        <div className="p-4 bg-[#111] border border-[#222] rounded-lg">
          <DepositorTreeNode
            node={treeData}
            onSelectUser={handleSelectUser}
            isRoot={true}
          />
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-20 text-gray-500">
          <Users className="w-16 h-16 mb-4 opacity-50" />
          <p className="text-lg">Search for a user to view their depositor referral tree</p>
          <p className="text-sm mt-2">Enter a name, email, or referral code above</p>
        </div>
      )}
    </div>
  );
}

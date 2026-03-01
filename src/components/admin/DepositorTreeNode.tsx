import { useState } from 'react';
import { ChevronRight, ChevronDown, User, DollarSign, Users, Calendar } from 'lucide-react';

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

interface DepositorTreeNodeProps {
  node: TreeNodeData;
  onSelectUser: (userId: string) => void;
  isRoot?: boolean;
}

export function DepositorTreeNode({ node, onSelectUser, isRoot = false }: DepositorTreeNodeProps) {
  const [isExpanded, setIsExpanded] = useState(isRoot || node.level < 2);
  const hasChildren = node.children && node.children.length > 0;

  const getDepositTierColor = (amount: number) => {
    if (amount >= 10000) return 'bg-emerald-500';
    if (amount >= 5000) return 'bg-emerald-400';
    if (amount >= 1000) return 'bg-amber-500';
    if (amount >= 100) return 'bg-amber-400';
    if (amount > 0) return 'bg-blue-400';
    return 'bg-gray-400';
  };

  const getDepositBorderColor = (amount: number) => {
    if (amount >= 10000) return 'border-emerald-500';
    if (amount >= 5000) return 'border-emerald-400';
    if (amount >= 1000) return 'border-amber-500';
    if (amount >= 100) return 'border-amber-400';
    if (amount > 0) return 'border-blue-400';
    return 'border-gray-600';
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'N/A';
    return new Date(dateStr).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const getInitials = (name: string | null, email: string) => {
    if (name) {
      return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
    }
    return email.slice(0, 2).toUpperCase();
  };

  const childDepositorCount = node.children?.filter(c => c.has_deposits).length || 0;
  const totalChildDeposits = node.children?.reduce((sum, c) => sum + (c.total_deposits || 0), 0) || 0;

  return (
    <div className="select-none">
      <div
        className={`flex items-start gap-3 p-3 rounded-lg transition-all duration-200 hover:bg-[#1a1a1a] ${
          isRoot ? 'bg-[#1a1a1a] border border-[#2a2a2a]' : ''
        }`}
      >
        {hasChildren ? (
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="mt-1 p-1 hover:bg-[#2a2a2a] rounded transition-colors"
          >
            {isExpanded ? (
              <ChevronDown className="w-4 h-4 text-gray-400" />
            ) : (
              <ChevronRight className="w-4 h-4 text-gray-400" />
            )}
          </button>
        ) : (
          <div className="w-6" />
        )}

        <div
          className={`w-10 h-10 rounded-full flex items-center justify-center text-sm font-medium border-2 ${getDepositBorderColor(node.total_deposits)} ${
            node.has_deposits ? getDepositTierColor(node.total_deposits) : 'bg-[#2a2a2a]'
          }`}
        >
          {node.has_deposits ? (
            <span className="text-white">{getInitials(node.full_name, node.email)}</span>
          ) : (
            <User className="w-5 h-5 text-gray-500" />
          )}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <button
              onClick={() => onSelectUser(node.user_id)}
              className="font-medium text-white hover:text-blue-400 transition-colors truncate"
            >
              {node.full_name || node.username || node.email.split('@')[0]}
            </button>
            {isRoot && (
              <span className="px-2 py-0.5 text-xs bg-blue-500/20 text-blue-400 rounded">Root</span>
            )}
            {node.has_deposits && (
              <span className={`px-2 py-0.5 text-xs rounded ${
                node.total_deposits >= 10000 ? 'bg-emerald-500/20 text-emerald-400' :
                node.total_deposits >= 1000 ? 'bg-amber-500/20 text-amber-400' :
                'bg-blue-500/20 text-blue-400'
              }`}>
                {formatCurrency(node.total_deposits)}
              </span>
            )}
          </div>

          <div className="flex items-center gap-4 mt-1 text-xs text-gray-500">
            <span className="truncate">{node.email}</span>
            {node.referral_code && (
              <span className="text-gray-600">#{node.referral_code}</span>
            )}
          </div>

          {node.has_deposits && (
            <div className="flex items-center gap-4 mt-2 text-xs">
              <div className="flex items-center gap-1 text-gray-400">
                <DollarSign className="w-3 h-3" />
                <span>{node.deposit_count} deposit{node.deposit_count !== 1 ? 's' : ''}</span>
              </div>
              <div className="flex items-center gap-1 text-gray-400">
                <Calendar className="w-3 h-3" />
                <span>Last: {formatDate(node.last_deposit_date)}</span>
              </div>
            </div>
          )}

          {hasChildren && (
            <div className="flex items-center gap-3 mt-2 text-xs">
              <div className="flex items-center gap-1 text-gray-400">
                <Users className="w-3 h-3" />
                <span>{node.children?.length} referral{node.children?.length !== 1 ? 's' : ''}</span>
              </div>
              {childDepositorCount > 0 && (
                <span className="text-emerald-400">
                  {childDepositorCount} depositor{childDepositorCount !== 1 ? 's' : ''} ({formatCurrency(totalChildDeposits)})
                </span>
              )}
            </div>
          )}
        </div>
      </div>

      {hasChildren && isExpanded && (
        <div className="ml-6 pl-4 border-l border-[#2a2a2a]">
          {node.children?.map((child) => (
            <DepositorTreeNode
              key={child.user_id}
              node={child}
              onSelectUser={onSelectUser}
            />
          ))}
        </div>
      )}
    </div>
  );
}

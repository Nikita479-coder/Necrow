import { useState, useEffect } from 'react';
import { MessageSquare, Plus, Clock, CheckCircle, XCircle, AlertCircle, Search } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';
import NewTicketModal from './NewTicketModal';
import TicketDetailModal from './TicketDetailModal';

interface Ticket {
  id: string;
  subject: string;
  category: { name: string; color_code: string } | null;
  priority: string;
  status: string;
  created_at: string;
  updated_at: string;
  unread_count?: number;
}

export default function UserSupportTickets() {
  const { user } = useAuth();
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [filteredTickets, setFilteredTickets] = useState<Ticket[]>([]);
  const [loading, setLoading] = useState(true);
  const [showNewTicket, setShowNewTicket] = useState(false);
  const [selectedTicket, setSelectedTicket] = useState<string | null>(null);
  const [filter, setFilter] = useState<'all' | 'open' | 'resolved'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    if (user) {
      loadTickets();
      subscribeToTickets();
    }
  }, [user]);

  useEffect(() => {
    filterTickets();
  }, [tickets, filter, searchQuery]);

  const loadTickets = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('support_tickets')
        .select(`
          *,
          category:support_categories(name, color_code)
        `)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const ticketsWithUnread = await Promise.all(
        (data || []).map(async (ticket) => {
          const { count } = await supabase
            .from('support_messages')
            .select('*', { count: 'exact', head: true })
            .eq('ticket_id', ticket.id)
            .eq('sender_type', 'admin')
            .is('read_at', null);

          return { ...ticket, unread_count: count || 0 };
        })
      );

      setTickets(ticketsWithUnread);
    } catch (error) {
      console.error('Error loading tickets:', error);
    } finally {
      setLoading(false);
    }
  };

  const subscribeToTickets = () => {
    if (!user) return;

    const subscription = supabase
      .channel('user_tickets')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'support_tickets',
          filter: `user_id=eq.${user.id}`,
        },
        () => {
          loadTickets();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  };

  const filterTickets = () => {
    let filtered = tickets;

    if (filter === 'open') {
      filtered = tickets.filter(t => ['open', 'in_progress', 'waiting_admin'].includes(t.status));
    } else if (filter === 'resolved') {
      filtered = tickets.filter(t => ['resolved', 'closed'].includes(t.status));
    }

    if (searchQuery) {
      filtered = filtered.filter(t =>
        t.subject.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    setFilteredTickets(filtered);
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'open':
      case 'in_progress':
      case 'waiting_admin':
        return <Clock className="w-4 h-4 text-yellow-500" />;
      case 'resolved':
      case 'closed':
        return <CheckCircle className="w-4 h-4 text-green-500" />;
      default:
        return <AlertCircle className="w-4 h-4 text-gray-500" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open':
        return 'bg-blue-500/10 text-blue-500';
      case 'in_progress':
        return 'bg-yellow-500/10 text-yellow-500';
      case 'waiting_user':
        return 'bg-orange-500/10 text-orange-500';
      case 'waiting_admin':
        return 'bg-purple-500/10 text-purple-500';
      case 'resolved':
        return 'bg-green-500/10 text-green-500';
      case 'closed':
        return 'bg-gray-500/10 text-gray-500';
      default:
        return 'bg-gray-500/10 text-gray-500';
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent':
        return 'text-red-500';
      case 'high':
        return 'text-orange-500';
      case 'medium':
        return 'text-yellow-500';
      case 'low':
        return 'text-gray-500';
      default:
        return 'text-gray-500';
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-semibold text-white">Support Tickets</h2>
          <p className="text-sm text-gray-400 mt-1">
            Get help from our support team
          </p>
        </div>
        <button
          onClick={() => setShowNewTicket(true)}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
        >
          <Plus className="w-4 h-4" />
          New Ticket
        </button>
      </div>

      <div className="flex items-center gap-4">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            placeholder="Search tickets..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-gray-800/50 border border-gray-700 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
          />
        </div>

        <div className="flex gap-2">
          {(['all', 'open', 'resolved'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === f
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-800/50 text-gray-400 hover:text-white'
              }`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {filteredTickets.length === 0 ? (
        <div className="text-center py-12">
          <MessageSquare className="w-16 h-16 text-gray-600 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-white mb-2">No tickets found</h3>
          <p className="text-gray-400 mb-4">
            {filter === 'all' ? 'Create your first support ticket to get help' : `No ${filter} tickets`}
          </p>
          {filter === 'all' && (
            <button
              onClick={() => setShowNewTicket(true)}
              className="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
            >
              Create Ticket
            </button>
          )}
        </div>
      ) : (
        <div className="space-y-3">
          {filteredTickets.map((ticket) => (
            <div
              key={ticket.id}
              onClick={() => setSelectedTicket(ticket.id)}
              className="bg-gray-800/50 border border-gray-700 rounded-lg p-4 hover:border-blue-500/50 transition-colors cursor-pointer"
            >
              <div className="flex items-start justify-between mb-2">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    {ticket.category && (
                      <span
                        className="px-2 py-0.5 rounded text-xs font-medium"
                        style={{
                          backgroundColor: `${ticket.category.color_code}20`,
                          color: ticket.category.color_code,
                        }}
                      >
                        {ticket.category.name}
                      </span>
                    )}
                    <span className={`px-2 py-0.5 rounded text-xs font-medium ${getStatusColor(ticket.status)}`}>
                      {ticket.status.replace('_', ' ')}
                    </span>
                    {ticket.unread_count && ticket.unread_count > 0 && (
                      <span className="px-2 py-0.5 rounded text-xs font-medium bg-blue-500/20 text-blue-400">
                        {ticket.unread_count} new
                      </span>
                    )}
                  </div>
                  <h3 className="text-white font-medium">{ticket.subject}</h3>
                </div>
                <div className="flex items-center gap-2">
                  {getStatusIcon(ticket.status)}
                  <span className={`text-sm font-medium ${getPriorityColor(ticket.priority)}`}>
                    {ticket.priority}
                  </span>
                </div>
              </div>
              <div className="text-sm text-gray-400">
                Created {new Date(ticket.created_at).toLocaleDateString()} at{' '}
                {new Date(ticket.created_at).toLocaleTimeString()}
              </div>
            </div>
          ))}
        </div>
      )}

      {showNewTicket && (
        <NewTicketModal
          onClose={() => setShowNewTicket(false)}
          onSuccess={() => {
            setShowNewTicket(false);
            loadTickets();
          }}
        />
      )}

      {selectedTicket && (
        <TicketDetailModal
          ticketId={selectedTicket}
          onClose={() => setSelectedTicket(null)}
          onUpdate={loadTickets}
        />
      )}
    </div>
  );
}

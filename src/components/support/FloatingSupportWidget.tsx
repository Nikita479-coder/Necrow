import { useState, useEffect, useRef } from 'react';
import { MessageCircle, X, Send } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';
import { useNotificationSound } from '../../hooks/useNotificationSound';

export default function FloatingSupportWidget() {
  const { user, isAuthenticated } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [success, setSuccess] = useState(false);
  const subscriptionRef = useRef<any>(null);
  const { playSound } = useNotificationSound({ enabled: true, volume: 0.5 });
  const prevUnreadCountRef = useRef(0);

  useEffect(() => {
    if (user) {
      loadUnreadCount();
      const cleanup = subscribeToTickets();
      return cleanup;
    }
  }, [user]);

  useEffect(() => {
    if (unreadCount > prevUnreadCountRef.current && prevUnreadCountRef.current !== 0) {
      playSound();
    }
    prevUnreadCountRef.current = unreadCount;
  }, [unreadCount, playSound]);

  const loadUnreadCount = async () => {
    if (!user) return;

    try {
      const { data: tickets } = await supabase
        .from('support_tickets')
        .select('id')
        .eq('user_id', user.id)
        .in('status', ['open', 'in_progress', 'waiting_user']);

      if (!tickets) return;

      let total = 0;
      for (const ticket of tickets) {
        const { count } = await supabase
          .from('support_messages')
          .select('*', { count: 'exact', head: true })
          .eq('ticket_id', ticket.id)
          .eq('sender_type', 'admin')
          .is('read_at', null);

        total += count || 0;
      }

      setUnreadCount(total);
    } catch (error) {
      console.error('Error loading unread count:', error);
    }
  };

  const subscribeToTickets = () => {
    if (!user) return () => {};

    if (subscriptionRef.current) {
      subscriptionRef.current.unsubscribe();
    }

    const channel = supabase
      .channel('widget_tickets_realtime')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
        },
        (payload) => {
          const newMsg = payload.new as any;
          if (newMsg.sender_type === 'admin') {
            loadUnreadCount();
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'support_messages',
        },
        () => {
          loadUnreadCount();
        }
      );

    channel.subscribe();
    subscriptionRef.current = channel;

    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.unsubscribe();
        subscriptionRef.current = null;
      }
    };
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setSending(true);
    try {
      const { data: categories } = await supabase
        .from('support_categories')
        .select('id')
        .eq('name', 'Other')
        .single();

      const { data: ticket, error: ticketError } = await supabase
        .from('support_tickets')
        .insert({
          user_id: user.id,
          subject,
          category_id: categories?.id,
          priority: 'medium',
          status: 'open',
        })
        .select()
        .single();

      if (ticketError) throw ticketError;

      const { error: messageError } = await supabase
        .from('support_messages')
        .insert({
          ticket_id: ticket.id,
          sender_id: user.id,
          sender_type: 'user',
          message,
        });

      if (messageError) throw messageError;

      setSuccess(true);
      setSubject('');
      setMessage('');
      setTimeout(() => {
        setSuccess(false);
        setIsOpen(false);
      }, 2000);
    } catch (error) {
      console.error('Error creating ticket:', error);
    } finally {
      setSending(false);
    }
  };

  if (!isAuthenticated) return null;

  return (
    <>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="fixed bottom-6 right-6 w-14 h-14 bg-blue-600 hover:bg-blue-700 rounded-full shadow-lg flex items-center justify-center transition-all z-40"
      >
        {isOpen ? (
          <X className="w-6 h-6 text-white" />
        ) : (
          <>
            <MessageCircle className="w-6 h-6 text-white" />
            {unreadCount > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 rounded-full text-xs text-white flex items-center justify-center animate-pulse">
                {unreadCount > 9 ? '9+' : unreadCount}
              </span>
            )}
          </>
        )}
      </button>

      {isOpen && (
        <div className="fixed bottom-24 right-6 w-96 bg-gray-900 rounded-xl border border-gray-800 shadow-2xl z-40 flex flex-col max-h-[600px]">
          <div className="bg-blue-600 px-6 py-4 rounded-t-xl">
            <h3 className="text-white font-semibold">Quick Support</h3>
            <p className="text-blue-100 text-sm">Send us a message</p>
          </div>

          {success ? (
            <div className="p-6 flex-1 flex items-center justify-center">
              <div className="text-center">
                <div className="w-16 h-16 bg-green-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg
                    className="w-8 h-8 text-green-500"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                </div>
                <h4 className="text-white font-medium mb-2">Ticket Created</h4>
                <p className="text-gray-400 text-sm">
                  We'll respond as soon as possible
                </p>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="p-6 space-y-4 flex-1 flex flex-col">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Subject
                </label>
                <input
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  placeholder="What do you need help with?"
                  className="w-full px-4 py-2 bg-gray-800/50 border border-gray-700 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
                  required
                />
              </div>

              <div className="flex-1">
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Message
                </label>
                <textarea
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Describe your issue..."
                  rows={4}
                  className="w-full px-4 py-2 bg-gray-800/50 border border-gray-700 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500 resize-none"
                  required
                />
              </div>

              <button
                type="submit"
                disabled={sending}
                className="w-full py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              >
                <Send className="w-4 h-4" />
                {sending ? 'Sending...' : 'Send Message'}
              </button>

              <p className="text-xs text-gray-500 text-center">
                Or visit your profile to view all tickets
              </p>
            </form>
          )}
        </div>
      )}
    </>
  );
}

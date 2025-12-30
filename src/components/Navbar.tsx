import { User, Bell, Settings, Wallet, ChevronDown, Zap, Shield, LogOut, Menu, X } from 'lucide-react';
import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import { useAuth } from '../context/AuthContext';
import AuthModal from './AuthModal';
import NotificationsPanel from './NotificationsPanel';
import { supabase } from '../lib/supabase';

export default function Navbar() {
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [pendingTradesCount, setPendingTradesCount] = useState(0);
  const { navigateTo } = useNavigation();
  const { isAuthenticated, signOut, profile, user, canAccessAdmin, staffInfo } = useAuth();

  useEffect(() => {
    if (user) {
      loadUnreadCount();
      loadPendingTradesCount();

      const subscription = supabase
        .channel('notifications_count')
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        }, () => {
          loadUnreadCount();
        })
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'copy_trade_notifications',
          filter: `follower_id=eq.${user.id}`
        }, () => {
          loadPendingTradesCount();
        })
        .subscribe();

      return () => {
        subscription.unsubscribe();
      };
    }
  }, [user]);

  const loadUnreadCount = async () => {
    if (!user) return;

    try {
      const { count, error } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('read', false);

      if (error) throw error;
      setUnreadCount(count || 0);
    } catch (error) {
      console.error('Error loading unread count:', error);
    }
  };

  const loadPendingTradesCount = async () => {
    if (!user) return;

    try {
      const { count, error } = await supabase
        .from('copy_trade_notifications')
        .select('*', { count: 'exact', head: true })
        .eq('follower_id', user.id)
        .eq('notification_status', 'unread');

      if (error) throw error;
      setPendingTradesCount(count || 0);
    } catch (error) {
      console.error('Error loading pending trades count:', error);
    }
  };

  const handleProtectedAction = (action: () => void) => {
    if (isAuthenticated) {
      action();
    } else {
      setShowAuthModal(true);
    }
  };

  const menuItems = [
    { label: 'Markets', hasDropdown: false, onClick: () => navigateTo('markets'), protected: false },
    { label: 'Futures', hasDropdown: false, onClick: () => navigateTo('futures'), protected: false },
    { label: 'Earn', hasDropdown: false, onClick: () => navigateTo('earn'), protected: false },
    { label: 'Swap', hasDropdown: false, onClick: () => handleProtectedAction(() => navigateTo('swap')), protected: true },
    { label: 'Copy Trading', hasDropdown: false, onClick: () => handleProtectedAction(() => navigateTo('copytrading')), protected: true, ...(pendingTradesCount > 0 && { badge: pendingTradesCount }) },
    { label: 'Giveaway', hasDropdown: false, onClick: () => navigateTo('giveaway'), protected: false, highlight: true },
    { label: 'Wallet', hasDropdown: false, onClick: () => handleProtectedAction(() => navigateTo('wallet')), protected: true },
  ];

  return (
    <>
      <AuthModal isOpen={showAuthModal} onClose={() => setShowAuthModal(false)} />
      <nav className="glass-nav px-4 py-3 sticky top-0 z-50">
      <div className="flex items-center justify-between max-w-[1920px] mx-auto">
        <div className="flex items-center gap-4 sm:gap-8">
          <button onClick={() => navigateTo('home')} className="flex items-center gap-2 sm:gap-3 group cursor-pointer">
            <div className="relative">
              <div className="w-8 h-8 sm:w-10 sm:h-10 bg-gradient-to-br from-[#f0b90b] via-[#f8d12f] to-[#f0b90b] flex items-center justify-center transform rotate-45 rounded-lg neon-glow animate-pulse-slow">
                <Zap className="transform -rotate-45 text-black w-4 h-4 sm:w-5 sm:h-5" strokeWidth={2.5} />
              </div>
              <div className="absolute inset-0 bg-gradient-to-br from-[#f0b90b] to-[#f8d12f] rounded-lg blur-xl opacity-50 animate-pulse-slow"></div>
            </div>
            <span className="text-[#f0b90b] text-sm sm:text-xl font-bold tracking-wider neon-text hidden xs:inline">SHARK TRADES</span>
          </button>

          <div className="hidden lg:flex items-center gap-6">
            {menuItems.map((item) => (
              <button
                key={item.label}
                onClick={item.onClick}
                className={`relative transition-all duration-300 text-sm font-medium flex items-center gap-1 group py-1 ${
                  item.highlight
                    ? 'text-yellow-400 hover:text-yellow-300'
                    : 'text-gray-300 hover:text-[#f0b90b]'
                }`}
              >
                {item.label}
                {item.highlight && (
                  <span className="absolute -top-1 -right-1 w-2 h-2 bg-yellow-400 rounded-full animate-pulse" />
                )}
                {item.hasDropdown && <ChevronDown className="w-3 h-3 transition-transform group-hover:rotate-180" />}
                {item.badge !== undefined && (
                  <span className="ml-1 min-w-[18px] h-[18px] bg-[#f0b90b] text-black text-[10px] font-bold rounded-full flex items-center justify-center px-1">
                    {item.badge > 9 ? '9+' : item.badge}
                  </span>
                )}
                <span className="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] transition-all duration-300 group-hover:w-full"></span>
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center gap-2">
          {!isAuthenticated ? (
            <button
              onClick={() => navigateTo('signin')}
              className="bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] hover:from-[#f8d12f] hover:to-[#f0b90b] text-black px-3 sm:px-5 py-2 sm:py-2.5 rounded-full font-semibold text-xs sm:text-sm flex items-center gap-1 sm:gap-2 transition-all duration-300 hover:scale-105 neon-glow-hover shadow-lg"
            >
              <User className="w-4 h-4" />
              <span className="hidden sm:inline">Sign In</span>
            </button>
          ) : (
            <button
              onClick={() => handleProtectedAction(() => navigateTo('deposit'))}
              className="bg-gradient-to-r from-[#f0b90b] to-[#f8d12f] hover:from-[#f8d12f] hover:to-[#f0b90b] text-black px-3 sm:px-5 py-2 sm:py-2.5 rounded-full font-semibold text-xs sm:text-sm flex items-center gap-1 sm:gap-2 transition-all duration-300 hover:scale-105 neon-glow-hover shadow-lg"
            >
              <Wallet className="w-4 h-4" />
              <span className="hidden sm:inline">Deposit</span>
            </button>
          )}

          <div className="hidden md:flex items-center gap-2">
            {canAccessAdmin() && (
              <button
                onClick={() => navigateTo('admindashboard')}
                className="text-gray-400 hover:text-[#f0b90b] transition-all duration-300 hover:scale-110 p-2 rounded-full hover:bg-[#f0b90b]/10 relative"
                title={staffInfo?.role_name ? `Admin Panel (${staffInfo.role_name})` : 'Admin Panel'}
              >
                <Settings className="w-5 h-5" />
              </button>
            )}

            <button
              onClick={() => handleProtectedAction(() => navigateTo('kyc'))}
              className="text-gray-400 hover:text-[#f0b90b] transition-all duration-300 hover:scale-110 p-2 rounded-full hover:bg-[#f0b90b]/10 relative"
              title="KYC Verification"
            >
              <Shield className="w-5 h-5" />
            </button>

            {isAuthenticated && (
              <button
                onClick={() => navigateTo('profile')}
                className="text-gray-400 hover:text-[#f0b90b] transition-all duration-300 hover:scale-110 p-2 rounded-full hover:bg-[#f0b90b]/10 relative"
                title="Profile"
              >
                <User className="w-5 h-5" />
              </button>
            )}

            <div className="relative">
              <button
                data-notification-button
                onClick={() => handleProtectedAction(() => setShowNotifications(!showNotifications))}
                className="text-gray-400 hover:text-[#f0b90b] transition-all duration-300 hover:scale-110 p-2 rounded-full hover:bg-[#f0b90b]/10 relative"
              >
                <Bell className="w-5 h-5" />
                {unreadCount > 0 && (
                  <span className="absolute top-0 right-0 min-w-[18px] h-[18px] bg-[#f0b90b] text-black text-[10px] font-bold rounded-full flex items-center justify-center px-1">
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </button>
              {showNotifications && (
                <NotificationsPanel
                  isOpen={showNotifications}
                  onClose={() => setShowNotifications(false)}
                  onNavigate={navigateTo}
                />
              )}
            </div>

            {isAuthenticated && (
              <button
                onClick={signOut}
                className="text-gray-400 hover:text-red-400 transition-all duration-300 hover:scale-110 p-2 rounded-full hover:bg-red-500/10"
                title="Logout"
              >
                <LogOut className="w-5 h-5" />
              </button>
            )}
          </div>

          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden text-gray-400 hover:text-[#f0b90b] p-2 transition-colors"
          >
            {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>
      </div>
    </nav>

      {mobileMenuOpen && (
        <div className="md:hidden fixed inset-0 top-[60px] bg-[#0b0e11]/95 backdrop-blur-lg z-40">
          <div className="flex flex-col p-4 space-y-2">
            {menuItems.map((item) => (
              <button
                key={item.label}
                onClick={() => {
                  item.onClick();
                  setMobileMenuOpen(false);
                }}
                className="text-left text-gray-300 hover:text-[#f0b90b] px-4 py-3 rounded-lg hover:bg-[#181a20] transition-all text-base font-medium"
              >
                {item.label}
              </button>
            ))}

            <div className="border-t border-gray-800 my-2"></div>

            {canAccessAdmin() && (
              <button
                onClick={() => {
                  navigateTo('admindashboard');
                  setMobileMenuOpen(false);
                }}
                className="text-left text-[#f0b90b] hover:text-[#f8d12f] px-4 py-3 rounded-lg hover:bg-[#f0b90b]/10 transition-all text-base font-medium flex items-center gap-2"
              >
                <Settings className="w-5 h-5" />
                Admin Panel {staffInfo?.role_name && `(${staffInfo.role_name})`}
              </button>
            )}

            <button
              onClick={() => {
                handleProtectedAction(() => navigateTo('kyc'));
                setMobileMenuOpen(false);
              }}
              className="text-left text-gray-300 hover:text-[#f0b90b] px-4 py-3 rounded-lg hover:bg-[#181a20] transition-all text-base font-medium flex items-center gap-2"
            >
              <Shield className="w-5 h-5" />
              KYC Verification
            </button>

            {isAuthenticated && (
              <button
                onClick={() => {
                  navigateTo('profile');
                  setMobileMenuOpen(false);
                }}
                className="text-left text-gray-300 hover:text-[#f0b90b] px-4 py-3 rounded-lg hover:bg-[#181a20] transition-all text-base font-medium flex items-center gap-2"
              >
                <User className="w-5 h-5" />
                Profile
              </button>
            )}

            <button
              onClick={() => {
                handleProtectedAction(() => setShowNotifications(true));
                setMobileMenuOpen(false);
              }}
              className="text-left text-gray-300 hover:text-[#f0b90b] px-4 py-3 rounded-lg hover:bg-[#181a20] transition-all text-base font-medium flex items-center gap-2 relative"
            >
              <Bell className="w-5 h-5" />
              Notifications
              {unreadCount > 0 && (
                <span className="ml-auto min-w-[22px] h-[22px] bg-[#f0b90b] text-black text-xs font-bold rounded-full flex items-center justify-center px-1">
                  {unreadCount > 9 ? '9+' : unreadCount}
                </span>
              )}
            </button>

            {isAuthenticated && (
              <button
                onClick={() => {
                  signOut();
                  setMobileMenuOpen(false);
                }}
                className="text-left text-gray-300 hover:text-red-400 px-4 py-3 rounded-lg hover:bg-[#181a20] transition-all text-base font-medium flex items-center gap-2"
              >
                <LogOut className="w-5 h-5" />
                Logout
              </button>
            )}
          </div>
        </div>
      )}
    </>
  );
}

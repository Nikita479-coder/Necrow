import Navbar from '../components/Navbar';
import UserSupportTickets from '../components/support/UserSupportTickets';
import { useAuth } from '../context/AuthContext';
import { MessageSquare } from 'lucide-react';

export default function Support() {
  const { isAuthenticated } = useAuth();

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-[#0b0e11] via-[#1a1d24] to-[#0b0e11]">
        <Navbar />
        <div className="flex items-center justify-center min-h-[calc(100vh-80px)]">
          <div className="text-center">
            <MessageSquare className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <h2 className="text-2xl font-bold text-white mb-2">Sign In Required</h2>
            <p className="text-gray-400">
              Please sign in to access support and create tickets
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-[#0b0e11] via-[#1a1d24] to-[#0b0e11]">
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <MessageSquare className="w-8 h-8 text-[#f0b90b]" />
            <h1 className="text-3xl font-bold text-white">Support Center</h1>
          </div>
          <p className="text-gray-400">
            Need help? Create a support ticket and our team will assist you.
          </p>
        </div>

        <UserSupportTickets />
      </div>
    </div>
  );
}

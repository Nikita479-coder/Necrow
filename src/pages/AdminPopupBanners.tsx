import { useEffect, useState } from 'react';
import { ArrowLeft } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';
import PopupBannerManager from '../components/admin/PopupBannerManager';

export default function AdminPopupBanners() {
  const { user, canAccessAdmin, profile, staffInfo, loading: authLoading } = useAuth();
  const { navigateTo } = useNavigation();
  const [hasAccess, setHasAccess] = useState(false);

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

  if (!hasAccess) {
    return null;
  }

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

        <PopupBannerManager />
      </div>
    </div>
  );
}

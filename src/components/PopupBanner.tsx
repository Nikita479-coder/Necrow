import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface PopupData {
  id: string;
  title: string;
  description: string | null;
  image_url: string;
  created_at: string;
}

export default function PopupBanner() {
  const { isAuthenticated } = useAuth();
  const [currentPopup, setCurrentPopup] = useState<PopupData | null>(null);
  const [loading, setLoading] = useState(false);
  const [imageLoaded, setImageLoaded] = useState(false);

  useEffect(() => {
    if (isAuthenticated) {
      loadUnseenPopups();
    }
  }, [isAuthenticated]);

  const loadUnseenPopups = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_unseen_popups');

      if (error) throw error;

      if (data && data.length > 0) {
        setCurrentPopup(data[0]);
      }
    } catch (error) {
      console.error('Error loading popups:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleClose = async () => {
    if (!currentPopup) return;

    try {
      const { error } = await supabase.rpc('mark_popup_viewed', {
        p_popup_id: currentPopup.id
      });

      if (error) throw error;

      setCurrentPopup(null);
      setImageLoaded(false);

      setTimeout(() => {
        loadUnseenPopups();
      }, 500);
    } catch (error) {
      console.error('Error marking popup as viewed:', error);
    }
  };

  if (!currentPopup || loading) return null;

  return (
    <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4 animate-fadeIn">
      <div
        className="absolute inset-0 bg-black/80 backdrop-blur-sm"
        onClick={handleClose}
      />

      <div className="relative bg-[#0b0e11] rounded-2xl border border-gray-800 max-w-4xl w-full max-h-[90vh] overflow-hidden shadow-2xl animate-slideUp">
        <button
          onClick={handleClose}
          className="absolute top-4 right-4 z-10 p-2 bg-black/50 hover:bg-black/70 rounded-full text-white transition-colors backdrop-blur-sm"
          aria-label="Close popup"
        >
          <X className="w-6 h-6" />
        </button>

        <div className="relative">
          {!imageLoaded && (
            <div className="absolute inset-0 flex items-center justify-center bg-[#1a1d24]">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b]"></div>
            </div>
          )}

          <img
            src={currentPopup.image_url}
            alt={currentPopup.title}
            className={`w-full h-auto max-h-[60vh] object-contain transition-opacity duration-300 ${
              imageLoaded ? 'opacity-100' : 'opacity-0'
            }`}
            onLoad={() => setImageLoaded(true)}
            onError={() => {
              console.error('Failed to load popup image');
              setImageLoaded(true);
            }}
          />
        </div>

        {(currentPopup.title || currentPopup.description) && (
          <div className="p-6 border-t border-gray-800">
            {currentPopup.title && (
              <h3 className="text-2xl font-bold text-white mb-2">
                {currentPopup.title}
              </h3>
            )}
            {currentPopup.description && (
              <p className="text-gray-400 leading-relaxed">
                {currentPopup.description}
              </p>
            )}
          </div>
        )}

        <div className="px-6 pb-6">
          <button
            onClick={handleClose}
            className="w-full px-6 py-3 bg-[#f0b90b] text-black rounded-xl font-medium hover:bg-[#d4a50a] transition-colors"
          >
            Got it!
          </button>
        </div>
      </div>

      <style>{`
        @keyframes fadeIn {
          from {
            opacity: 0;
          }
          to {
            opacity: 1;
          }
        }

        @keyframes slideUp {
          from {
            opacity: 0;
            transform: translateY(20px) scale(0.95);
          }
          to {
            opacity: 1;
            transform: translateY(0) scale(1);
          }
        }

        .animate-fadeIn {
          animation: fadeIn 0.2s ease-out;
        }

        .animate-slideUp {
          animation: slideUp 0.3s ease-out;
        }
      `}</style>
    </div>
  );
}

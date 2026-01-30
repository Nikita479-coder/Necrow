import { useState, useEffect } from 'react';
import { Cookie, Settings, Check, Shield } from 'lucide-react';
import { useNavigation } from '../App';

function CookieConsentBanner() {
  const [isVisible, setIsVisible] = useState(false);
  const [showPreferences, setShowPreferences] = useState(false);
  const { navigateTo } = useNavigation();

  const [preferences, setPreferences] = useState({
    necessary: true,
    analytics: true,
    marketing: false,
  });

  useEffect(() => {
    const consent = localStorage.getItem('cookieConsent');
    if (!consent) {
      const timer = setTimeout(() => setIsVisible(true), 1000);
      return () => clearTimeout(timer);
    }
  }, []);

  const handleAcceptAll = () => {
    const consentData = {
      necessary: true,
      analytics: true,
      marketing: true,
      timestamp: new Date().toISOString(),
    };
    localStorage.setItem('cookieConsent', JSON.stringify(consentData));
    setIsVisible(false);
  };

  const handleAcceptSelected = () => {
    const consentData = {
      ...preferences,
      timestamp: new Date().toISOString(),
    };
    localStorage.setItem('cookieConsent', JSON.stringify(consentData));
    setIsVisible(false);
  };

  const handleRejectNonEssential = () => {
    const consentData = {
      necessary: true,
      analytics: false,
      marketing: false,
      timestamp: new Date().toISOString(),
    };
    localStorage.setItem('cookieConsent', JSON.stringify(consentData));
    setIsVisible(false);
  };

  if (!isVisible) return null;

  return (
    <div className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="w-full max-w-2xl mx-4 mb-4 sm:mb-0 bg-[#181a20] border border-gray-700 rounded-2xl shadow-2xl overflow-hidden">
        {!showPreferences ? (
          <div className="p-6">
            <div className="flex items-start gap-4 mb-4">
              <div className="w-12 h-12 bg-amber-500/20 rounded-xl flex items-center justify-center flex-shrink-0">
                <Cookie className="w-6 h-6 text-amber-400" />
              </div>
              <div>
                <h3 className="text-white font-bold text-lg mb-1">We Value Your Privacy</h3>
                <p className="text-gray-400 text-sm">
                  We use cookies to enhance your browsing experience, analyze site traffic, and personalize content.
                  By clicking "Accept All", you consent to our use of cookies.
                </p>
              </div>
            </div>

            <div className="bg-[#0b0e11] rounded-xl p-4 mb-4 border border-gray-800">
              <div className="flex items-center gap-2 mb-2">
                <Shield className="w-4 h-4 text-emerald-400" />
                <span className="text-white text-sm font-medium">Your data is protected</span>
              </div>
              <p className="text-gray-500 text-xs">
                We comply with GDPR, CCPA, and other applicable privacy regulations.
                You can change your preferences at any time.
              </p>
            </div>

            <div className="flex flex-col sm:flex-row gap-3">
              <button
                onClick={handleAcceptAll}
                className="flex-1 py-3 bg-amber-500 hover:bg-amber-600 text-black font-semibold rounded-xl transition-colors flex items-center justify-center gap-2"
              >
                <Check className="w-4 h-4" />
                Accept All Cookies
              </button>
              <button
                onClick={handleRejectNonEssential}
                className="flex-1 py-3 bg-[#0b0e11] hover:bg-gray-800 text-white font-medium rounded-xl border border-gray-700 transition-colors"
              >
                Essential Only
              </button>
              <button
                onClick={() => setShowPreferences(true)}
                className="sm:w-auto py-3 px-4 text-gray-400 hover:text-white font-medium rounded-xl border border-gray-700 hover:border-gray-600 transition-colors flex items-center justify-center gap-2"
              >
                <Settings className="w-4 h-4" />
                <span className="sm:hidden">Preferences</span>
              </button>
            </div>

            <div className="mt-4 text-center">
              <button
                onClick={() => navigateTo('legal')}
                className="text-gray-500 hover:text-amber-400 text-xs transition-colors"
              >
                Read our Privacy Policy and Cookie Policy
              </button>
            </div>
          </div>
        ) : (
          <div className="p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-bold text-lg">Cookie Preferences</h3>
              <button
                onClick={() => setShowPreferences(false)}
                className="text-gray-400 hover:text-white text-sm"
              >
                Back
              </button>
            </div>

            <div className="space-y-4 mb-6">
              <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <span className="text-white font-medium">Strictly Necessary</span>
                    <span className="text-xs bg-emerald-500/20 text-emerald-400 px-2 py-0.5 rounded-full">Required</span>
                  </div>
                  <div className="w-10 h-6 bg-emerald-500 rounded-full flex items-center justify-end px-0.5">
                    <div className="w-5 h-5 bg-white rounded-full"></div>
                  </div>
                </div>
                <p className="text-gray-500 text-xs">
                  Essential for the website to function properly. Cannot be disabled.
                </p>
              </div>

              <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-white font-medium">Analytics & Performance</span>
                  <button
                    onClick={() => setPreferences(p => ({ ...p, analytics: !p.analytics }))}
                    className={`w-10 h-6 rounded-full flex items-center px-0.5 transition-colors ${
                      preferences.analytics ? 'bg-amber-500 justify-end' : 'bg-gray-600 justify-start'
                    }`}
                  >
                    <div className="w-5 h-5 bg-white rounded-full"></div>
                  </button>
                </div>
                <p className="text-gray-500 text-xs">
                  Help us understand how visitors interact with our website.
                </p>
              </div>

              <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-white font-medium">Marketing & Advertising</span>
                  <button
                    onClick={() => setPreferences(p => ({ ...p, marketing: !p.marketing }))}
                    className={`w-10 h-6 rounded-full flex items-center px-0.5 transition-colors ${
                      preferences.marketing ? 'bg-amber-500 justify-end' : 'bg-gray-600 justify-start'
                    }`}
                  >
                    <div className="w-5 h-5 bg-white rounded-full"></div>
                  </button>
                </div>
                <p className="text-gray-500 text-xs">
                  Used to deliver personalized advertisements and track conversions.
                </p>
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={handleAcceptSelected}
                className="flex-1 py-3 bg-amber-500 hover:bg-amber-600 text-black font-semibold rounded-xl transition-colors"
              >
                Save Preferences
              </button>
              <button
                onClick={handleAcceptAll}
                className="flex-1 py-3 bg-[#0b0e11] hover:bg-gray-800 text-white font-medium rounded-xl border border-gray-700 transition-colors"
              >
                Accept All
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default CookieConsentBanner;

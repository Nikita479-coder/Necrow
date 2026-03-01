import { X, Lock } from 'lucide-react';
import { useNavigation } from '../App';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

function AuthModal({ isOpen, onClose }: AuthModalProps) {
  const { navigateTo } = useNavigation();

  if (!isOpen) return null;

  const handleSignIn = () => {
    onClose();
    navigateTo('signin');
  };

  const handleSignUp = () => {
    onClose();
    navigateTo('signup');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div
        className="absolute inset-0 bg-black/70 backdrop-blur-sm"
        onClick={onClose}
      />

      <div className="relative bg-gradient-to-br from-gray-900 to-gray-800 border border-gray-700 rounded-2xl p-8 max-w-md w-full mx-4 shadow-2xl transform transition-all">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-white transition-colors"
        >
          <X className="w-6 h-6" />
        </button>

        <div className="flex flex-col items-center text-center mb-6">
          <div className="w-16 h-16 bg-[#f0b90b]/10 rounded-full flex items-center justify-center mb-4">
            <Lock className="w-8 h-8 text-[#f0b90b]" />
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">Authentication Required</h2>
          <p className="text-gray-400">
            You need to sign in to access this feature. Create an account or sign in to continue.
          </p>
        </div>

        <div className="space-y-3">
          <button
            onClick={handleSignIn}
            className="w-full bg-[#f0b90b] hover:bg-[#d9a506] text-black font-semibold py-3 rounded-lg transition-colors duration-200"
          >
            Sign In
          </button>

          <button
            onClick={handleSignUp}
            className="w-full bg-gray-700 hover:bg-gray-600 text-white font-semibold py-3 rounded-lg transition-colors duration-200"
          >
            Create Account
          </button>
        </div>

        <p className="text-center text-gray-500 text-sm mt-6">
          Join thousands of traders worldwide
        </p>
      </div>
    </div>
  );
}

export default AuthModal;

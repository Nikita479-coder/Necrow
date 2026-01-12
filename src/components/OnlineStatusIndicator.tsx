import { useOnlineStatus } from '../hooks/useOnlineStatus';

interface OnlineStatusIndicatorProps {
  userId: string;
  showText?: boolean;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export default function OnlineStatusIndicator({
  userId,
  showText = false,
  size = 'md',
  className = ''
}: OnlineStatusIndicatorProps) {
  const { isOnline, loading } = useOnlineStatus(userId);

  const sizeClasses = {
    sm: 'w-2 h-2',
    md: 'w-3 h-3',
    lg: 'w-4 h-4'
  };

  if (loading) {
    return (
      <div className={`flex items-center gap-2 ${className}`}>
        <div className={`${sizeClasses[size]} rounded-full bg-gray-600 animate-pulse`} />
        {showText && <span className="text-xs text-gray-500">Loading...</span>}
      </div>
    );
  }

  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <div className="relative">
        <div
          className={`${sizeClasses[size]} rounded-full ${
            isOnline
              ? 'bg-emerald-500'
              : 'bg-gray-600'
          }`}
        />
        {isOnline && (
          <div
            className={`absolute inset-0 ${sizeClasses[size]} rounded-full bg-emerald-500 animate-ping opacity-75`}
          />
        )}
      </div>
      {showText && (
        <span className={`text-xs ${isOnline ? 'text-emerald-400' : 'text-gray-500'}`}>
          {isOnline ? 'Online' : 'Offline'}
        </span>
      )}
    </div>
  );
}

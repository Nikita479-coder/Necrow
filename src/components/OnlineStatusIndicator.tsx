import { useState, useEffect } from 'react';
import { getGlobalOnlineUsers } from '../hooks/usePresence';

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
  const [isOnline, setIsOnline] = useState(false);

  useEffect(() => {
    const checkStatus = () => {
      const users = getGlobalOnlineUsers();
      setIsOnline(users.some(u => u.id === userId));
    };

    checkStatus();
    const interval = setInterval(checkStatus, 1000);

    return () => clearInterval(interval);
  }, [userId]);

  const sizeClasses = {
    sm: 'w-2 h-2',
    md: 'w-3 h-3',
    lg: 'w-4 h-4'
  };

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

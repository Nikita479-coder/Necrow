import { useState, useEffect } from 'react';
import { sessionService } from '../services/sessionService';

export function useOnlineStatus(userId: string | null | undefined) {
  const [isOnline, setIsOnline] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    if (!userId) {
      setIsOnline(false);
      setLoading(false);
      return;
    }

    const checkStatus = async () => {
      setLoading(true);
      const online = await sessionService.checkUserOnlineStatus(userId);
      setIsOnline(online);
      setLoading(false);
    };

    checkStatus();

    const unsubscribe = sessionService.subscribeToOnlineStatus((changedUserId, online) => {
      if (changedUserId === userId) {
        setIsOnline(online);
      }
    });

    return () => {
      unsubscribe();
    };
  }, [userId]);

  return { isOnline, loading };
}

export function useMultipleOnlineStatus(userIds: string[]) {
  const [onlineStatus, setOnlineStatus] = useState<Map<string, boolean>>(new Map());
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    if (userIds.length === 0) {
      setOnlineStatus(new Map());
      setLoading(false);
      return;
    }

    const checkStatus = async () => {
      setLoading(true);
      const statusMap = await sessionService.getUsersOnlineStatus(userIds);
      setOnlineStatus(statusMap);
      setLoading(false);
    };

    checkStatus();

    const unsubscribe = sessionService.subscribeToOnlineStatus((changedUserId, online) => {
      if (userIds.includes(changedUserId)) {
        setOnlineStatus(prev => {
          const newMap = new Map(prev);
          newMap.set(changedUserId, online);
          return newMap;
        });
      }
    });

    return () => {
      unsubscribe();
    };
  }, [userIds.join(',')]);

  return { onlineStatus, loading };
}

export function useOnlineUsers() {
  const [onlineUsers, setOnlineUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    const fetchOnlineUsers = async () => {
      setLoading(true);
      const users = await sessionService.getOnlineUsers();
      setOnlineUsers(users);
      setLoading(false);
    };

    fetchOnlineUsers();

    const refreshInterval = setInterval(fetchOnlineUsers, 60000);

    const unsubscribe = sessionService.subscribeToOnlineStatus(() => {
      fetchOnlineUsers();
    });

    return () => {
      clearInterval(refreshInterval);
      unsubscribe();
    };
  }, []);

  return { onlineUsers, loading };
}

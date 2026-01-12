# Real-Time Online Status System

## Overview

The platform now features a real-time online status tracking system using Supabase Realtime. This system provides instant updates when users come online or go offline, with a 2-minute activity timeout.

## How It Works

### Backend (Database)

1. **user_sessions table**: Tracks each user's online status
   - `is_online`: Boolean flag for online status
   - `heartbeat`: Updated every 30 seconds while user is active
   - `last_activity`: Last activity timestamp
   - `last_seen`: Last time user was seen online

2. **Realtime Subscriptions**: Table is published for realtime updates
   - All changes to user_sessions are broadcast instantly
   - Authenticated users can subscribe to status changes

3. **Database Functions**:
   - `update_user_session()`: Updates user heartbeat and online status
   - `is_user_online(user_id)`: Checks if specific user is online
   - `get_users_online_status(user_ids[])`: Bulk check multiple users
   - `get_online_users()`: Returns list of all currently online users
   - `mark_inactive_users_offline()`: Auto-marks users offline after 2 minutes

### Frontend (React)

1. **sessionService**: Core service managing online status
   - Sends heartbeat every 30 seconds
   - Subscribes to realtime database changes
   - Maintains in-memory cache of online users
   - Notifies components of status changes

2. **React Hooks**:
   - `useOnlineStatus(userId)`: Track single user's online status
   - `useMultipleOnlineStatus(userIds[])`: Track multiple users
   - `useOnlineUsers()`: Get list of all online users

3. **Component**:
   - `OnlineStatusIndicator`: Visual indicator showing online/offline status

## Usage Examples

### Display Online Status for a User

```tsx
import OnlineStatusIndicator from '../components/OnlineStatusIndicator';

function UserCard({ userId }) {
  return (
    <div>
      <OnlineStatusIndicator
        userId={userId}
        showText={true}
        size="md"
      />
    </div>
  );
}
```

### Check Online Status in Code

```tsx
import { useOnlineStatus } from '../hooks/useOnlineStatus';

function Component({ userId }) {
  const { isOnline, loading } = useOnlineStatus(userId);

  if (loading) return <div>Loading...</div>;

  return <div>{isOnline ? 'User is online' : 'User is offline'}</div>;
}
```

### Track Multiple Users

```tsx
import { useMultipleOnlineStatus } from '../hooks/useOnlineStatus';

function UsersList({ userIds }) {
  const { onlineStatus, loading } = useMultipleOnlineStatus(userIds);

  return (
    <div>
      {userIds.map(id => (
        <div key={id}>
          User: {onlineStatus.get(id) ? 'Online' : 'Offline'}
        </div>
      ))}
    </div>
  );
}
```

### Get All Online Users

```tsx
import { useOnlineUsers } from '../hooks/useOnlineStatus';

function OnlineUsersList() {
  const { onlineUsers, loading } = useOnlineUsers();

  return (
    <div>
      <h3>Online Users ({onlineUsers.length})</h3>
      {onlineUsers.map(user => (
        <div key={user.user_id}>{user.username}</div>
      ))}
    </div>
  );
}
```

## Key Features

1. **Real-Time Updates**: Status changes are broadcast instantly via Supabase Realtime
2. **Accurate Presence Detection**: 30-second heartbeat with 2-minute timeout
3. **Automatic Cleanup**: Users marked offline after 2 minutes of inactivity
4. **Tab Visibility Detection**: Status updates when tab becomes visible/hidden
5. **Network Detection**: Responds to online/offline browser events
6. **Memory Efficient**: Maintains in-memory cache to reduce database queries
7. **React Integration**: Custom hooks for easy component integration

## Technical Details

### Heartbeat System
- **Frequency**: Every 30 seconds (configurable in sessionService.ts)
- **Timeout**: 2 minutes (configurable in database functions)
- **Method**: Updates `heartbeat` column in user_sessions table

### Realtime Subscription
- **Channel**: 'user-sessions'
- **Events**: INSERT, UPDATE, DELETE on user_sessions table
- **Filter**: All authenticated users can subscribe

### Activity Events Tracked
- Tab focus/blur (via visibilitychange event)
- Network status (via online/offline events)
- Page unload (via beforeunload event)
- Manual heartbeat updates

## Performance Considerations

1. **Database Load**: Heartbeat updates every 30 seconds per user
2. **Realtime Connections**: One channel per client for all users
3. **Memory Usage**: In-memory cache of online user IDs
4. **Network Traffic**: Minimal - only status changes are broadcast

## Customization

### Change Heartbeat Frequency
Edit `sessionService.ts`:
```typescript
this.updateInterval = setInterval(() => {
  this.updateSession(true);
}, 30000); // Change this value (in milliseconds)
```

### Change Timeout Duration
Edit the database migration or run:
```sql
-- Update the timeout to 5 minutes
ALTER FUNCTION is_user_online(uuid) ...
WHERE s.heartbeat > now() - interval '5 minutes'
```

### Add Custom Status Events
Subscribe to status changes:
```typescript
import { sessionService } from '../services/sessionService';

sessionService.subscribeToOnlineStatus((userId, isOnline) => {
  console.log(`User ${userId} is now ${isOnline ? 'online' : 'offline'}`);
});
```

## Troubleshooting

### Users Not Showing as Online
1. Check if realtime is enabled on user_sessions table
2. Verify user is authenticated
3. Check browser console for errors
4. Verify sessionService is started in AuthContext

### Status Not Updating in Real-Time
1. Check Supabase Realtime connection
2. Verify publication includes user_sessions table
3. Check RLS policies allow reading session data
4. Ensure component is using the hooks correctly

### High Database Load
1. Increase heartbeat interval (default 30s)
2. Increase timeout duration (default 2min)
3. Add database indexes if needed (already included)

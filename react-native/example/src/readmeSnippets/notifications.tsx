import { useEffect } from 'react';
import { SallaPush } from '@salla.sa/mobile-push-react-native';
import { settingsScreen } from './standIns';

// The reference's "Events" and "Foreground display": a listener removed by its function, and a screen that decides
// about foreground notifications.

export function followThePermission(): void {
  // snippet:remove-listener
  const onChange = (granted: boolean) => settingsScreen.showPermission(granted);
  SallaPush.Notifications.addEventListener('permissionChange', onChange);
  // Later, the same function removes it:
  SallaPush.Notifications.removeEventListener('permissionChange', onChange);
  // end-snippet
}

export function ChatScreen({ chatId }: { chatId: string }) {
  // snippet:will-display
  useEffect(() => {
    const subscription = SallaPush.Notifications.addEventListener(
      'foregroundWillDisplay',
      (event) => {
        if (event.notification.getString('chat_id') === chatId) {
          event.preventDefault(); // before any await: it counts only while the listener runs
        }
      }
    );
    return () => subscription.remove();
  }, [chatId]);
  // end-snippet
  return null;
}

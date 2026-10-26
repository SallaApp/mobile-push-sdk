import {
  useCallback,
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from 'react';
import {
  Platform,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  SallaPush,
  type SallaPushIOSPermissionStatus,
  type SallaPushLogLevel,
} from '@salla.sa/mobile-push-react-native';
import { Actions } from './Actions';
import { EventLog, Foreground } from './Events';
import { eventLog, tokenEnd } from './eventLog';
import { Button, colors, Line, Section } from './ui';

type Status = {
  sdkVersion: string;
  initialized: boolean;
  appId: string | null;
  deviceId: string | null;
  tokenEnd: string;
  optedIn: boolean;
  permission: boolean;
  permissionStatus: SallaPushIOSPermissionStatus | null;
  externalId: string | null;
  loggedIn: boolean;
  tags: Record<string, string>;
  logLevel: SallaPushLogLevel;
};

export default function App() {
  const [status, refresh] = useStatus();
  return (
    <ScrollView
      contentContainerStyle={styles.content}
      contentInsetAdjustmentBehavior="automatic"
      keyboardShouldPersistTaps="handled"
      style={styles.screen}
    >
      <Text style={styles.title}>SallaPush example</Text>
      {status !== null && !status.initialized ? <NotConfigured /> : null}
      <Section title="Status">
        {status === null ? null : <StatusLines status={status} />}
        <Button title="Refresh" onPress={refresh} />
      </Section>
      <Actions />
      <Foreground />
      <EventLog />
    </ScrollView>
  );
}

/** SallaPush's state, read again on every event of the log and with the Refresh button. */
function useStatus(): [Status | null, () => void] {
  const [status, setStatus] = useState<Status | null>(null);
  const lastEvent = useSyncExternalStore(
    eventLog.subscribe,
    eventLog.lastEventId
  );
  const latest = useRef(0);
  const refresh = useCallback(() => {
    const request = ++latest.current;
    readStatus().then((next) => {
      if (request === latest.current) {
        setStatus(next);
      }
    });
  }, []);
  useEffect(() => {
    refresh();
  }, [refresh, lastEvent]);
  return [status, refresh];
}

async function readStatus(): Promise<Status> {
  const subscription = SallaPush.User.pushSubscription;
  const [
    sdkVersion,
    initialized,
    appId,
    deviceId,
    token,
    optedIn,
    permission,
    permissionStatus,
    externalId,
    loggedIn,
    tags,
    logLevel,
  ] = await Promise.all([
    SallaPush.getSdkVersion(),
    SallaPush.isInitialized(),
    SallaPush.getAppId(),
    subscription.getId(),
    subscription.getToken(),
    subscription.getOptedIn(),
    SallaPush.Notifications.getPermission(),
    SallaPush.Notifications.getPermissionStatus(),
    SallaPush.User.getExternalId(),
    SallaPush.User.isLoggedIn(),
    SallaPush.User.getTags(),
    SallaPush.Debug.getLogLevel(),
  ]);
  return {
    sdkVersion,
    initialized,
    appId,
    deviceId,
    tokenEnd: tokenEnd(token),
    optedIn,
    permission,
    permissionStatus,
    externalId,
    loggedIn,
    tags,
    logLevel,
  };
}

function StatusLines({ status }: { status: Status }) {
  const permission = status.permission ? 'allowed' : 'not allowed';
  const tags = Object.entries(status.tags)
    .map(([key, value]) => `${key}=${value}`)
    .join(', ');
  return (
    <>
      <Line label="SDK" value={status.sdkVersion} />
      <Line label="App id" value={status.appId ?? 'none'} />
      <Line label="Device id" value={status.deviceId ?? 'not registered'} />
      <Line label="Token" value={status.tokenEnd} />
      <Line label="Opted in" value={status.optedIn ? 'yes' : 'no'} />
      <Line
        label="Permission"
        value={
          Platform.OS === 'ios'
            ? `${permission} (${status.permissionStatus})`
            : permission
        }
      />
      <Line
        label="Customer"
        value={
          status.loggedIn ? (status.externalId ?? 'logged in') : 'logged out'
        }
      />
      <Line label="Tags" value={tags === '' ? 'none' : tags} />
      <Line label="Console log level" value={status.logLevel} />
    </>
  );
}

function NotConfigured() {
  return (
    <View style={styles.banner}>
      <Text style={styles.bannerText}>
        Not configured: SallaPush didn't start, since this build has no valid
        app id. Set SALLAPUSH_APP_ID (iOS) or sallapushAppId (Android) as
        example/README.md shows.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: colors.white,
  },
  content: {
    paddingBottom: 48,
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'android' ? (StatusBar.currentHeight ?? 0) : 0,
  },
  title: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '700',
    paddingTop: 12,
  },
  banner: {
    backgroundColor: colors.warning,
    borderRadius: 8,
    marginTop: 12,
    padding: 12,
  },
  bannerText: {
    color: colors.text,
  },
});

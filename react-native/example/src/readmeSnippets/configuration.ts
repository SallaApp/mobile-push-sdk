import {
  SallaPush,
  SallaPushLogLevel,
} from '@salla.sa/mobile-push-react-native';
import { telemetry } from './standIns';

// The reference's "SallaPush" and "SallaPush.Debug": initializing from JavaScript, and a log handler.

export function startWithAppIdFromServer(appId: string): void {
  // snippet:initialize
  SallaPush.initialize(appId, {
    logLevel: SallaPushLogLevel.Info,
    ios: { appGroupIdentifier: 'group.com.example.shop' },
  });
  // end-snippet
}

export function forwardErrors(): void {
  // snippet:log-handler
  SallaPush.Debug.setLogHandler(SallaPushLogLevel.Error, (entry) => {
    telemetry.report('sallapush', entry.code, entry.message, entry.metadata);
  });
  // end-snippet
}

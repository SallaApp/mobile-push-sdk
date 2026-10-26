import NativeRNSallaPush from './NativeRNSallaPush';
import { LogHandlerHub } from './internal/EventHub';
import { func, logLevel, nullable, valid } from './internal/validate';
import type { SallaPushDebugNamespace, SallaPushLogLevel } from './types';

const logHandler = new LogHandlerHub();

export const Debug: SallaPushDebugNamespace = {
  getLogLevel: () =>
    NativeRNSallaPush.getLogLevel() as Promise<SallaPushLogLevel>,
  setLogLevel(level) {
    if (valid('SallaPush.Debug.setLogLevel', { level: [level, logLevel] })) {
      NativeRNSallaPush.setLogLevel(level);
    }
  },
  setLogHandler(level, handler) {
    if (
      valid('SallaPush.Debug.setLogHandler', {
        level: [level, logLevel],
        handler: [handler, nullable(func)],
      })
    ) {
      logHandler.set(level, handler);
    }
  },
};

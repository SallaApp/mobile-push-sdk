import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

import NativeRNSallaPush, { type LogEntrySpec } from '../NativeRNSallaPush';
import { SallaPush, SallaPushLogLevel, type SallaPushLogEntry } from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
let warn: jest.SpiedFunction<typeof console.warn>;
let error: jest.SpiedFunction<typeof console.error>;

beforeEach(() => {
  jest.clearAllMocks();
  warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  error = jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, null);
  warn.mockRestore();
  error.mockRestore();
});

type Handler = jest.Mock<(entry: SallaPushLogEntry) => void>;

const entry: LogEntrySpec = {
  level: 'warn',
  category: 'registration',
  code: 'register.retry',
  message: 'Registration failed (HTTP 503); retrying in 30 s.',
  metadata: { http_status: '503', attempt: '2' },
  timestamp: 1_800_000_000_123,
};

/** Emits a log entry through the handler the hub subscribed to the emitter with. */
function emit(spec: LogEntrySpec): void {
  native.onLog.mock.calls.at(-1)?.[0](spec);
}

describe('SallaPush.Debug', () => {
  it.each(Object.values(SallaPushLogLevel))(
    'resolves the log level %s native reports',
    async (level) => {
      native.getLogLevel.mockResolvedValueOnce(level);

      await expect(SallaPush.Debug.getLogLevel()).resolves.toBe(level);
    }
  );

  it.each(Object.values(SallaPushLogLevel))(
    'sets the log level %s',
    (level) => {
      SallaPush.Debug.setLogLevel(level);

      expect(native.setLogLevel).toHaveBeenCalledWith(level);
    }
  );

  it('drops an unknown log level, with one warning', () => {
    for (const level of ['Debug', 'trace', 3, null]) {
      SallaPush.Debug.setLogLevel(level as unknown as SallaPushLogLevel);
    }

    expect(native.setLogLevel).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      "[SallaPush] SallaPush.Debug.setLogLevel ignored: level must be one of 'off', 'error', 'warn', " +
        "'info', 'debug', 'verbose'."
    );
  });
});

describe('SallaPush.Debug.setLogHandler', () => {
  it('sets the native level, then subscribes, then starts the native registration', () => {
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Info, () => {});

    expect(native.setLogHandlerLevel.mock.calls).toEqual([['info']]);
    expect(native.onLog).toHaveBeenCalledTimes(1);
    expect(native.startEvents.mock.calls).toEqual([['log']]);
    const levelAt = native.setLogHandlerLevel.mock.invocationCallOrder[0] ?? 0;
    const subscribedAt = native.onLog.mock.invocationCallOrder[0] ?? 0;
    expect(levelAt).toBeLessThan(subscribedAt);
    expect(subscribedAt).toBeLessThan(
      native.startEvents.mock.invocationCallOrder[0] ?? 0
    );
  });

  it('passes each entry to the handler', () => {
    const handler: Handler = jest.fn();
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Debug, handler);

    emit(entry);

    expect(handler).toHaveBeenCalledWith({
      level: SallaPushLogLevel.Warn,
      category: 'registration',
      code: 'register.retry',
      message: 'Registration failed (HTTP 503); retrying in 30 s.',
      metadata: { http_status: '503', attempt: '2' },
      timestamp: 1_800_000_000_123,
    });
    expect(Object.isFrozen(handler.mock.calls[0]?.[0])).toBe(true);
  });

  it('replaces the handler, and sends only the new level to native', () => {
    const first: Handler = jest.fn();
    const second: Handler = jest.fn();

    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, first);
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Verbose, second);
    emit(entry);

    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledTimes(1);
    expect(native.setLogHandlerLevel.mock.calls).toEqual([
      ['warn'],
      ['verbose'],
    ]);
    expect(native.onLog).toHaveBeenCalledTimes(1);
    expect(native.startEvents).toHaveBeenCalledTimes(1);
  });

  it('removes the handler with null: stops the native registration, then unsubscribes', () => {
    const handler: Handler = jest.fn();
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, handler);
    const subscription = native.onLog.mock.results[0]?.value as {
      remove: jest.Mock;
    };

    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, null);
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, null);
    emit(entry);

    expect(handler).not.toHaveBeenCalled();
    expect(native.stopEvents.mock.calls).toEqual([['log']]);
    expect(subscription.remove).toHaveBeenCalledTimes(1);
    expect(native.stopEvents.mock.invocationCallOrder[0]).toBeLessThan(
      subscription.remove.mock.invocationCallOrder[0] ?? 0
    );
  });

  it('starts again after a removal', () => {
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, () => {});
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, null);
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Error, () => {});

    expect(native.onLog).toHaveBeenCalledTimes(2);
    expect(native.startEvents.mock.calls).toEqual([['log'], ['log']]);
    expect(native.setLogHandlerLevel.mock.calls).toEqual([['warn'], ['error']]);
  });

  it('sends nothing for a removal without a handler', () => {
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, null);

    expect(native.setLogHandlerLevel).not.toHaveBeenCalled();
    expect(native.stopEvents).not.toHaveBeenCalled();
  });

  it('reports a handler that throws', () => {
    const failure = new Error('handler failed');
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Warn, () => {
      throw failure;
    });

    emit(entry);

    expect(error).toHaveBeenCalledWith(
      '[SallaPush] A SallaPush.Debug log handler threw:',
      failure
    );
  });

  it('drops a call with an unknown level or a handler that is neither a function nor null', () => {
    SallaPush.Debug.setLogHandler('trace' as SallaPushLogLevel, () => {});
    SallaPush.Debug.setLogHandler(
      SallaPushLogLevel.Warn,
      undefined as unknown as null
    );

    expect(native.setLogHandlerLevel).not.toHaveBeenCalled();
    expect(native.onLog).not.toHaveBeenCalled();
    expect(warn.mock.calls).toEqual([
      [
        "[SallaPush] SallaPush.Debug.setLogHandler ignored: level must be one of 'off', 'error', 'warn', " +
          "'info', 'debug', 'verbose'.",
      ],
      [
        '[SallaPush] SallaPush.Debug.setLogHandler ignored: handler must be a function or null.',
      ],
    ]);
  });
});

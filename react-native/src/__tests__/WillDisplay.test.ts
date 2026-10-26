import {
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

import NativeRNSallaPush, {
  type NotificationSpec,
  type WillDisplayEventSpec,
} from '../NativeRNSallaPush';
import {
  SallaPush,
  type SallaPushEventSubscription,
  type SallaPushWillDisplayEvent,
} from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
const subscriptions: SallaPushEventSubscription[] = [];
let error: jest.SpiedFunction<typeof console.error>;
let handler: ((payload: WillDisplayEventSpec) => void) | undefined;
let emitterSubscription: { remove: jest.Mock };
let subscribedAt: number;
let startedAt: number;

type Listener = jest.Mock<(event: SallaPushWillDisplayEvent) => void>;

// The hub subscribes to the emitter with its first listener ever, and keeps that subscription for the runtime.
beforeAll(() => {
  SallaPush.Notifications.addEventListener(
    'foregroundWillDisplay',
    () => {}
  ).remove();
  handler = native.onWillDisplay.mock.calls[0]?.[0];
  emitterSubscription = native.onWillDisplay.mock.results[0]?.value as {
    remove: jest.Mock;
  };
  subscribedAt = native.onWillDisplay.mock.invocationCallOrder[0] ?? 0;
  startedAt = native.startEvents.mock.invocationCallOrder[0] ?? 0;
});

beforeEach(() => {
  jest.clearAllMocks();
  error = jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  for (const subscription of subscriptions.splice(0)) {
    subscription.remove();
  }
  error.mockRestore();
});

function listen(listener: Listener = jest.fn()): Listener {
  subscriptions.push(
    SallaPush.Notifications.addEventListener('foregroundWillDisplay', listener)
  );
  return listener;
}

const notification: NotificationSpec = {
  notificationId: 'msg_5a11a90001',
  title: 'SallaPush test',
  body: 'A native SallaPush notification',
  additionalData: { type: 'product', id: '42' },
  rawPayload: { sp_v: '1', sp_id: 'msg_5a11a90001', type: 'product' },
  source: 'native',
  stringValues: { type: 'product', id: '42' },
  intValues: { id: 42 },
  boolValues: {},
  numberValues: { id: 42 },
};

/** Emits what native's will-display listener sends for a notification it holds under `handle`. */
function emit(handle: string): void {
  handler?.({ handle, notification });
}

describe("SallaPush.Notifications 'foregroundWillDisplay' listeners", () => {
  it('subscribe to the emitter before the native registration starts', () => {
    expect(handler).toBeDefined();
    expect(subscribedAt).toBeLessThan(startedAt);
  });

  it('start and stop the native registration, and keep the emitter subscription', () => {
    listen();
    listen();
    subscriptions.splice(0).forEach((subscription) => subscription.remove());
    listen();

    expect(native.startEvents.mock.calls).toEqual([
      ['willDisplay'],
      ['willDisplay'],
    ]);
    expect(native.stopEvents.mock.calls).toEqual([['willDisplay']]);
    expect(native.onWillDisplay).not.toHaveBeenCalled();
    expect(emitterSubscription.remove).not.toHaveBeenCalled();
  });

  it('get the notification native holds', () => {
    const listener = listen();

    emit('7d9c2a54');

    const event = listener.mock.calls[0]?.[0];
    expect(event?.notification).toMatchObject({
      notificationId: 'msg_5a11a90001',
      title: 'SallaPush test',
      additionalData: { type: 'product', id: '42' },
    });
    expect(event?.notification.getInt('id')).toBe(42);
  });

  it('show a notification no listener prevented, once the listeners returned', () => {
    const listener = listen();

    emit('7d9c2a54');

    expect(native.displayNotification.mock.calls).toEqual([['7d9c2a54']]);
    expect(listener.mock.invocationCallOrder[0]).toBeLessThan(
      native.displayNotification.mock.invocationCallOrder[0] ?? 0
    );
  });

  it('keep a notification hidden when one of them prevented it', () => {
    const seen: boolean[] = [];
    const record = (event: SallaPushWillDisplayEvent) => {
      seen.push(event.isPrevented);
    };
    listen(jest.fn(record));
    listen(
      jest.fn((event: SallaPushWillDisplayEvent) => event.preventDefault())
    );
    listen(jest.fn(record));

    emit('7d9c2a54');

    expect(seen).toEqual([false, true]);
    expect(native.displayNotification).not.toHaveBeenCalled();
  });

  it('still decide when a listener throws', () => {
    const failure = new Error('listener failed');
    listen(
      jest.fn(() => {
        throw failure;
      })
    );
    const second = listen();

    emit('7d9c2a54');

    expect(second).toHaveBeenCalledTimes(1);
    expect(native.displayNotification.mock.calls).toEqual([['7d9c2a54']]);
    expect(error).toHaveBeenCalledWith(
      "[SallaPush] A SallaPush.Notifications 'foregroundWillDisplay' listener threw:",
      failure
    );
  });

  it('keep a notification hidden when the listener that prevented it threw', () => {
    listen(
      jest.fn((event: SallaPushWillDisplayEvent) => {
        event.preventDefault();
        throw new Error('listener failed');
      })
    );

    emit('7d9c2a54');

    expect(native.displayNotification).not.toHaveBeenCalled();
  });

  it('show a notification a listener prevented and displayed at once, once', () => {
    listen(
      jest.fn((event: SallaPushWillDisplayEvent) => {
        event.preventDefault();
        event.notification.display();
      })
    );

    emit('7d9c2a54');

    expect(native.displayNotification.mock.calls).toEqual([['7d9c2a54']]);
  });

  it('keep a notification hidden when a later one prevents it after an earlier one called display() without preventing', () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    listen(
      jest.fn((event: SallaPushWillDisplayEvent) =>
        event.notification.display()
      )
    );
    listen(
      jest.fn((event: SallaPushWillDisplayEvent) => event.preventDefault())
    );

    emit('7d9c2a54');

    expect(native.displayNotification).not.toHaveBeenCalled();
    warn.mockRestore();
  });

  it('show a prevented notification when the app calls display() later', () => {
    const held: SallaPushWillDisplayEvent[] = [];
    listen(
      jest.fn((event: SallaPushWillDisplayEvent) => {
        event.preventDefault();
        held.push(event);
      })
    );

    emit('7d9c2a54');
    expect(native.displayNotification).not.toHaveBeenCalled();
    held[0]?.notification.display();

    expect(native.displayNotification.mock.calls).toEqual([['7d9c2a54']]);
  });

  it('ignore a preventDefault() made after they returned', () => {
    const held: SallaPushWillDisplayEvent[] = [];
    listen(jest.fn((event: SallaPushWillDisplayEvent) => held.push(event)));

    emit('7d9c2a54');
    held[0]?.preventDefault();

    expect(native.displayNotification.mock.calls).toEqual([['7d9c2a54']]);
  });
});

describe('a will-display event without a listener', () => {
  it('is shown: native held it, and the last listener was removed while it was on its way', () => {
    SallaPush.Notifications.addEventListener(
      'foregroundWillDisplay',
      () => {}
    ).remove();

    emit('5b0e9f13');

    expect(native.displayNotification.mock.calls).toEqual([['5b0e9f13']]);
  });
});

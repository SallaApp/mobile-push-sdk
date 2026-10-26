import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

import NativeRNSallaPush, {
  type ClickEventSpec,
  type NotificationSpec,
} from '../NativeRNSallaPush';
import {
  SallaPush,
  type SallaPushClickEvent,
  type SallaPushEventSubscription,
} from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
const subscriptions: SallaPushEventSubscription[] = [];
let warn: jest.SpiedFunction<typeof console.warn>;
let error: jest.SpiedFunction<typeof console.error>;

beforeEach(() => {
  jest.clearAllMocks();
  warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  error = jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  for (const subscription of subscriptions.splice(0)) {
    subscription.remove();
  }
  warn.mockRestore();
  error.mockRestore();
});

function onClick(
  listener: (event: SallaPushClickEvent) => void
): SallaPushEventSubscription {
  const subscription = SallaPush.Notifications.addEventListener(
    'click',
    listener
  );
  subscriptions.push(subscription);
  return subscription;
}

function click(notificationId: string): ClickEventSpec {
  const notification: NotificationSpec = {
    notificationId,
    additionalData: {},
    rawPayload: {},
    source: 'native',
    stringValues: {},
    intValues: {},
    boolValues: {},
    numberValues: {},
  };
  return { notification };
}

/** Emits a tap through the handler the click hub subscribed to the emitter with. */
function emitClick(notificationId: string): void {
  native.onClick.mock.calls.at(-1)?.[0](click(notificationId));
}

function clickSubscription() {
  return native.onClick.mock.results.at(-1)?.value as { remove: jest.Mock };
}

/** Each event kind: how JavaScript adds and removes a listener, and the emitter and native registration behind it. */
const kinds = [
  {
    event: "SallaPush.Notifications 'click'",
    kind: 'click',
    emitter: () => native.onClick,
    add: (listener: () => void) =>
      SallaPush.Notifications.addEventListener('click', listener),
  },
  {
    event: "SallaPush.Notifications 'permissionChange'",
    kind: 'permission',
    emitter: () => native.onPermissionChange,
    add: (listener: () => void) =>
      SallaPush.Notifications.addEventListener('permissionChange', listener),
  },
  {
    event: "SallaPush.User 'change'",
    kind: 'user',
    emitter: () => native.onUserChange,
    add: (listener: () => void) =>
      SallaPush.User.addEventListener('change', listener),
  },
  {
    event: "SallaPush.User 'loginFailure'",
    kind: 'loginFailure',
    emitter: () => native.onLoginFailure,
    add: (listener: () => void) =>
      SallaPush.User.addEventListener('loginFailure', listener),
  },
];

describe.each(kinds)('$event listeners', ({ kind, emitter, add }) => {
  it('subscribe to the emitter before they start the native registration', () => {
    subscriptions.push(add(() => {}));

    expect(emitter()).toHaveBeenCalledTimes(1);
    expect(native.startEvents.mock.calls).toEqual([[kind]]);
    expect(emitter().mock.invocationCallOrder[0]).toBeLessThan(
      native.startEvents.mock.invocationCallOrder[0] ?? 0
    );
  });

  it('share one native registration, stopped and unsubscribed after the last removal', () => {
    const first = add(() => {});
    const second = add(() => {});
    const subscription = emitter().mock.results[0]?.value as {
      remove: jest.Mock;
    };

    expect(emitter()).toHaveBeenCalledTimes(1);
    expect(native.startEvents).toHaveBeenCalledTimes(1);

    first.remove();
    expect(native.stopEvents).not.toHaveBeenCalled();
    expect(subscription.remove).not.toHaveBeenCalled();

    second.remove();
    expect(native.stopEvents.mock.calls).toEqual([[kind]]);
    expect(subscription.remove).toHaveBeenCalledTimes(1);
    expect(native.stopEvents.mock.invocationCallOrder[0]).toBeLessThan(
      subscription.remove.mock.invocationCallOrder[0] ?? 0
    );
  });

  it('start again after the last removal', () => {
    add(() => {}).remove();
    subscriptions.push(add(() => {}));

    expect(emitter()).toHaveBeenCalledTimes(2);
    expect(native.startEvents.mock.calls).toEqual([[kind], [kind]]);
  });
});

describe('event listeners', () => {
  it('register the same function once', () => {
    const listener = jest.fn<(event: SallaPushClickEvent) => void>();

    const first = onClick(listener);
    onClick(listener);
    emitClick('msg_1');

    expect(native.onClick).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledTimes(1);
    first.remove();
    expect(native.stopEvents).toHaveBeenCalledTimes(1);
  });

  it('are removed by remove() and by removeEventListener', () => {
    const first = jest.fn<(event: SallaPushClickEvent) => void>();
    const second = jest.fn<(event: SallaPushClickEvent) => void>();
    onClick(first).remove();
    onClick(second);

    emitClick('msg_1');
    SallaPush.Notifications.removeEventListener('click', second);
    emitClick('msg_2');

    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledTimes(1);
    expect(native.stopEvents.mock.calls).toEqual([['click'], ['click']]);
  });

  it('get events in native order, in the order they were added', () => {
    const received: string[] = [];
    onClick((event) =>
      received.push(`first ${event.notification.notificationId}`)
    );
    onClick((event) =>
      received.push(`second ${event.notification.notificationId}`)
    );

    emitClick('msg_1');
    emitClick('msg_2');

    expect(received).toEqual([
      'first msg_1',
      'second msg_1',
      'first msg_2',
      'second msg_2',
    ]);
  });

  it('removed during a dispatch still get that event', () => {
    const second = jest.fn<(event: SallaPushClickEvent) => void>();
    onClick(() => SallaPush.Notifications.removeEventListener('click', second));
    onClick(second);

    emitClick('msg_1');
    emitClick('msg_2');

    expect(second).toHaveBeenCalledTimes(1);
  });

  it('that throw are reported, and the others still run', () => {
    const failure = new Error('listener failed');
    const second = jest.fn<(event: SallaPushClickEvent) => void>();
    onClick(() => {
      throw failure;
    });
    onClick(second);

    emitClick('msg_1');

    expect(second).toHaveBeenCalledTimes(1);
    expect(error).toHaveBeenCalledWith(
      "[SallaPush] A SallaPush.Notifications 'click' listener threw:",
      failure
    );
  });

  it('get nothing once removed, even an event native emitted before the removal', () => {
    const listener = jest.fn<(event: SallaPushClickEvent) => void>();
    const subscription = onClick(listener);
    const handler = native.onClick.mock.calls[0]?.[0];

    subscription.remove();
    handler?.(click('msg_1'));

    expect(listener).not.toHaveBeenCalled();
    expect(clickSubscription().remove).toHaveBeenCalledTimes(1);
  });
});

describe('addEventListener and removeEventListener validation', () => {
  it('drops an unknown event, with one warning and an inert subscription', () => {
    const subscription = SallaPush.Notifications.addEventListener(
      'opened' as 'click',
      () => {}
    );
    SallaPush.Notifications.addEventListener('Click' as 'click', () => {});
    subscription.remove();

    expect(native.onClick).not.toHaveBeenCalled();
    expect(native.startEvents).not.toHaveBeenCalled();
    expect(native.stopEvents).not.toHaveBeenCalled();
    expect(warn.mock.calls).toEqual([
      [
        "[SallaPush] SallaPush.Notifications.addEventListener ignored: event must be one of 'click', " +
          "'foregroundWillDisplay', 'permissionChange'.",
      ],
    ]);
  });

  it('drops a listener that is not a function', () => {
    SallaPush.User.addEventListener(
      'change',
      'onChange' as unknown as () => void
    );

    expect(native.onUserChange).not.toHaveBeenCalled();
    expect(native.startEvents).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.User.addEventListener ignored: listener must be a function.'
    );
  });

  it('drops a removal with an unknown event or a listener that is not a function', () => {
    const listener = jest.fn<(event: SallaPushClickEvent) => void>();
    onClick(listener);

    SallaPush.Notifications.removeEventListener('opened' as 'click', listener);
    SallaPush.User.removeEventListener(
      'loginFailure',
      null as unknown as () => void
    );
    emitClick('msg_1');

    expect(listener).toHaveBeenCalledTimes(1);
    expect(native.stopEvents).not.toHaveBeenCalled();
    expect(warn.mock.calls).toEqual([
      [
        "[SallaPush] SallaPush.Notifications.removeEventListener ignored: event must be one of 'click', " +
          "'foregroundWillDisplay', 'permissionChange'.",
      ],
      [
        '[SallaPush] SallaPush.User.removeEventListener ignored: listener must be a function.',
      ],
    ]);
  });

  it('ignores the removal of a listener that was never added', () => {
    SallaPush.User.removeEventListener('change', () => {});
    SallaPush.User.pushSubscription.removeEventListener('change', () => {});

    expect(native.stopEvents).not.toHaveBeenCalled();
    expect(native.removePushSubscriptionListener).not.toHaveBeenCalled();
    expect(warn).not.toHaveBeenCalled();
  });
});

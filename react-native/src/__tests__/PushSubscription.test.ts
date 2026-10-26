import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

import NativeRNSallaPush, {
  type SubscriptionStateSpec,
} from '../NativeRNSallaPush';
import {
  SallaPush,
  type SallaPushEventSubscription,
  type SallaPushSubscriptionChangedState,
} from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
const subscription = SallaPush.User.pushSubscription;
const subscriptions: SallaPushEventSubscription[] = [];
let error: jest.SpiedFunction<typeof console.error>;

beforeEach(() => {
  jest.clearAllMocks();
  error = jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  for (const added of subscriptions.splice(0)) {
    added.remove();
  }
  error.mockRestore();
});

type Listener = jest.Mock<(state: SallaPushSubscriptionChangedState) => void>;

function listen(listener: Listener = jest.fn()): Listener {
  subscriptions.push(subscription.addEventListener('change', listener));
  return listener;
}

/** The id the n-th listener added in this test registered natively. */
function idOf(index: number): number {
  return native.addPushSubscriptionListener.mock.calls[index]?.[0] ?? -1;
}

const unregistered: SubscriptionStateSpec = { optedIn: false };
const registered: SubscriptionStateSpec = {
  id: '3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40',
  token: 'a1b2c3',
  optedIn: true,
};

/** Emits what the native observer of `listenerId` reports. */
function emit(
  listenerId: number,
  previous: SubscriptionStateSpec,
  current: SubscriptionStateSpec
): void {
  native.onPushSubscriptionChange.mock.calls.at(-1)?.[0]({
    listenerId,
    previous,
    current,
  });
}

describe('SallaPush.User.pushSubscription', () => {
  it('is one namespace for the app', () => {
    expect(SallaPush.User.pushSubscription).toBe(subscription);
  });

  it('resolves the subscription native reads at call time', async () => {
    native.getPushSubscriptionId.mockResolvedValueOnce(
      '3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40'
    );
    native.getPushSubscriptionToken.mockResolvedValueOnce('a1b2c3');
    native.getPushSubscriptionOptedIn.mockResolvedValueOnce(true);

    await expect(subscription.getId()).resolves.toBe(
      '3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40'
    );
    await expect(subscription.getToken()).resolves.toBe('a1b2c3');
    await expect(subscription.getOptedIn()).resolves.toBe(true);
  });

  it('resolves an unregistered device as native reads it', async () => {
    await expect(subscription.getId()).resolves.toBeNull();
    await expect(subscription.getToken()).resolves.toBeNull();
    await expect(subscription.getOptedIn()).resolves.toBe(false);
  });

  it('passes optIn and optOut', () => {
    subscription.optIn();
    subscription.optOut();

    expect(native.optIn).toHaveBeenCalledTimes(1);
    expect(native.optOut).toHaveBeenCalledTimes(1);
    expect(native.optIn.mock.invocationCallOrder[0]).toBeLessThan(
      native.optOut.mock.invocationCallOrder[0] ?? 0
    );
  });
});

describe('SallaPush.User.pushSubscription change listeners', () => {
  it('subscribe to the emitter once, before each registers its own native observer', () => {
    listen();
    listen();

    expect(native.onPushSubscriptionChange).toHaveBeenCalledTimes(1);
    expect(native.addPushSubscriptionListener).toHaveBeenCalledTimes(2);
    expect(idOf(1)).toBe(idOf(0) + 1);
    expect(
      native.onPushSubscriptionChange.mock.invocationCallOrder[0]
    ).toBeLessThan(
      native.addPushSubscriptionListener.mock.invocationCallOrder[0] ?? 0
    );
    expect(native.startEvents).not.toHaveBeenCalled();
  });

  it('get only the events their own native observer reports', () => {
    const first = listen();
    const second = listen();

    emit(idOf(1), unregistered, registered);

    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledWith({
      previous: { id: null, token: null, optedIn: false },
      current: {
        id: '3f1c5a52-6a7e-4d1e-9a53-0c7b9e1d2f40',
        token: 'a1b2c3',
        optedIn: true,
      },
    });
  });

  it('each get their own replay: a listener added later gets one, the earlier one none', () => {
    const first = listen();
    emit(idOf(0), registered, registered);
    const second = listen();
    emit(idOf(1), registered, registered);

    expect(first).toHaveBeenCalledTimes(1);
    expect(second).toHaveBeenCalledTimes(1);
    expect(second.mock.calls[0]?.[0].previous).toEqual(
      second.mock.calls[0]?.[0].current
    );
  });

  it('register the same function once', () => {
    const listener = listen();
    listen(listener);

    emit(idOf(0), unregistered, registered);

    expect(native.addPushSubscriptionListener).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledTimes(1);
  });

  it('remove only their own native observer; the last removal unsubscribes', () => {
    const first = subscription.addEventListener('change', jest.fn());
    const second =
      jest.fn<(state: SallaPushSubscriptionChangedState) => void>();
    subscription.addEventListener('change', second);
    const emitterSubscription = native.onPushSubscriptionChange.mock.results[0]
      ?.value as { remove: jest.Mock };

    first.remove();
    expect(native.removePushSubscriptionListener.mock.calls).toEqual([
      [idOf(0)],
    ]);
    expect(emitterSubscription.remove).not.toHaveBeenCalled();

    subscription.removeEventListener('change', second);
    expect(native.removePushSubscriptionListener.mock.calls).toEqual([
      [idOf(0)],
      [idOf(1)],
    ]);
    expect(emitterSubscription.remove).toHaveBeenCalledTimes(1);
  });

  it('drop an event for a listener already removed', () => {
    const removed =
      jest.fn<(state: SallaPushSubscriptionChangedState) => void>();
    const kept = listen();
    subscription.addEventListener('change', removed).remove();

    emit(idOf(1), unregistered, registered);

    expect(removed).not.toHaveBeenCalled();
    expect(kept).not.toHaveBeenCalled();
  });

  it('start again after the last removal, with new ids', () => {
    subscription.addEventListener('change', jest.fn()).remove();
    listen();

    expect(native.onPushSubscriptionChange).toHaveBeenCalledTimes(2);
    expect(idOf(1)).toBe(idOf(0) + 1);
  });

  it('report a listener that throws', () => {
    const failure = new Error('listener failed');
    listen(
      jest.fn(() => {
        throw failure;
      })
    );

    emit(idOf(0), unregistered, registered);

    expect(error).toHaveBeenCalledWith(
      "[SallaPush] A SallaPush.User.pushSubscription 'change' listener threw:",
      failure
    );
  });
});

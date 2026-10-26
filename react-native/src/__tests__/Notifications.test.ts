import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

import NativeRNSallaPush from '../NativeRNSallaPush';
import {
  SallaPush,
  SallaPushIOSPermissionStatus,
  SallaPushPayloadSource,
  type SallaPushClickEvent,
  type SallaPushEventSubscription,
} from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
const notifications = SallaPush.Notifications;
const subscriptions: SallaPushEventSubscription[] = [];
let warn: jest.SpiedFunction<typeof console.warn>;

beforeEach(() => {
  jest.clearAllMocks();
  warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  for (const subscription of subscriptions.splice(0)) {
    subscription.remove();
  }
  warn.mockRestore();
});

describe('SallaPush.Notifications permission', () => {
  it('resolves the permission native reads at call time', async () => {
    native.getPermission.mockResolvedValueOnce(true);
    native.canRequestPermission.mockResolvedValueOnce(true);

    await expect(notifications.getPermission()).resolves.toBe(true);
    await expect(notifications.canRequestPermission()).resolves.toBe(true);
  });

  it.each(Object.values(SallaPushIOSPermissionStatus))(
    'resolves the iOS status %s',
    async (status) => {
      native.getPermissionStatus.mockResolvedValueOnce(status);

      await expect(notifications.getPermissionStatus()).resolves.toBe(status);
    }
  );

  it('resolves a null status on Android', async () => {
    await expect(notifications.getPermissionStatus()).resolves.toBeNull();
  });

  it('requests the permission without the settings fallback by default', async () => {
    native.requestPermission.mockResolvedValueOnce(true);

    await expect(notifications.requestPermission()).resolves.toBe(true);
    expect(native.requestPermission).toHaveBeenCalledWith(false);
  });

  it('requests the permission with the settings fallback', async () => {
    await expect(notifications.requestPermission(true)).resolves.toBe(false);
    expect(native.requestPermission).toHaveBeenCalledWith(true);
  });

  it('resolves false for a request whose fallback is not a boolean', async () => {
    await expect(
      notifications.requestPermission('yes' as unknown as boolean)
    ).resolves.toBe(false);

    expect(native.requestPermission).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.Notifications.requestPermission ignored: fallbackToSettings must be a boolean.'
    );
  });

  it('resolves the provisional authorization native gives', async () => {
    native.registerForProvisionalAuthorization.mockResolvedValueOnce(true);

    await expect(
      notifications.registerForProvisionalAuthorization()
    ).resolves.toBe(true);
  });

  it('passes refreshPermission, registerForRemoteNotifications and clearAll', () => {
    notifications.refreshPermission();
    notifications.registerForRemoteNotifications();
    notifications.clearAll();

    expect(native.refreshPermission).toHaveBeenCalledTimes(1);
    expect(native.registerForRemoteNotifications).toHaveBeenCalledTimes(1);
    expect(native.clearAll).toHaveBeenCalledTimes(1);
  });
});

describe('SallaPush.Notifications.forwardApnsToken', () => {
  it('passes the hexadecimal text unchanged, for native to decode', () => {
    notifications.forwardApnsToken('A1B2C3');

    expect(native.forwardApnsToken).toHaveBeenCalledWith('A1B2C3');
  });

  it('drops a token that is not a string', () => {
    notifications.forwardApnsToken(null as unknown as string);

    expect(native.forwardApnsToken).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.Notifications.forwardApnsToken ignored: apnsToken must be a string.'
    );
  });
});

describe('SallaPush.Notifications.removeNotification', () => {
  it('passes an Android notification id', () => {
    notifications.removeNotification(-2147483648);
    notifications.removeNotification(42);

    expect(native.removeNotification.mock.calls).toEqual([[-2147483648], [42]]);
  });

  it('drops ids that are not 32-bit integers, with one warning', () => {
    for (const id of ['42', 1.5, Number.NaN, 2147483648]) {
      notifications.removeNotification(id as unknown as number);
    }

    expect(native.removeNotification).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.Notifications.removeNotification ignored: androidNotificationId must be a ' +
        '32-bit integer.'
    );
  });
});

describe('SallaPush.Notifications payload helpers', () => {
  it('passes the payload unchanged and resolves native recognition', async () => {
    const payload = {
      custom: { i: 'os-id', a: { push_ref: 'msg_1a2b' } },
      alert: 'Hi',
    };
    native.isSallaPushNotification.mockResolvedValueOnce(true);

    await expect(notifications.isSallaPushNotification(payload)).resolves.toBe(
      true
    );
    expect(native.isSallaPushNotification.mock.calls[0]?.[0]).toBe(payload);
  });

  it('resolves false for a payload that is not a plain object', async () => {
    await expect(
      notifications.isSallaPushNotification(
        'sp_v' as unknown as Record<string, unknown>
      )
    ).resolves.toBe(false);

    expect(native.isSallaPushNotification).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.Notifications.isSallaPushNotification ignored: payload must be a plain object.'
    );
  });

  it('passes trackOpened data and resolves the answer', async () => {
    const additionalData = { push_ref: 'msg_1a2b', screen: 'offers' };
    native.trackOpened.mockResolvedValueOnce(true);

    await expect(notifications.trackOpened(additionalData)).resolves.toBe(true);
    expect(native.trackOpened.mock.calls[0]?.[0]).toBe(additionalData);
  });

  it('passes trackOpened without data', async () => {
    await expect(notifications.trackOpened(null)).resolves.toBe(false);

    expect(native.trackOpened).toHaveBeenCalledWith(null);
  });

  it('resolves false for trackOpened data that is neither an object nor null', async () => {
    await expect(
      notifications.trackOpened(undefined as unknown as null)
    ).resolves.toBe(false);

    expect(native.trackOpened).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.Notifications.trackOpened ignored: additionalData must be a plain object or null.'
    );
  });
});

describe('SallaPush.Notifications events', () => {
  it("passes taps to 'click' listeners, with native's typed values", () => {
    const listener = jest.fn<(event: SallaPushClickEvent) => void>();
    subscriptions.push(notifications.addEventListener('click', listener));

    native.onClick.mock.calls[0]?.[0]({
      notification: {
        notificationId: 'msg_5a11a90001',
        title: 'SallaPush test',
        launchUrl: 'https://example.com/products/42',
        additionalData: { type: 'product', id: '42' },
        rawPayload: { sp_v: '1', sp_id: 'msg_5a11a90001', id: '42' },
        source: 'native',
        stringValues: { type: 'product', id: '42' },
        intValues: { id: 42 },
        boolValues: {},
        numberValues: { id: 42 },
      },
      url: 'https://example.com/products/42',
    });

    expect(native.startEvents).toHaveBeenCalledWith('click');
    const event = listener.mock.calls[0]?.[0];
    expect(event?.result).toEqual({
      actionId: null,
      url: 'https://example.com/products/42',
    });
    expect(event?.notification).toMatchObject({
      notificationId: 'msg_5a11a90001',
      title: 'SallaPush test',
      source: SallaPushPayloadSource.Native,
      additionalData: { type: 'product', id: '42' },
    });
    expect(event?.notification.getString('type')).toBe('product');
    expect(event?.notification.getInt('id')).toBe(42);
  });

  it("passes permission changes to 'permissionChange' listeners", () => {
    const listener = jest.fn<(permission: boolean) => void>();
    subscriptions.push(
      notifications.addEventListener('permissionChange', listener)
    );
    const emit = native.onPermissionChange.mock.calls[0]?.[0];

    emit?.({ permission: true });
    emit?.({ permission: false });

    expect(native.startEvents).toHaveBeenCalledWith('permission');
    expect(listener.mock.calls).toEqual([[true], [false]]);
  });
});

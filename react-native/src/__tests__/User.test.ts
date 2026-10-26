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
  SallaPushLoginFailure,
  type SallaPushEventSubscription,
  type SallaPushUserChangedState,
} from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
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

describe('SallaPush.User getters', () => {
  it('resolve the customer native reads at call time', async () => {
    native.getExternalId.mockResolvedValueOnce('customer-7');
    native.isLoggedIn.mockResolvedValueOnce(true);

    await expect(SallaPush.User.getExternalId()).resolves.toBe('customer-7');
    await expect(SallaPush.User.isLoggedIn()).resolves.toBe(true);
  });

  it('resolve a guest as native reads it', async () => {
    await expect(SallaPush.User.getExternalId()).resolves.toBeNull();
    await expect(SallaPush.User.isLoggedIn()).resolves.toBe(false);
  });

  it('resolve the tags native holds', async () => {
    native.getTags.mockResolvedValueOnce({ level: 'gold', city: 'riyadh' });

    await expect(SallaPush.User.getTags()).resolves.toEqual({
      level: 'gold',
      city: 'riyadh',
    });
  });
});

describe('SallaPush.User tags', () => {
  it('passes addTag and removeTag unchanged, for native to normalise', () => {
    SallaPush.User.addTag(' Level ', '');
    SallaPush.User.removeTag(' City ');

    expect(native.addTag).toHaveBeenCalledWith(' Level ', '');
    expect(native.removeTag).toHaveBeenCalledWith(' City ');
  });

  it('passes the tags object unchanged, non-string values included', () => {
    const tags = { level: 'gold', visits: 3, vip: true };

    SallaPush.User.addTags(tags as unknown as Record<string, string>);

    expect(native.addTags).toHaveBeenCalledTimes(1);
    expect(native.addTags.mock.calls[0]?.[0]).toBe(tags);
    expect(warn).not.toHaveBeenCalled();
  });

  it('passes the keys array unchanged, non-string keys included', () => {
    const keys = ['level', 3];

    SallaPush.User.removeTags(keys as unknown as string[]);

    expect(native.removeTags.mock.calls[0]?.[0]).toBe(keys);
    expect(warn).not.toHaveBeenCalled();
  });

  it('drops an addTag with a boolean value', () => {
    SallaPush.User.addTag('vip', true as unknown as string);

    expect(native.addTag).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.User.addTag ignored: value must be a string.'
    );
  });

  it('drops an addTag without a string key', () => {
    SallaPush.User.addTag(undefined as unknown as string, 'gold');

    expect(native.addTag).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.User.addTag ignored: key must be a string.'
    );
  });

  it('drops every addTags whose tags are not a plain object, with one warning', () => {
    const notPlainObjects = [
      'level=gold',
      null,
      [['level', 'gold']],
      new Map([['level', 'gold']]),
    ];

    for (const tags of notPlainObjects) {
      SallaPush.User.addTags(tags as unknown as Record<string, string>);
    }

    expect(native.addTags).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.User.addTags ignored: tags must be a plain object.'
    );
  });

  it('drops a removeTag without a string key', () => {
    SallaPush.User.removeTag(5 as unknown as string);

    expect(native.removeTag).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.User.removeTag ignored: key must be a string.'
    );
  });

  it('drops a removeTags without an array', () => {
    SallaPush.User.removeTags('level' as unknown as string[]);

    expect(native.removeTags).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.User.removeTags ignored: keys must be an array.'
    );
  });
});

describe('SallaPush.User.setLanguage', () => {
  it('passes a language', () => {
    SallaPush.User.setLanguage('ar');

    expect(native.setLanguage).toHaveBeenCalledWith('ar');
  });

  it('passes null, which means the device language', () => {
    SallaPush.User.setLanguage(null);

    expect(native.setLanguage).toHaveBeenCalledWith(null);
  });

  it('drops a language that is neither a string nor null', () => {
    SallaPush.User.setLanguage(undefined as unknown as string);
    SallaPush.User.setLanguage(1 as unknown as string);

    expect(native.setLanguage).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.User.setLanguage ignored: language must be a string or null.'
    );
  });
});

describe('SallaPush.User events', () => {
  it("passes user changes to 'change' listeners", () => {
    const listener = jest.fn<(state: SallaPushUserChangedState) => void>();
    subscriptions.push(SallaPush.User.addEventListener('change', listener));

    native.onUserChange.mock.calls[0]?.[0]({
      previous: { isLoggedIn: false },
      current: { externalId: 'customer-7', isLoggedIn: true },
    });

    expect(native.startEvents).toHaveBeenCalledWith('user');
    expect(listener).toHaveBeenCalledWith({
      previous: { externalId: null, isLoggedIn: false },
      current: { externalId: 'customer-7', isLoggedIn: true },
    });
  });

  it("passes login failures to 'loginFailure' listeners", () => {
    const listener = jest.fn<(failure: SallaPushLoginFailure) => void>();
    subscriptions.push(
      SallaPush.User.addEventListener('loginFailure', listener)
    );
    const emit = native.onLoginFailure.mock.calls[0]?.[0];

    emit?.({ failure: 'tokenRejected' });
    emit?.({ failure: 'invalidRequest' });

    expect(native.startEvents).toHaveBeenCalledWith('loginFailure');
    expect(listener.mock.calls).toEqual([
      [SallaPushLoginFailure.TokenRejected],
      [SallaPushLoginFailure.InvalidRequest],
    ]);
  });
});

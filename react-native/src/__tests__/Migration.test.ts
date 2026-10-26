import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

import NativeRNSallaPush from '../NativeRNSallaPush';
import { SallaPush } from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
let warn: jest.SpiedFunction<typeof console.warn>;

beforeEach(() => {
  jest.clearAllMocks();
  warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  warn.mockRestore();
});

describe('SallaPush.Migration', () => {
  it.each([true, false])('passes setDisplayCompatPayloads(%s)', (display) => {
    SallaPush.Migration.setDisplayCompatPayloads(display);

    expect(native.setDisplayCompatPayloads).toHaveBeenCalledWith(display);
  });

  it('drops a setting that is not a boolean', () => {
    SallaPush.Migration.setDisplayCompatPayloads('false' as unknown as boolean);

    expect(native.setDisplayCompatPayloads).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.Migration.setDisplayCompatPayloads ignored: display must be a boolean.'
    );
  });
});

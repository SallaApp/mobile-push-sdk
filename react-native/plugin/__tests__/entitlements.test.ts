import { describe, expect, it } from '@jest/globals';
import type { InfoPlist } from 'expo/config-plugins';

import {
  setEntitlements,
  withSallaPushEntitlements,
} from '../src/ios/entitlements';
import { appConfig, runMod } from './mods';

const GROUPS = 'com.apple.security.application-groups';

describe('setEntitlements', () => {
  it('sets aps-environment to development by default', () => {
    expect(setEntitlements({}, {})).toEqual({
      'aps-environment': 'development',
    });
  });

  it('sets aps-environment to the mode when the app has none', () => {
    expect(
      setEntitlements({ 'aps-environment': '' }, { mode: 'production' })
    ).toEqual({ 'aps-environment': 'production' });
  });

  it('keeps the aps-environment the app already has', () => {
    expect(
      setEntitlements(
        { 'aps-environment': 'development' },
        { mode: 'production' }
      )
    ).toEqual({ 'aps-environment': 'development' });
  });

  it('adds the App Group once and keeps the others', () => {
    const once = setEntitlements(
      { 'aps-environment': 'production', [GROUPS]: ['group.other'] },
      { appGroup: 'group.sa.salla.example' }
    );
    const twice = setEntitlements(once, { appGroup: 'group.sa.salla.example' });

    expect(twice).toEqual({
      'aps-environment': 'production',
      [GROUPS]: ['group.other', 'group.sa.salla.example'],
    });
  });

  it('creates the App Group list when there is none', () => {
    expect(
      setEntitlements({}, { appGroup: 'group.sa.salla.example' })[GROUPS]
    ).toEqual(['group.sa.salla.example']);
  });

  it('adds no App Group list without an appGroup', () => {
    expect(setEntitlements({}, {})).not.toHaveProperty(GROUPS);
  });
});

describe('withSallaPushEntitlements', () => {
  it('edits the entitlements through the entitlements mod', async () => {
    const config = withSallaPushEntitlements(appConfig(), {
      mode: 'production',
      appGroup: 'group.sa.salla.example',
    });

    const { modResults } = await runMod<InfoPlist>(
      config,
      'ios',
      'entitlements',
      {}
    );

    expect(modResults).toEqual({
      'aps-environment': 'production',
      [GROUPS]: ['group.sa.salla.example'],
    });
  });
});

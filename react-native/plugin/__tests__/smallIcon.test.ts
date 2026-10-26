import { afterAll, describe, expect, it } from '@jest/globals';
import fs from 'fs';
import path from 'path';

import { iconResource, withSallaPushSmallIcon } from '../src/android/smallIcon';
import { appConfig, modsOf, runMod, tempProject } from './mods';

const COPY = path.join(
  'android',
  'app',
  'src',
  'main',
  'res',
  'drawable-xxxhdpi',
  'sallapush_small_icon.png'
);
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64'
);
const roots: string[] = [];

afterAll(() => {
  for (const root of roots) {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

function project(): string {
  const root = tempProject({ 'package.json': '{}' });
  fs.mkdirSync(path.join(root, 'assets'));
  fs.writeFileSync(path.join(root, 'assets', 'notification-icon.png'), PNG);
  roots.push(root);
  return root;
}

describe('iconResource', () => {
  it("is the copy for a file, and the app's drawable for a drawable", () => {
    expect(iconResource('./assets/notification-icon.png')).toBe(
      '@drawable/sallapush_small_icon'
    );
    expect(iconResource('@drawable/ic_notification')).toBe(
      '@drawable/ic_notification'
    );
  });
});

describe('withSallaPushSmallIcon', () => {
  it('copies the PNG into drawable-xxxhdpi', async () => {
    const root = project();

    await runMod(
      withSallaPushSmallIcon(appConfig(), {
        smallIcon: './assets/notification-icon.png',
      }),
      'android',
      'dangerous',
      undefined,
      root
    );

    expect(fs.readFileSync(path.join(root, COPY))).toEqual(PNG);
  });

  it('throws when the file is missing', async () => {
    await expect(
      runMod(
        withSallaPushSmallIcon(appConfig(), {
          smallIcon: './assets/missing.png',
        }),
        'android',
        'dangerous',
        undefined,
        project()
      )
    ).rejects.toThrow(
      '@salla.sa/mobile-push-react-native: android.smallIcon "./assets/missing.png" doesn\'t exist in the project.'
    );
  });

  it('copies nothing for a drawable, or without smallIcon', () => {
    expect(
      modsOf(
        withSallaPushSmallIcon(appConfig(), {
          smallIcon: '@drawable/ic_notification',
        }),
        'android'
      )
    ).toEqual({});
    expect(modsOf(withSallaPushSmallIcon(appConfig(), {}), 'android')).toEqual(
      {}
    );
  });
});

import { withDangerousMod, type ConfigPlugin } from 'expo/config-plugins';
import fs from 'fs';
import path from 'path';

import { PLUGIN_NAME } from '../constants';
import type { AndroidProps } from '../validate';

const DRAWABLE = 'sallapush_small_icon';

/** The icon's resource: the drawable the app names, or the copy of its PNG. */
export function iconResource(smallIcon: string): string {
  return smallIcon.startsWith('@') ? smallIcon : `@drawable/${DRAWABLE}`;
}

/** Copies the PNG that android.smallIcon names to res/drawable-xxxhdpi/sallapush_small_icon.png. */
export const withSallaPushSmallIcon: ConfigPlugin<AndroidProps> = (
  config,
  android
) => {
  const { smallIcon } = android;
  if (smallIcon === undefined || smallIcon.startsWith('@')) {
    return config;
  }
  return withDangerousMod(config, [
    'android',
    async (mod) => {
      const source = path.resolve(mod.modRequest.projectRoot, smallIcon);
      if (!fs.existsSync(source)) {
        throw new Error(
          `${PLUGIN_NAME}: android.smallIcon ${JSON.stringify(smallIcon)} doesn't exist in the project.`
        );
      }
      const target = path.join(
        mod.modRequest.platformProjectRoot,
        'app',
        'src',
        'main',
        'res',
        'drawable-xxxhdpi',
        `${DRAWABLE}.png`
      );
      await fs.promises.mkdir(path.dirname(target), { recursive: true });
      await fs.promises.copyFile(source, target);
      return mod;
    },
  ]);
};

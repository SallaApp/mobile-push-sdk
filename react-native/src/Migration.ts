import NativeRNSallaPush from './NativeRNSallaPush';
import { boolean, valid } from './internal/validate';
import type { SallaPushMigrationNamespace } from './types';

export const Migration: SallaPushMigrationNamespace = {
  setDisplayCompatPayloads(display) {
    if (
      valid('SallaPush.Migration.setDisplayCompatPayloads', {
        display: [display, boolean],
      })
    ) {
      NativeRNSallaPush.setDisplayCompatPayloads(display);
    }
  },
};

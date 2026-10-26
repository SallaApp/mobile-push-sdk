import type { ExpoConfig } from 'expo/config';
import type {
  ExportedConfig,
  ExportedConfigWithProps,
  Mod,
} from 'expo/config-plugins';
import fs from 'fs';
import os from 'os';
import path from 'path';

export function fixture(name: string): string {
  return fs.readFileSync(
    path.join(__dirname, '..', '__fixtures__', name),
    'utf8'
  );
}

/** An app config; tests also pass keys that newer Expo types no longer declare, such as newArchEnabled. */
export function appConfig(config: Record<string, unknown> = {}): ExpoConfig {
  return { name: 'HelloWorld', slug: 'hello-world', ...config } as ExpoConfig;
}

/** A project folder in the temp directory, with these files. */
export function tempProject(files: Record<string, string>): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sallapush-plugin-'));
  for (const [name, contents] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, name)), { recursive: true });
    fs.writeFileSync(path.join(root, name), contents);
  }
  return root;
}

/** The mods the plugins registered for `platform`, by name. */
export function modsOf(
  config: ExportedConfig,
  platform: 'ios' | 'android'
): Record<string, unknown> {
  return { ...config.mods?.[platform] };
}

/** Runs the `platform.mod` mod that the plugins registered on `config`, as prebuild does. */
export async function runMod<T>(
  config: ExportedConfig,
  platform: 'ios' | 'android',
  mod: string,
  modResults: T,
  projectRoot = '/app'
): Promise<ExportedConfigWithProps<T>> {
  const action = modsOf(config, platform)[mod] as Mod<T> | undefined;
  if (action === undefined) {
    throw new Error(`No ${platform}.${mod} mod was registered.`);
  }
  return action({
    ...config,
    modResults,
    modRawConfig: config,
    modRequest: {
      projectRoot,
      platformProjectRoot: path.join(projectRoot, platform),
      platform,
      modName: mod,
      introspect: false,
    },
  });
}

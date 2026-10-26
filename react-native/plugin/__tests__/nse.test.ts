import { afterAll, describe, expect, it } from '@jest/globals';
import { IOSConfig } from 'expo/config-plugins';
import fs from 'fs';
import path from 'path';

import withSallaPush from '../src';
import { withSallaPushEasExtension } from '../src/ios/easExtensions';
import {
  addNseTarget,
  nseFiles,
  withSallaPushNotificationServiceExtension,
} from '../src/ios/nse';
import { appConfig, fixture, modsOf, runMod, tempProject } from './mods';

const NSE = 'SallaPushNotificationService';
const INFO_PLIST = `${NSE}-Info.plist`;
const ENTITLEMENTS = `${NSE}.entitlements`;
const PBXPROJ = path.join('ios', 'HelloWorld.xcodeproj', 'project.pbxproj');
const roots: string[] = [];
const entry = {
  targetName: NSE,
  bundleIdentifier: `sa.salla.example.${NSE}`,
  entitlements: {
    'com.apple.security.application-groups': ['group.sa.salla.example'],
  },
};

type Project = ReturnType<typeof IOSConfig.XcodeUtils.getPbxproj>;

afterAll(() => {
  for (const root of roots) {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

/** A project with the Expo SDK 57 Xcode project. */
function project(): string {
  const root = tempProject({ [PBXPROJ]: fixture('sdk-57/project.pbxproj') });
  roots.push(root);
  return root;
}

function plistString(
  plist: string | undefined,
  key: string
): string | undefined {
  return new RegExp(`<key>${key}</key>\\s*<string>([^<]*)</string>`).exec(
    plist ?? ''
  )?.[1];
}

function nseTargets(xcode: Project) {
  return IOSConfig.Target.getNativeTargets(xcode).filter(
    ([, target]) => IOSConfig.XcodeUtils.unquote(target.name) === NSE
  );
}

function nseTarget(xcode: Project) {
  const [found] = nseTargets(xcode);
  if (found === undefined) {
    throw new Error('The project has no extension target.');
  }
  return found;
}

/** The build settings of the target's configurations, by name, without quotes. */
function settingsOf(
  xcode: Project,
  listId: string
): Record<string, Record<string, unknown>> {
  return Object.fromEntries(
    IOSConfig.XcodeUtils.getBuildConfigurationsForListId(xcode, listId).map(
      ([, configuration]) => [
        configuration.name,
        Object.fromEntries(
          Object.entries(configuration.buildSettings).map(([key, value]) => [
            key,
            typeof value === 'string'
              ? IOSConfig.XcodeUtils.unquote(value)
              : value,
          ])
        ),
      ]
    )
  );
}

describe('nseFiles', () => {
  it('copies the native extension source', () => {
    const source = nseFiles(appConfig(), {})['NotificationService.swift'];

    expect(source).toBe(
      fs.readFileSync(
        path.join(__dirname, '..', 'templates', 'NotificationService.swift'),
        'utf8'
      )
    );
    expect(source).toContain('import SallaPushExtension');
    expect(source).toContain(
      'if SallaPushServiceExtension.isSallaPushNotification(request) {'
    );
    expect(source).toContain(
      'sallaPushService?.didReceive(request, withContentHandler: contentHandler)'
    );
    expect(source).toContain(
      'sallaPushService?.serviceExtensionTimeWillExpire()'
    );
  });

  it('declares a notification service extension', () => {
    const plist = nseFiles(appConfig(), {})[INFO_PLIST];

    expect(plistString(plist, 'NSExtensionPointIdentifier')).toBe(
      'com.apple.usernotifications.service'
    );
    expect(plistString(plist, 'NSExtensionPrincipalClass')).toBe(
      '$(PRODUCT_MODULE_NAME).NotificationService'
    );
    expect(plistString(plist, 'CFBundleIdentifier')).toBe(
      '$(PRODUCT_BUNDLE_IDENTIFIER)'
    );
  });

  it("gives the extension the app's version and build number", () => {
    const plist = nseFiles(
      appConfig({ version: '2.3.0', ios: { buildNumber: '7' } }),
      {}
    )[INFO_PLIST];

    expect(plistString(plist, 'CFBundleShortVersionString')).toBe('2.3.0');
    expect(plistString(plist, 'CFBundleVersion')).toBe('7');
  });

  it('takes ios.version over version, as the app does', () => {
    const plist = nseFiles(
      appConfig({ version: '2.3.0', ios: { version: '2.4.0' } }),
      {}
    )[INFO_PLIST];

    expect(plistString(plist, 'CFBundleShortVersionString')).toBe('2.4.0');
  });

  it('defaults to version 1.0.0 and build 1', () => {
    const plist = nseFiles(appConfig(), {})[INFO_PLIST];

    expect(plistString(plist, 'CFBundleShortVersionString')).toBe('1.0.0');
    expect(plistString(plist, 'CFBundleVersion')).toBe('1');
  });

  it('writes the App Group to the Info.plist and the entitlements', () => {
    const files = nseFiles(appConfig(), { appGroup: 'group.sa.salla.example' });

    expect(plistString(files[INFO_PLIST], 'SallaPushAppGroup')).toBe(
      'group.sa.salla.example'
    );
    expect(files[INFO_PLIST]).toContain(
      '\t</dict>\n\t<key>SallaPushAppGroup</key>\n\t<string>group.sa.salla.example</string>\n</dict>\n'
    );
    expect(files[ENTITLEMENTS]).toBe(
      [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0">',
        '<dict>',
        '\t<key>com.apple.security.application-groups</key>',
        '\t<array>',
        '\t\t<string>group.sa.salla.example</string>',
        '\t</array>',
        '</dict>',
        '</plist>',
        '',
      ].join('\n')
    );
  });

  it('leaves the App Group out without one', () => {
    const files = nseFiles(appConfig(), {});

    expect(files[INFO_PLIST]).not.toContain('SallaPushAppGroup');
    expect(files[INFO_PLIST]).not.toContain('{{');
    expect(files[INFO_PLIST]).toContain('\t</dict>\n</dict>\n</plist>\n');
    expect(files[ENTITLEMENTS]).toContain('<dict>\n</dict>');
  });

  it('escapes the values for XML', () => {
    const files = nseFiles(appConfig({ version: '1.0 <beta> & "rc"' }), {
      appGroup: 'group.a&b',
    });

    expect(plistString(files[INFO_PLIST], 'CFBundleShortVersionString')).toBe(
      '1.0 &lt;beta&gt; &amp; &quot;rc&quot;'
    );
    expect(files[ENTITLEMENTS]).toContain('<string>group.a&amp;b</string>');
  });
});

describe('addNseTarget', () => {
  it('adds the extension target once, also across prebuilds', () => {
    const root = project();
    const first = IOSConfig.XcodeUtils.getPbxproj(root);
    addNseTarget(first, { bundleIdentifier: 'sa.salla.example' });
    addNseTarget(first, { bundleIdentifier: 'sa.salla.example' });
    fs.writeFileSync(path.join(root, PBXPROJ), first.writeSync());

    const second = IOSConfig.XcodeUtils.getPbxproj(root);
    addNseTarget(second, { bundleIdentifier: 'sa.salla.example' });

    expect(nseTargets(second)).toHaveLength(1);
    expect(second.writeSync()).toBe(
      fs.readFileSync(path.join(root, PBXPROJ), 'utf8')
    );
  });

  it('sets the build settings of every configuration', () => {
    const xcode = IOSConfig.XcodeUtils.getPbxproj(project());

    addNseTarget(xcode, { bundleIdentifier: 'sa.salla.example' });

    const settings = settingsOf(
      xcode,
      nseTarget(xcode)[1].buildConfigurationList
    );
    expect(Object.keys(settings).sort()).toEqual(['Debug', 'Release']);
    for (const configuration of Object.values(settings)) {
      expect(configuration).toMatchObject({
        INFOPLIST_FILE: path.posix.join(NSE, INFO_PLIST),
        PRODUCT_BUNDLE_IDENTIFIER: `sa.salla.example.${NSE}`,
        IPHONEOS_DEPLOYMENT_TARGET: '16.4',
        SWIFT_VERSION: '5.0',
        CODE_SIGN_ENTITLEMENTS: path.posix.join(NSE, ENTITLEMENTS),
        CODE_SIGN_STYLE: 'Automatic',
        PRODUCT_NAME: NSE,
      });
      expect(configuration).not.toHaveProperty('DEVELOPMENT_TEAM');
      expect(configuration).not.toHaveProperty('TARGETED_DEVICE_FAMILY');
    }
  });

  it("copies the app's device family and deployment target, and sets the team", () => {
    const xcode = IOSConfig.XcodeUtils.getPbxproj(project());
    const app = IOSConfig.Target.findFirstNativeTarget(xcode)[1];
    for (const [
      ,
      configuration,
    ] of IOSConfig.XcodeUtils.getBuildConfigurationsForListId(
      xcode,
      app.buildConfigurationList
    )) {
      configuration.buildSettings.TARGETED_DEVICE_FAMILY = '"1,2"';
      configuration.buildSettings.IPHONEOS_DEPLOYMENT_TARGET = '17.0';
    }

    addNseTarget(xcode, {
      bundleIdentifier: 'sa.salla.example',
      developmentTeam: 'ABCDE12345',
    });

    const [uuid, target] = nseTarget(xcode);
    for (const configuration of Object.values(
      settingsOf(xcode, target.buildConfigurationList)
    )) {
      expect(configuration).toMatchObject({
        TARGETED_DEVICE_FAMILY: '1,2',
        IPHONEOS_DEPLOYMENT_TARGET: '17.0',
        DEVELOPMENT_TEAM: 'ABCDE12345',
      });
    }
    expect(
      xcode.getFirstProject().firstProject.attributes.TargetAttributes[uuid]
    ).toEqual({ DevelopmentTeam: 'ABCDE12345' });
  });

  it('updates the settings of the target an earlier prebuild added', () => {
    const xcode = IOSConfig.XcodeUtils.getPbxproj(project());
    addNseTarget(xcode, { bundleIdentifier: 'sa.salla.old' });

    addNseTarget(xcode, {
      bundleIdentifier: 'sa.salla.example',
      developmentTeam: 'ABCDE12345',
    });

    expect(nseTargets(xcode)).toHaveLength(1);
    for (const configuration of Object.values(
      settingsOf(xcode, nseTarget(xcode)[1].buildConfigurationList)
    )) {
      expect(configuration).toMatchObject({
        PRODUCT_BUNDLE_IDENTIFIER: `sa.salla.example.${NSE}`,
        DEVELOPMENT_TEAM: 'ABCDE12345',
      });
    }
  });

  it('embeds the extension in the app, which depends on it', () => {
    const xcode = IOSConfig.XcodeUtils.getPbxproj(project());

    addNseTarget(xcode, { bundleIdentifier: 'sa.salla.example' });

    const objects = xcode.hash.project.objects as Record<
      string,
      Record<string, any>
    >;
    const [uuid, target] = nseTarget(xcode);
    const app = IOSConfig.Target.findFirstNativeTarget(xcode)[1];
    const embed = app.buildPhases
      .map(
        ({ value }: { value: string }) =>
          objects.PBXCopyFilesBuildPhase?.[value]
      )
      .filter(Boolean);
    expect(embed).toHaveLength(1);
    expect(embed[0]).toMatchObject({
      name: '"Embed Foundation Extensions"',
      dstSubfolderSpec: 13,
      dstPath: '""',
    });
    expect(
      embed[0].files.map(
        ({ value }: { value: string }) => objects.PBXBuildFile?.[value]?.fileRef
      )
    ).toEqual([target.productReference]);
    expect(
      app.dependencies.map(
        ({ value }: { value: string }) =>
          objects.PBXTargetDependency?.[value]?.target
      )
    ).toEqual([uuid]);
  });

  it('adds the folder group and compiles the source in the extension', () => {
    const xcode = IOSConfig.XcodeUtils.getPbxproj(project());

    addNseTarget(xcode, { bundleIdentifier: 'sa.salla.example' });

    const objects = xcode.hash.project.objects as Record<
      string,
      Record<string, any>
    >;
    const main =
      objects.PBXGroup?.[xcode.getFirstProject().firstProject.mainGroup];
    const group = main.children
      .map(({ value }: { value: string }) => objects.PBXGroup?.[value])
      .find((child: { name?: string }) => child?.name === NSE);
    expect(group).toMatchObject({ name: NSE, path: NSE });
    expect(
      group.children.map(({ comment }: { comment: string }) => comment)
    ).toEqual(['NotificationService.swift', INFO_PLIST, ENTITLEMENTS]);

    const phases = Object.fromEntries(
      nseTarget(xcode)[1].buildPhases.map(
        ({ value, comment }: { value: string; comment: string }) => [
          comment,
          (
            objects.PBXSourcesBuildPhase?.[value] ??
            objects.PBXResourcesBuildPhase?.[value] ??
            objects.PBXFrameworksBuildPhase?.[value]
          ).files.map(
            ({ value: file }: { value: string }) =>
              objects.PBXFileReference?.[objects.PBXBuildFile?.[file]?.fileRef]
                ?.path
          ),
        ]
      )
    );
    expect(phases).toEqual({
      Sources: ['"NotificationService.swift"'],
      Resources: [],
      Frameworks: [],
    });
  });

  it('writes no undefined value and no unused build file', () => {
    const xcode = IOSConfig.XcodeUtils.getPbxproj(project());

    addNseTarget(xcode, { bundleIdentifier: 'sa.salla.example' });

    const written = xcode.writeSync();
    expect(written).not.toContain('undefined');
    expect(written).not.toContain(`${INFO_PLIST} in `);
    expect(written).not.toContain(`${ENTITLEMENTS} in `);
    expect(written).toContain('lastKnownFileType = text.plist.entitlements;');
  });
});

describe('withSallaPushNotificationServiceExtension', () => {
  // Plugins add their mods to the config they get, so each run starts from a new one.
  const config = () =>
    appConfig({
      version: '2.3.0',
      ios: { bundleIdentifier: 'sa.salla.example', appleTeamId: 'TEAM000001' },
    });

  it('writes the extension files into ios/SallaPushNotificationService on every prebuild', async () => {
    const root = project();
    fs.mkdirSync(path.join(root, 'ios', NSE));
    fs.writeFileSync(path.join(root, 'ios', NSE, INFO_PLIST), 'stale');
    const ios = { appGroup: 'group.sa.salla.example' };

    await runMod(
      withSallaPushNotificationServiceExtension(config(), ios),
      'ios',
      'dangerous',
      undefined,
      root
    );

    for (const [name, contents] of Object.entries(nseFiles(config(), ios))) {
      expect(fs.readFileSync(path.join(root, 'ios', NSE, name), 'utf8')).toBe(
        contents
      );
    }
  });

  it('adds the target through the xcodeproj mod, with the team of the app or developmentTeam', async () => {
    const root = project();

    const fromApp = await runMod(
      withSallaPushNotificationServiceExtension(config(), {}),
      'ios',
      'xcodeproj',
      IOSConfig.XcodeUtils.getPbxproj(root),
      root
    );
    const fromProp = await runMod(
      withSallaPushNotificationServiceExtension(config(), {
        developmentTeam: 'TEAM000002',
      }),
      'ios',
      'xcodeproj',
      IOSConfig.XcodeUtils.getPbxproj(root),
      root
    );

    for (const [{ modResults }, team] of [
      [fromApp, 'TEAM000001'],
      [fromProp, 'TEAM000002'],
    ] as const) {
      for (const configuration of Object.values(
        settingsOf(modResults, nseTarget(modResults)[1].buildConfigurationList)
      )) {
        expect(configuration.DEVELOPMENT_TEAM).toBe(team);
      }
    }
  });

  it('needs ios.bundleIdentifier', async () => {
    const root = project();

    await expect(
      runMod(
        withSallaPushNotificationServiceExtension(appConfig(), {}),
        'ios',
        'xcodeproj',
        IOSConfig.XcodeUtils.getPbxproj(root),
        root
      )
    ).rejects.toThrow(
      '@salla.sa/mobile-push-react-native: the Notification Service Extension needs ios.bundleIdentifier in the app config.'
    );
  });
});

describe('withSallaPushEasExtension', () => {
  const widget = {
    targetName: 'Widget',
    bundleIdentifier: 'sa.salla.example.Widget',
    entitlements: {},
  };

  it('lists the extension for EAS Build once and keeps the other entries', () => {
    const config = appConfig({
      ios: { bundleIdentifier: 'sa.salla.example' },
      extra: {
        router: {},
        eas: {
          projectId: 'project',
          build: { experimental: { ios: { appExtensions: [widget] } } },
        },
      },
    });

    const once = withSallaPushEasExtension(config, {
      appGroup: 'group.sa.salla.example',
    });
    const twice = withSallaPushEasExtension(once, {
      appGroup: 'group.sa.salla.example',
    });

    expect(twice.extra).toEqual({
      router: {},
      eas: {
        projectId: 'project',
        build: { experimental: { ios: { appExtensions: [widget, entry] } } },
      },
    });
  });

  it('gives the extension no entitlements without an App Group', () => {
    const config = withSallaPushEasExtension(
      appConfig({ ios: { bundleIdentifier: 'sa.salla.example' } }),
      {}
    );

    expect(config.extra?.eas.build.experimental.ios.appExtensions).toEqual([
      { ...entry, entitlements: {} },
    ]);
  });

  it('lists nothing without ios.bundleIdentifier', () => {
    const config = appConfig();

    expect(withSallaPushEasExtension(config, {})).toBe(config);
  });
});

describe('the plugin', () => {
  const config = () =>
    appConfig({ ios: { bundleIdentifier: 'sa.salla.example' } });

  it('adds the extension by default', () => {
    const result = withSallaPush(config(), { ios: { appId: 'st_42_ios' } });

    expect(Object.keys(modsOf(result, 'ios')).sort()).toEqual([
      'appDelegate',
      'dangerous',
      'entitlements',
      'infoPlist',
      'xcodeproj',
    ]);
    expect(result.extra?.eas.build.experimental.ios.appExtensions).toEqual([
      { ...entry, entitlements: {} },
    ]);
  });

  it('adds none of it with notificationServiceExtension: false', () => {
    const result = withSallaPush(config(), {
      ios: { notificationServiceExtension: false },
    });

    expect(modsOf(result, 'ios')).not.toHaveProperty('xcodeproj');
    expect(result.extra).toBeUndefined();
  });
});

import type { ExpoConfig } from 'expo/config';
import {
  IOSConfig,
  withDangerousMod,
  withXcodeProject,
  type ConfigPlugin,
} from 'expo/config-plugins';
import fs from 'fs';
import path from 'path';

import { NSE_TARGET, PLUGIN_NAME } from '../constants';
import { readTemplate, render } from '../templates';
import type { IOSProps } from '../validate';

const SOURCE = 'NotificationService.swift';
const INFO_PLIST = `${NSE_TARGET}-Info.plist`;
const ENTITLEMENTS = `${NSE_TARGET}.entitlements`;
const EMBED_PHASE = 'Embed Foundation Extensions';

type BuildSettings = Record<string, unknown>;

/** The part of the `xcode` package's project that the plugin uses; expo/config-plugins types it loosely. */
interface XcodeProject {
  hash: { project: { objects: Record<string, Record<string, any>> } };
  getFirstProject(): {
    firstProject: { mainGroup: string; buildConfigurationList: string };
  };
  getFirstTarget(): {
    uuid: string;
    firstTarget: { buildConfigurationList: string };
  };
  addPbxGroup(
    files: string[],
    name: string,
    path: string
  ): {
    uuid: string;
    pbxGroup: { children: { value: string; comment?: string }[] };
  };
  addToPbxGroup(child: string, group: string): void;
  addTarget(
    name: string,
    type: string,
    subfolder: string,
    bundleId: string
  ): { uuid: string; pbxNativeTarget: { productReference: string } };
  addBuildPhase(
    files: string[],
    type: string,
    comment: string,
    target: string
  ): unknown;
  addTargetAttribute(
    attribute: string,
    value: string,
    target: { uuid: string }
  ): void;
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** The extension's files, from plugin/templates, with the app's versions and App Group. */
export function nseFiles(
  config: ExpoConfig,
  ios: IOSProps
): Record<string, string> {
  const group =
    ios.appGroup === undefined ? undefined : escapeXml(ios.appGroup);
  return {
    [SOURCE]: readTemplate(SOURCE),
    [INFO_PLIST]: render(readTemplate(INFO_PLIST), {
      CFBundleShortVersionString: escapeXml(
        IOSConfig.Version.getVersion(config)
      ),
      CFBundleVersion: escapeXml(IOSConfig.Version.getBuildNumber(config)),
      SallaPushAppGroup:
        group === undefined
          ? []
          : ['<key>SallaPushAppGroup</key>', `<string>${group}</string>`],
    }),
    [ENTITLEMENTS]: render(readTemplate(ENTITLEMENTS), {
      ApplicationGroups:
        group === undefined
          ? []
          : [
              '<key>com.apple.security.application-groups</key>',
              '<array>',
              `\t<string>${group}</string>`,
              '</array>',
            ],
    }),
  };
}

function findTarget(project: XcodeProject) {
  return IOSConfig.Target.getNativeTargets(project).find(
    ([, target]) => IOSConfig.XcodeUtils.unquote(target.name) === NSE_TARGET
  );
}

/** The build settings of each configuration in the list, by configuration name. */
function configurations(
  project: XcodeProject,
  listId: string
): Map<string, BuildSettings> {
  const objects = project.hash.project.objects;
  const list = objects.XCConfigurationList?.[listId];
  const entries: { value: string }[] = list?.buildConfigurations ?? [];
  return new Map(
    entries.map(({ value }) => {
      const configuration = objects.XCBuildConfiguration?.[value];
      return [configuration?.name, configuration?.buildSettings ?? {}];
    })
  );
}

function addTarget(project: XcodeProject, bundleIdentifier: string): string {
  const objects = project.hash.project.objects;
  // addTarget links the app to the extension only when these sections exist; a one-target project has neither.
  objects.PBXTargetDependency ??= {};
  objects.PBXContainerItemProxy ??= {};
  const group = project.addPbxGroup(
    [SOURCE, INFO_PLIST, ENTITLEMENTS],
    NSE_TARGET,
    NSE_TARGET
  );
  project.addToPbxGroup(
    group.uuid,
    project.getFirstProject().firstProject.mainGroup
  );
  const target = project.addTarget(
    NSE_TARGET,
    'app_extension',
    NSE_TARGET,
    bundleIdentifier
  );
  project.addBuildPhase(
    [SOURCE],
    'PBXSourcesBuildPhase',
    'Sources',
    target.uuid
  );
  project.addBuildPhase([], 'PBXResourcesBuildPhase', 'Resources', target.uuid);
  project.addBuildPhase(
    [],
    'PBXFrameworksBuildPhase',
    'Frameworks',
    target.uuid
  );
  tidy(
    project,
    group.pbxGroup.children,
    target.pbxNativeTarget.productReference
  );
  return target.uuid;
}

/**
 * Leaves out what the xcode package writes but Xcode doesn't: undefined values, build files for the plists, which no
 * phase uses, and "Copy Files" as the name of the phase that embeds the extension.
 */
function tidy(
  project: XcodeProject,
  children: { value: string; comment?: string }[],
  product: string
): void {
  const objects = project.hash.project.objects;
  const references = objects.PBXFileReference ?? {};
  const files = objects.PBXBuildFile ?? {};
  for (const reference of [...children.map(({ value }) => value), product]) {
    const entry = references[reference] ?? {};
    for (const key of Object.keys(entry)) {
      if (entry[key] === undefined) {
        delete entry[key];
      }
    }
  }
  for (const { value, comment } of children) {
    if (comment === ENTITLEMENTS) {
      (references[value] ?? {}).lastKnownFileType = 'text.plist.entitlements';
    }
    if (comment === SOURCE) {
      continue;
    }
    for (const key of Object.keys(files)) {
      if (files[key]?.fileRef === value) {
        delete files[key];
        delete files[`${key}_comment`];
      }
    }
  }
  const embedded = Object.keys(files).find(
    (key) => files[key]?.fileRef === product
  );
  const label = `${NSE_TARGET}.appex in ${EMBED_PHASE}`;
  const phases = objects.PBXCopyFilesBuildPhase ?? {};
  const app = objects.PBXNativeTarget?.[project.getFirstTarget().uuid];
  for (const step of app?.buildPhases ?? []) {
    const phase = phases[step.value];
    const file = phase?.files?.find(
      (entry: { value: string }) => entry.value === embedded
    );
    if (file !== undefined) {
      phase.name = `"${EMBED_PHASE}"`;
      phases[`${step.value}_comment`] = EMBED_PHASE;
      step.comment = EMBED_PHASE;
      file.comment = label;
      files[`${embedded}_comment`] = label;
    }
  }
}

/**
 * Adds the extension target to the app's project when it has none: its group, its Sources, Resources and Frameworks
 * phases, the embedding in the app and the app's dependency on it. Its build settings are set on every prebuild, so a
 * changed bundle identifier or team reaches it too.
 */
export function addNseTarget(
  project: XcodeProject,
  settings: { bundleIdentifier: string; developmentTeam?: string }
): void {
  const uuid =
    findTarget(project)?.[0] ?? addTarget(project, settings.bundleIdentifier);
  const objects = project.hash.project.objects;
  const target = objects.PBXNativeTarget?.[uuid];
  const app = configurations(
    project,
    project.getFirstTarget().firstTarget.buildConfigurationList
  );
  const base = configurations(
    project,
    project.getFirstProject().firstProject.buildConfigurationList
  );
  for (const [name, buildSettings] of configurations(
    project,
    target?.buildConfigurationList
  )) {
    const inherited = (key: string) =>
      app.get(name)?.[key] ?? base.get(name)?.[key];
    Object.assign(buildSettings, {
      INFOPLIST_FILE: `${NSE_TARGET}/${INFO_PLIST}`,
      PRODUCT_BUNDLE_IDENTIFIER: `${settings.bundleIdentifier}.${NSE_TARGET}`,
      SWIFT_VERSION: '5.0',
      CODE_SIGN_ENTITLEMENTS: `${NSE_TARGET}/${ENTITLEMENTS}`,
      CODE_SIGN_STYLE: 'Automatic',
    });
    for (const key of [
      'IPHONEOS_DEPLOYMENT_TARGET',
      'TARGETED_DEVICE_FAMILY',
    ]) {
      if (inherited(key) !== undefined) {
        buildSettings[key] = inherited(key);
      }
    }
    if (settings.developmentTeam !== undefined) {
      buildSettings.DEVELOPMENT_TEAM = settings.developmentTeam;
    }
  }
  if (settings.developmentTeam !== undefined) {
    project.addTargetAttribute('DevelopmentTeam', settings.developmentTeam, {
      uuid,
    });
  }
}

export const withSallaPushNotificationServiceExtension: ConfigPlugin<
  IOSProps
> = (config, ios) => {
  const withFiles = withDangerousMod(config, [
    'ios',
    async (mod) => {
      const folder = path.join(mod.modRequest.platformProjectRoot, NSE_TARGET);
      await fs.promises.mkdir(folder, { recursive: true });
      for (const [name, contents] of Object.entries(nseFiles(mod, ios))) {
        await fs.promises.writeFile(path.join(folder, name), contents);
      }
      return mod;
    },
  ]);
  return withXcodeProject(withFiles, (mod) => {
    const bundleIdentifier = mod.ios?.bundleIdentifier;
    if (bundleIdentifier === undefined) {
      throw new Error(
        `${PLUGIN_NAME}: the Notification Service Extension needs ios.bundleIdentifier in the app config.`
      );
    }
    addNseTarget(mod.modResults as XcodeProject, {
      bundleIdentifier,
      developmentTeam: ios.developmentTeam ?? mod.ios?.appleTeamId,
    });
    return mod;
  });
};

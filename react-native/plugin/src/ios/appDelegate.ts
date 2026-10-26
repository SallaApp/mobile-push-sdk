import { withAppDelegate, type ConfigPlugin } from 'expo/config-plugins';
import path from 'path';

import { PLUGIN_NAME } from '../constants';
import {
  indentOf,
  mergeBlock,
  removeBlock,
  withoutBlocks,
  type Anchor,
} from '../mergeBlock';

/** An `application(_:…)` method, known by its second argument label. */
interface Method {
  readonly label: string;
  /** The declaration after the parameter name, as far as it tells this method from its overloads. */
  readonly rest: string;
}

/** A call SallaPush receives from the app delegate. */
interface Forward extends Method {
  readonly tag: string;
  /** SallaPush's line, given the method's parameter name. */
  readonly call: (parameter: string) => string;
  /** Finds that line in the app's own code. */
  readonly called: RegExp;
  /** The override added when the app delegate has none. */
  readonly override: readonly string[];
}

const LAUNCH: Method = { label: 'didFinishLaunchingWithOptions', rest: '' };
const START = 'SallaPushRN.start()';
const STARTED = /\bSallaPushRN\.start\s*\(\s*\)/;
const MODULES = ['SallaPush', 'SallaPushReactNative'];

const FORWARDS: readonly Forward[] = [
  {
    tag: 'token',
    label: 'didRegisterForRemoteNotificationsWithDeviceToken',
    rest: String.raw`\s*Data\b`,
    call: (token) =>
      `SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: ${token})`,
    called:
      /\bSallaPush\.Notifications\.didRegisterForRemoteNotifications\s*\(/,
    override: [
      'public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {',
      '  SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)',
      '  super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)',
      '}',
    ],
  },
  {
    tag: 'failure',
    label: 'didFailToRegisterForRemoteNotificationsWithError',
    rest: String.raw`\s*(?:any\s+)?Error\b`,
    call: (error) =>
      `SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: ${error})`,
    called:
      /\bSallaPush\.Notifications\.didFailToRegisterForRemoteNotifications\s*\(/,
    override: [
      'public override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {',
      '  SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: error)',
      '  super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)',
      '}',
    ],
  },
  {
    tag: 'remote-notification',
    label: 'didReceiveRemoteNotification',
    // The completion-handler form, or its async variant; not the old form without a completion.
    rest: String.raw`\s*\[\s*AnyHashable\s*:\s*Any\s*\]\s*(?:,\s*fetchCompletionHandler\b|\)\s*async\b)`,
    call: (userInfo) =>
      `SallaPush.Notifications.didReceiveRemoteNotification(${userInfo})`,
    called: /\bSallaPush\.Notifications\.didReceiveRemoteNotification\s*\(/,
    override: [
      'public override func application(',
      '  _ application: UIApplication,',
      '  didReceiveRemoteNotification userInfo: [AnyHashable: Any],',
      '  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void',
      ') {',
      '  SallaPush.Notifications.didReceiveRemoteNotification(userInfo)',
      '  super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)',
      '}',
    ],
  },
];

const IMPORT =
  /^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private)\s+)?import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?([\w.]+)/;

/** The app's own code: SallaPush's blocks and comment lines are blanked, line for line. */
function searchable(src: string): string {
  return withoutBlocks(src).replace(/^[ \t]*\/\/.*$/gm, '');
}

function lineAt(text: string, index: number): number {
  return text.slice(0, index).split('\n').length - 1;
}

function closingBrace(text: string, open: number): number {
  let depth = 0;
  for (let index = open; index < text.length; index += 1) {
    if (text[index] === '{') {
      depth += 1;
    } else if (text[index] === '}') {
      depth -= 1;
      if (depth === 0) {
        return index;
      }
    }
  }
  return -1;
}

/** The app delegate's own implementation of `method`. `body` is undefined when its body can't be read. */
function findMethod(src: string, method: Method) {
  const text = searchable(src);
  const declaration = new RegExp(
    String.raw`\bfunc\s+application\s*\(\s*_\s+\w+\s*:\s*UIApplication\s*,\s*` +
      method.label +
      String.raw`(?:\s+(\w+))?\s*:` +
      method.rest
  ).exec(text);
  if (declaration === null) {
    return undefined;
  }
  const parameter = declaration[1] ?? method.label;
  const after = declaration.index + declaration[0].length;
  const open = text.indexOf('{', after);
  const lineEnd = text.indexOf('\n', open);
  const close = open === -1 ? -1 : closingBrace(text, open);
  if (
    close === -1 ||
    /[;}]|\bfunc\b/.test(text.slice(after, open)) ||
    text.slice(open + 1, lineEnd === -1 ? undefined : lineEnd).trim() !== ''
  ) {
    return { parameter, body: undefined };
  }
  const lines = src.split('\n');
  const line = lineAt(text, open);
  const outer = indentOf(lines[lineAt(text, declaration.index)] ?? '');
  const next =
    lines.slice(line + 1).find((candidate) => candidate.trim() !== '') ?? '';
  const first: Anchor = {
    index: line + 1,
    indent:
      indentOf(next).length > outer.length ? indentOf(next) : `${outer}  `,
  };
  return { parameter, body: { text: text.slice(open, close + 1), first } };
}

function byHand(file: string, problem: string, lines: readonly string[]) {
  return new Error(
    `${PLUGIN_NAME}: ${problem} in ${file}. Add these lines by hand, then run prebuild again:\n\n${lines.join('\n')}\n`
  );
}

function addImports(src: string, file: string): string {
  const own = searchable(src).split('\n');
  const imported = new Set(own.map((line) => IMPORT.exec(line)?.[1]));
  const lines = MODULES.filter((module) => !imported.has(module)).map(
    (module) => `import ${module}`
  );
  if (lines.length === 0) {
    return removeBlock(src, 'imports');
  }
  const merged = mergeBlock(
    src,
    { tag: 'imports', comment: '//', lines },
    () => {
      const last = own.findLastIndex((line) => IMPORT.test(line));
      return last === -1
        ? undefined
        : { index: last + 1, indent: indentOf(own[last] ?? '') };
    }
  );
  if (merged === undefined) {
    throw byHand(file, 'there is no import line', lines);
  }
  return merged;
}

function addStart(src: string, file: string): string {
  const found = findMethod(src, LAUNCH);
  if (found?.body === undefined) {
    if (STARTED.test(searchable(src))) {
      return removeBlock(src, 'start');
    }
    throw byHand(
      file,
      'there is no application(_:didFinishLaunchingWithOptions:) whose body the plugin can read',
      [`${START} // the method's first statement`]
    );
  }
  const { body } = found;
  return STARTED.test(body.text)
    ? removeBlock(src, 'start')
    : mergeBlock(
        src,
        { tag: 'start', comment: '//', lines: [START] },
        () => body.first
      );
}

/**
 * Adds SallaPush to a Swift app delegate: the imports, `SallaPushRN.start()` first in
 * `application(_:didFinishLaunchingWithOptions:)`, and the three forwarding methods. A method the app delegate already
 * overrides gets only SallaPush's line, as its first statement, since a second override wouldn't compile.
 */
export function addToAppDelegate(src: string, file: string): string {
  let result = addStart(addImports(src, file), file);
  const missing: Forward[] = [];
  for (const forward of FORWARDS) {
    const found = findMethod(result, forward);
    if (found === undefined) {
      missing.push(forward);
      continue;
    }
    const { body } = found;
    if (body === undefined) {
      if (forward.called.test(searchable(result))) {
        result = removeBlock(result, forward.tag);
        continue;
      }
      throw byHand(
        file,
        `the plugin can't read the body of application(_:${forward.label}:)`,
        [`${forward.call(found.parameter)} // the method's first statement`]
      );
    }
    result = forward.called.test(body.text)
      ? removeBlock(result, forward.tag)
      : mergeBlock(
          result,
          {
            tag: forward.tag,
            comment: '//',
            lines: [forward.call(found.parameter)],
          },
          () => body.first
        );
  }
  if (missing.length === 0) {
    return removeBlock(result, 'methods');
  }
  const methods = missing.flatMap((forward, index) =>
    index === 0 ? forward.override : ['', ...forward.override]
  );
  const merged = mergeBlock(
    result,
    { tag: 'methods', comment: '//', lines: methods },
    (lines) => {
      const index = lines.findIndex((line) => line.trim() === '// Linking API');
      return index === -1
        ? undefined
        : { index, indent: indentOf(lines[index] ?? '') };
    }
  );
  if (merged === undefined) {
    throw byHand(
      file,
      'there is no "// Linking API" line to add the methods before',
      methods
    );
  }
  return merged;
}

/** The plugin doesn't edit Objective-C app delegates: it checks that SallaPush is started, or says what to add. */
export function checkObjectiveC(src: string, file: string): string {
  if (/\[\s*SallaPushRN\s+start\s*\]/.test(src)) {
    return src;
  }
  throw byHand(
    file,
    'the plugin edits Swift app delegates only, and SallaPush is not started',
    [
      '@import SallaPush;',
      '@import SallaPushReactNative;',
      '',
      "[SallaPushRN start]; // application:didFinishLaunchingWithOptions:'s first statement",
      '[SallaPush.Notifications didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];',
      '[SallaPush.Notifications didFailToRegisterForRemoteNotificationsWithError:error];',
      '[SallaPush.Notifications didReceiveRemoteNotification:userInfo];',
    ]
  );
}

export const withSallaPushAppDelegate: ConfigPlugin = (config) =>
  withAppDelegate(config, (mod) => {
    const file = path.relative(mod.modRequest.projectRoot, mod.modResults.path);
    mod.modResults.contents =
      mod.modResults.language === 'swift'
        ? addToAppDelegate(mod.modResults.contents, file)
        : checkObjectiveC(mod.modResults.contents, file);
    return mod;
  });

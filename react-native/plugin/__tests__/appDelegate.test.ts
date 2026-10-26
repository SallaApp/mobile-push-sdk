import { describe, expect, it } from '@jest/globals';

import {
  addToAppDelegate,
  checkObjectiveC,
  withSallaPushAppDelegate,
} from '../src/ios/appDelegate';
import { appConfig, fixture, runMod } from './mods';

const FILE = 'ios/HelloWorld/AppDelegate.swift';
const LABELS = [
  'didRegisterForRemoteNotificationsWithDeviceToken',
  'didFailToRegisterForRemoteNotificationsWithError',
  'didReceiveRemoteNotification',
];

function count(text: string, pattern: RegExp): number {
  return text.match(new RegExp(pattern.source, 'g'))?.length ?? 0;
}

/** How many methods named `application(_:<label>:…)` the source declares. */
function declarations(text: string, label: string): number {
  return count(text, new RegExp(String.raw`func application\([^)]*${label}`));
}

function errorOf(action: () => unknown): string {
  try {
    action();
  } catch (error) {
    return (error as Error).message;
  }
  throw new Error('No error was thrown.');
}

/** The source with `lines` added before `line`, each ending with a line break. */
function insertBefore(
  src: string,
  line: string,
  lines: readonly string[]
): string {
  expect(src).toContain(`${line}\n`);
  return src.replace(`${line}\n`, `${lines.join('\n')}\n${line}\n`);
}

describe.each(['sdk-54', 'sdk-57'])('the Expo %s AppDelegate', (sdk) => {
  const result = addToAppDelegate(fixture(`${sdk}/AppDelegate.swift`), FILE);

  it('gets the imports, the start call and the three forwarding methods', () => {
    expect(result).toMatchSnapshot();
  });

  it('imports both modules after the last import', () => {
    expect(result).toContain(
      [
        'import ReactAppDependencyProvider',
        '// @generated begin sallapush-imports - expo prebuild (DO NOT MODIFY)',
        'import SallaPush',
        'import SallaPushReactNative',
        '// @generated end sallapush-imports',
        '',
        '@',
      ].join('\n')
    );
  });

  it('starts SallaPush as the first statement of didFinishLaunching', () => {
    expect(result).toContain(
      [
        '  ) -> Bool {',
        '    // @generated begin sallapush-start - expo prebuild (DO NOT MODIFY)',
        '    SallaPushRN.start()',
        '    // @generated end sallapush-start',
        '    let delegate = ReactNativeDelegate()',
      ].join('\n')
    );
  });

  it('adds the three methods before // Linking API, each calling SallaPush first, then super', () => {
    expect(result).toContain(
      [
        '  // @generated begin sallapush-methods - expo prebuild (DO NOT MODIFY)',
        '  public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {',
        '    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)',
        '    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)',
        '  }',
        '',
        '  public override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {',
        '    SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: error)',
        '    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)',
        '  }',
        '',
        '  public override func application(',
        '    _ application: UIApplication,',
        '    didReceiveRemoteNotification userInfo: [AnyHashable: Any],',
        '    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void',
        '  ) {',
        '    SallaPush.Notifications.didReceiveRemoteNotification(userInfo)',
        '    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)',
        '  }',
        '  // @generated end sallapush-methods',
        '  // Linking API',
      ].join('\n')
    );
  });

  it('is unchanged by a second run', () => {
    expect(addToAppDelegate(result, FILE)).toBe(result);
  });
});

describe('an AppDelegate that already overrides two of the methods', () => {
  const result = addToAppDelegate(fixture('overrides/AppDelegate.swift'), FILE);

  it('gets SallaPush lines inside those methods and only the third method', () => {
    expect(result).toMatchSnapshot();
  });

  it('declares each method once', () => {
    for (const label of LABELS) {
      expect(declarations(result, label)).toBe(1);
    }
  });

  it("calls SallaPush first in the app's methods, with their parameter names", () => {
    expect(result).toContain(
      [
        'didRegisterForRemoteNotificationsWithDeviceToken token: Data) {',
        '    // @generated begin sallapush-token - expo prebuild (DO NOT MODIFY)',
        '    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: token)',
        '    // @generated end sallapush-token',
        '    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: token)',
      ].join('\n')
    );
    expect(result).toContain(
      [
        '  ) {',
        '    // @generated begin sallapush-remote-notification - expo prebuild (DO NOT MODIFY)',
        '    SallaPush.Notifications.didReceiveRemoteNotification(payload)',
        '    // @generated end sallapush-remote-notification',
        '    super.application(application, didReceiveRemoteNotification: payload, fetchCompletionHandler: completionHandler)',
      ].join('\n')
    );
  });

  it('adds only the failure method itself', () => {
    const block =
      /sallapush-methods[^\n]*\n([\s\S]*?)\n.*@generated end sallapush-methods/.exec(
        result
      )?.[1];

    expect(block).toBeDefined();
    expect(block).toContain('didFailToRegisterForRemoteNotificationsWithError');
    expect(block).not.toContain(
      'didRegisterForRemoteNotificationsWithDeviceToken'
    );
    expect(block).not.toContain('didReceiveRemoteNotification');
  });

  it('is unchanged by a second run', () => {
    expect(addToAppDelegate(result, FILE)).toBe(result);
  });
});

describe('a later run', () => {
  const generated = addToAppDelegate(fixture('sdk-57/AppDelegate.swift'), FILE);

  it('drops a method from its block once the app delegate has its own', () => {
    const edited = insertBefore(generated, '  // Universal Links', [
      '  public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {',
      '    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)',
      '  }',
      '',
    ]);

    const result = addToAppDelegate(edited, FILE);

    expect(declarations(result, LABELS[0] ?? '')).toBe(1);
    expect(result).toContain(
      [
        'didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {',
        '    // @generated begin sallapush-token - expo prebuild (DO NOT MODIFY)',
        '    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)',
        '    // @generated end sallapush-token',
        '    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)',
        '  }',
        '',
        '  // Universal Links',
      ].join('\n')
    );
    expect(addToAppDelegate(result, FILE)).toBe(result);
  });

  it("removes SallaPush's line from a method that now calls SallaPush itself", () => {
    const overridden = addToAppDelegate(
      fixture('overrides/AppDelegate.swift'),
      FILE
    );
    const edited = overridden.replace(
      '    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: token)',
      '    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: token)\n    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: token)'
    );

    const result = addToAppDelegate(edited, FILE);

    expect(result).not.toContain('sallapush-token');
    expect(
      count(
        result,
        /SallaPush\.Notifications\.didRegisterForRemoteNotifications\(/
      )
    ).toBe(1);
  });

  it('removes the methods block once the app delegate has all three methods', () => {
    const edited = insertBefore(generated, '  // Universal Links', [
      '  public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {',
      '    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)',
      '  }',
      '',
      '  public override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {',
      '    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)',
      '  }',
      '',
      '  public override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {',
      '    return .noData',
      '  }',
      '',
    ]);

    const result = addToAppDelegate(edited, FILE);

    expect(result).not.toContain('sallapush-methods');
    for (const label of LABELS) {
      expect(declarations(result, label)).toBe(1);
    }
    expect(result).toContain(
      '    // @generated begin sallapush-failure - expo prebuild (DO NOT MODIFY)\n    SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: error)\n'
    );
    expect(result).toContain(
      'async -> UIBackgroundFetchResult {\n    // @generated begin sallapush-remote-notification - expo prebuild (DO NOT MODIFY)\n    SallaPush.Notifications.didReceiveRemoteNotification(userInfo)\n'
    );
  });
});

describe('an AppDelegate that calls SallaPush by hand', () => {
  const src = insertBefore(
    fixture('sdk-57/AppDelegate.swift').replace(
      'internal import Expo\n',
      'internal import Expo\nimport SallaPush\n'
    ),
    '  // Linking API',
    [
      '  public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {',
      '    SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)',
      '    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)',
      '  }',
      '',
      '  public override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {',
      '    SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: error)',
      '    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)',
      '  }',
      '',
      '  public override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {',
      '    SallaPush.Notifications.didReceiveRemoteNotification(userInfo)',
      '    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)',
      '  }',
      '',
    ]
  ).replace('  ) -> Bool {\n', '  ) -> Bool {\n    SallaPushRN.start()\n');

  it('gets only the import it lacks', () => {
    const result = addToAppDelegate(src, FILE);

    expect(result).toBe(
      src.replace(
        'import ReactAppDependencyProvider\n',
        'import ReactAppDependencyProvider\n// @generated begin sallapush-imports - expo prebuild (DO NOT MODIFY)\nimport SallaPushReactNative\n// @generated end sallapush-imports\n'
      )
    );
  });

  it('gets nothing once it imports both modules', () => {
    const complete = src.replace(
      'import SallaPush\n',
      'import SallaPush\nimport SallaPushReactNative\n'
    );

    expect(addToAppDelegate(complete, FILE)).toBe(complete);
  });

  it('accepts a one-line method that calls SallaPush itself', () => {
    const earlier = addToAppDelegate(fixture('sdk-57/AppDelegate.swift'), FILE);
    const edited = insertBefore(earlier, '  // Universal Links', [
      '  public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken); super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken) }',
      '',
    ]);

    const result = addToAppDelegate(edited, FILE);

    expect(declarations(result, LABELS[0] ?? '')).toBe(1);
    expect(result).toContain('sallapush-methods');
    expect(result).not.toContain('sallapush-token');
  });
});

describe('an AppDelegate the plugin cannot edit', () => {
  const template = fixture('sdk-57/AppDelegate.swift');

  it('throws with the methods to add without the // Linking API line', () => {
    const message = errorOf(() =>
      addToAppDelegate(template.replace('  // Linking API\n', ''), FILE)
    );

    expect(message).toContain(
      '@salla.sa/mobile-push-react-native: there is no "// Linking API" line to add the methods before in ios/HelloWorld/AppDelegate.swift. Add these lines by hand, then run prebuild again:'
    );
    expect(message).toContain(
      'public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {\n  SallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)'
    );
    expect(message).toContain(
      '  SallaPush.Notifications.didReceiveRemoteNotification(userInfo)'
    );
  });

  it('throws with the start line without didFinishLaunching', () => {
    const message = errorOf(() =>
      addToAppDelegate(
        template.replace(
          'didFinishLaunchingWithOptions launchOptions',
          'willFinishLaunchingWithOptions launchOptions'
        ),
        FILE
      )
    );

    expect(message).toBe(
      "@salla.sa/mobile-push-react-native: there is no application(_:didFinishLaunchingWithOptions:) whose body the plugin can read in ios/HelloWorld/AppDelegate.swift. Add these lines by hand, then run prebuild again:\n\nSallaPushRN.start() // the method's first statement\n"
    );
  });

  it('throws without an import line', () => {
    expect(() =>
      addToAppDelegate(template.replace(/^.*import .*\n/gm, ''), FILE)
    ).toThrow(
      '@salla.sa/mobile-push-react-native: there is no import line in ios/HelloWorld/AppDelegate.swift. Add these lines by hand, then run prebuild again:\n\nimport SallaPush\nimport SallaPushReactNative\n'
    );
  });

  it("throws with SallaPush's line when a method's body can't be read", () => {
    const src = insertBefore(template, '  // Linking API', [
      '  public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) { super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: token) }',
    ]);

    expect(() => addToAppDelegate(src, FILE)).toThrow(
      "the plugin can't read the body of application(_:didRegisterForRemoteNotificationsWithDeviceToken:) in ios/HelloWorld/AppDelegate.swift. Add these lines by hand, then run prebuild again:\n\nSallaPush.Notifications.didRegisterForRemoteNotifications(deviceToken: token) // the method's first statement\n"
    );
  });

  it("throws with SallaPush's line when a method's body never closes", () => {
    const truncated = `${template.slice(0, template.indexOf('  // Linking API'))}  public override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {\n`;

    expect(() => addToAppDelegate(truncated, FILE)).toThrow(
      "the plugin can't read the body of application(_:didFailToRegisterForRemoteNotificationsWithError:)"
    );
  });

  it("accepts a didFinishLaunching it can't read once it starts SallaPush", () => {
    const src = template.replace(
      '  ) -> Bool {\n',
      '  ) -> Bool { SallaPushRN.start()\n'
    );

    expect(() => addToAppDelegate(src, FILE)).not.toThrow();
    expect(() =>
      addToAppDelegate(
        template.replace('  ) -> Bool {\n', '  ) -> Bool { let x = 1\n'),
        FILE
      )
    ).toThrow('Add these lines by hand');
  });

  it('throws when a generated block lost its end line', () => {
    const generated = addToAppDelegate(template, FILE);

    expect(() =>
      addToAppDelegate(
        generated.replace('    // @generated end sallapush-start\n', ''),
        FILE
      )
    ).toThrow(
      '@salla.sa/mobile-push-react-native: the generated block sallapush-start lost its begin or end line. Delete what is left of it, or run npx expo prebuild --clean.'
    );
  });
});

describe('the methods the plugin recognizes', () => {
  const template = fixture('sdk-57/AppDelegate.swift');

  it('ignores commented-out methods and the old didReceiveRemoteNotification without a completion', () => {
    const src = insertBefore(template, '  // Linking API', [
      '  // public override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {',
      '  // }',
      '  public override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {',
      '  }',
      '',
    ]);

    const result = addToAppDelegate(src, FILE);

    expect(result).not.toContain('sallapush-token');
    expect(result).not.toContain('sallapush-remote-notification');
    expect(result).toContain(
      '  public override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {\n  }\n'
    );
    expect(result).toContain('fetchCompletionHandler completionHandler');
  });

  it('indents the line in an empty method two spaces deeper than the method', () => {
    const src = insertBefore(template, '  // Linking API', [
      '  public override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {',
      '  }',
    ]);

    expect(addToAppDelegate(src, FILE)).toContain(
      'WithError error: Error) {\n    // @generated begin sallapush-failure - expo prebuild (DO NOT MODIFY)\n    SallaPush.Notifications.didFailToRegisterForRemoteNotifications(error: error)\n    // @generated end sallapush-failure\n  }\n'
    );
  });
});

describe('an Objective-C AppDelegate', () => {
  it('throws with the lines to add', () => {
    const message = errorOf(() =>
      checkObjectiveC(
        '@implementation AppDelegate\n@end\n',
        'ios/HelloWorld/AppDelegate.mm'
      )
    );

    expect(message).toContain(
      '@salla.sa/mobile-push-react-native: the plugin edits Swift app delegates only, and SallaPush is not started in ios/HelloWorld/AppDelegate.mm.'
    );
    expect(message).toContain('[SallaPushRN start];');
    expect(message).toContain(
      '[SallaPush.Notifications didReceiveRemoteNotification:userInfo];'
    );
  });

  it('is left as it is once it starts SallaPush', () => {
    const src =
      '- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {\n  [SallaPushRN start];\n}\n';

    expect(checkObjectiveC(src, 'ios/HelloWorld/AppDelegate.mm')).toBe(src);
  });
});

describe('withSallaPushAppDelegate', () => {
  it('edits a Swift AppDelegate through the appDelegate mod', async () => {
    const contents = fixture('sdk-57/AppDelegate.swift');
    const config = withSallaPushAppDelegate(appConfig());

    const { modResults } = await runMod(config, 'ios', 'appDelegate', {
      path: '/app/ios/HelloWorld/AppDelegate.swift',
      language: 'swift' as const,
      contents,
    });

    expect(modResults.contents).toBe(addToAppDelegate(contents, FILE));
  });

  it('checks an Objective-C AppDelegate, naming its path in the project', async () => {
    const config = withSallaPushAppDelegate(appConfig());

    await expect(
      runMod(config, 'ios', 'appDelegate', {
        path: '/app/ios/HelloWorld/AppDelegate.mm',
        language: 'objcpp' as const,
        contents: '@implementation AppDelegate\n@end\n',
      })
    ).rejects.toThrow(
      'SallaPush is not started in ios/HelloWorld/AppDelegate.mm.'
    );
  });
});

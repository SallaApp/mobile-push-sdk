// Stand-ins for the app's own code that the docs' snippets call: declarations only, since the snippets are compiled
// and never run.

/** The app's telemetry, where SallaPush errors go. */
export declare const telemetry: {
  report(
    source: string,
    code: string,
    message: string,
    metadata: Readonly<Record<string, string>>
  ): void;
};

/** The app's settings screen. */
export declare const settingsScreen: {
  showPermission(granted: boolean): void;
};

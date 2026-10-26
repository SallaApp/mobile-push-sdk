/** Where the wrapper's own JavaScript lines go: the app's console, which React Native shows in LogBox. */
const output: Pick<Console, 'warn'> = console;

const reported = new Set<string>();

/** Writes a `[SallaPush]` warning the first time `key` comes up in this JavaScript runtime. */
export function warnOnce(key: string, message: string): void {
  if (reported.has(key)) {
    return;
  }
  reported.add(key);
  output.warn(`[SallaPush] ${message}`);
}

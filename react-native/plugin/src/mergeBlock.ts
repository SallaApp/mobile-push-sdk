import { PLUGIN_NAME } from './constants';

/** Generated lines in a native file, between markers that let the next prebuild find and replace them. */
export interface Block {
  /** Its markers are `@generated begin sallapush-<tag>` and `@generated end sallapush-<tag>`. */
  readonly tag: string;
  /** The line comment of the file's language. */
  readonly comment: '//' | '#';
  /** The lines between the markers, indented relative to them. */
  readonly lines: readonly string[];
}

/** Where a new block goes: before line `index`, indented with `indent`. */
export interface Anchor {
  readonly index: number;
  readonly indent: string;
}

const MARKER =
  /^\s*(?:\/\/|#) @generated (begin|end) sallapush-([\w-]+)(?:\s|$)/;

export function indentOf(line: string): string {
  return /^\s*/.exec(line)?.[0] ?? '';
}

/** The first and last line of the block `tag`; undefined when there is none. */
function findBlock(lines: readonly string[], tag: string) {
  const isMarker = (line: string, kind: string) => {
    const match = MARKER.exec(line);
    return match?.[1] === kind && match[2] === tag;
  };
  const start = lines.findIndex((line) => isMarker(line, 'begin'));
  const end = lines.findIndex(
    (line, index) => index > start && isMarker(line, 'end')
  );
  if (start === -1 && end === -1) {
    return undefined;
  }
  if (start === -1 || end === -1) {
    throw new Error(
      `${PLUGIN_NAME}: the generated block sallapush-${tag} lost its begin or end line. Delete what is left of it, or run npx expo prebuild --clean.`
    );
  }
  return { start, end };
}

/**
 * Replaces the block where it is, or inserts it at the anchor. Returns undefined when the block is new and the
 * anchor can't be found.
 */
export function mergeBlock(
  src: string,
  block: Block,
  anchor: (lines: readonly string[]) => Anchor
): string;
export function mergeBlock(
  src: string,
  block: Block,
  anchor: (lines: readonly string[]) => Anchor | undefined
): string | undefined;
export function mergeBlock(
  src: string,
  block: Block,
  anchor: (lines: readonly string[]) => Anchor | undefined
): string | undefined {
  const lines = src.split('\n');
  const found = findBlock(lines, block.tag);
  const at = found
    ? { index: found.start, indent: indentOf(lines[found.start] ?? '') }
    : anchor(lines);
  if (at === undefined) {
    return undefined;
  }
  lines.splice(
    at.index,
    found ? found.end - found.start + 1 : 0,
    `${at.indent}${block.comment} @generated begin sallapush-${block.tag} - expo prebuild (DO NOT MODIFY)`,
    ...block.lines.map((line) => (line === '' ? '' : at.indent + line)),
    `${at.indent}${block.comment} @generated end sallapush-${block.tag}`
  );
  return lines.join('\n');
}

export function removeBlock(src: string, tag: string): string {
  const lines = src.split('\n');
  const found = findBlock(lines, tag);
  if (found) {
    lines.splice(found.start, found.end - found.start + 1);
  }
  return lines.join('\n');
}

/** The source with every SallaPush block blanked line for line, so searches find only the app's own code. */
export function withoutBlocks(src: string): string {
  let inside = false;
  return src
    .split('\n')
    .map((line) => {
      const kind = MARKER.exec(line)?.[1];
      if (kind === 'begin') {
        inside = true;
      }
      const blank = inside || kind !== undefined;
      if (kind === 'end') {
        inside = false;
      }
      return blank ? '' : line;
    })
    .join('\n');
}

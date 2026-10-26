import fs from 'fs';
import path from 'path';

import { PLUGIN_NAME } from './constants';

const FOLDER = path.join(__dirname, '..', 'templates');

/** A file of plugin/templates, which the package ships next to plugin/build. */
export function readTemplate(name: string): string {
  return fs.readFileSync(path.join(FOLDER, name), 'utf8');
}

/**
 * Fills a template: `{{Name}}` takes a string; a line holding only `{{Name}}` takes lines, each indented like it, and
 * disappears when there are none.
 */
export function render(
  template: string,
  values: Record<string, string | readonly string[]>
): string {
  const value = (name: string) => {
    const filled = values[name];
    if (filled === undefined) {
      throw new Error(`${PLUGIN_NAME}: the template has no value for ${name}.`);
    }
    return filled;
  };
  return template
    .replace(/^([ \t]*)\{\{(\w+)\}\}\n/gm, (_, indent: string, name: string) =>
      [value(name)]
        .flat()
        .map((line) => `${indent}${line}\n`)
        .join('')
    )
    .replace(/\{\{(\w+)\}\}/g, (_, name: string) =>
      [value(name)].flat().join('')
    );
}

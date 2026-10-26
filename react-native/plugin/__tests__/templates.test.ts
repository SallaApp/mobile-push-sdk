import { describe, expect, it } from '@jest/globals';
import fs from 'fs';
import path from 'path';

import { readTemplate, render } from '../src/templates';

describe('render', () => {
  it('fills values and whole-line lists, indented like their line', () => {
    expect(
      render('<a>{{name}}</a>\n\t{{lines}}\nend {{name}}\n', {
        name: 'x',
        lines: ['<b/>', '\t<c/>'],
      })
    ).toBe('<a>x</a>\n\t<b/>\n\t\t<c/>\nend x\n');
  });

  it('drops the line of an empty list', () => {
    expect(render('<dict>\n\t{{lines}}\n</dict>\n', { lines: [] })).toBe(
      '<dict>\n</dict>\n'
    );
  });

  it('throws for a placeholder without a value', () => {
    expect(() => render('{{missing}}', {})).toThrow(
      '@salla.sa/mobile-push-react-native: the template has no value for missing.'
    );
  });
});

describe('readTemplate', () => {
  it('reads plugin/templates', () => {
    expect(readTemplate('NotificationService.swift')).toBe(
      fs.readFileSync(
        path.join(__dirname, '..', 'templates', 'NotificationService.swift'),
        'utf8'
      )
    );
  });
});

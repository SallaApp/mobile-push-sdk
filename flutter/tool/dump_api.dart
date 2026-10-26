// Lists the public Dart API of mobile_push, one sorted line per class,
// enum, member and top-level declaration that lib/mobile_push.dart
// exports, so that every change of the public API shows in review as a change
// of api/mobile_push.api. Syntactic only: it parses, never resolves.
//
//   dart run tool/dump_api.dart            prints the dump
//   dart run tool/dump_api.dart --check    fails when api/mobile_push.api differs
//   dart run tool/dump_api.dart --write    updates api/mobile_push.api
//
// Run it from the flutter/ folder.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// The committed dump, relative to the flutter/ folder.
const String dumpFile = 'api/mobile_push.api';

/// The library whose exports make the public API.
const String publicLibrary = 'lib/mobile_push.dart';

/// The name of this package, for `package:` URIs in exports.
const String packageName = 'mobile_push';

void main(List<String> arguments) {
  final String? mode = arguments.firstOrNull;
  if (arguments.length > 1 ||
      (mode != null && mode != '--check' && mode != '--write')) {
    stderr.writeln('usage: dart run tool/dump_api.dart [--check | --write]');
    exitCode = 2;
    return;
  }
  final List<String> dump;
  try {
    dump = dumpApi(Directory.current.path);
  } on ApiDumpException catch (error) {
    stderr.writeln('dump_api: $error');
    exitCode = 1;
    return;
  }
  final String text = '${dump.join('\n')}\n';
  final File file = File(dumpFile);
  switch (mode) {
    case '--write':
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
      stdout.writeln('dump_api: wrote $dumpFile (${dump.length} lines)');
    case '--check':
      final String committed = file.existsSync() ? file.readAsStringSync() : '';
      if (committed == text) {
        stdout.writeln('dump_api: $dumpFile is current (${dump.length} lines)');
        return;
      }
      final List<String> before = committed.split('\n')
        ..removeWhere((line) => line.isEmpty);
      stderr.writeln('dump_api: the public API differs from $dumpFile:');
      for (final String line in before.where((line) => !dump.contains(line))) {
        stderr.writeln('- $line');
      }
      for (final String line in dump.where((line) => !before.contains(line))) {
        stderr.writeln('+ $line');
      }
      stderr.writeln(
        'Review the change, then run: dart run tool/dump_api.dart --write',
      );
      exitCode = 1;
    default:
      stdout.write(text);
  }
}

/// Why the API could not be listed.
final class ApiDumpException implements Exception {
  /// Creates the exception with its [message].
  ApiDumpException(this.message);

  /// What went wrong, and where.
  final String message;

  @override
  String toString() => message;
}

/// The public API of the package at [root]: one line per declaration and
/// member that [library] exports, sorted by the symbol it declares (`Name` or
/// `Name.member`), then by text.
List<String> dumpApi(String root, {String library = publicLibrary}) {
  final _Exports exports = _Exports(root);
  final List<_Line> lines = <_Line>[
    for (final MapEntry<String, _Declaration> entry
        in exports.namespace(_normalize('$root/$library')).entries)
      ..._lines(entry.key, entry.value),
  ];
  lines.sort((a, b) {
    final int bySymbol = a.symbol.compareTo(b.symbol);
    return bySymbol != 0 ? bySymbol : a.text.compareTo(b.text);
  });
  return <String>[for (final _Line line in lines) line.text];
}

/// One top-level declaration and the file that declares it.
final class _Declaration {
  _Declaration(this.node, this.path);

  final CompilationUnitMember node;
  final String path;
}

/// One line of the dump, with the symbol it declares.
final class _Line {
  _Line(this.symbol, this.text);

  final String symbol;
  final String text;
}

/// Follows exports and parts from a library file, with the show and hide
/// combinators applied, as Dart does.
final class _Exports {
  _Exports(this.root);

  final String root;
  final Map<String, CompilationUnit> _units = <String, CompilationUnit>{};
  final Set<String> _visiting = <String>{};

  /// The public names that the library at [path] declares or exports.
  Map<String, _Declaration> namespace(String path) {
    if (!_visiting.add(path)) {
      // An export cycle: the names of the library being built come from its
      // other exports and its declarations.
      return const <String, _Declaration>{};
    }
    final CompilationUnit unit = _parse(path);
    final Map<String, _Declaration> names = <String, _Declaration>{};
    _declare(names, unit, path);
    for (final Directive directive in unit.directives) {
      if (directive is PartDirective) {
        final String part = _resolve(path, directive.uri);
        _declare(names, _parse(part), part);
      }
    }
    for (final Directive directive in unit.directives) {
      if (directive is! ExportDirective) {
        continue;
      }
      if (directive.configurations.isNotEmpty) {
        throw ApiDumpException(
          '$path: a conditional export is not supported; extend tool/dump_api.dart',
        );
      }
      Map<String, _Declaration> exported = namespace(
        _resolve(path, directive.uri),
      );
      for (final Combinator combinator in directive.combinators) {
        final (bool show, List<SimpleIdentifier> listed) = switch (combinator) {
          ShowCombinator() => (true, combinator.shownNames),
          HideCombinator() => (false, combinator.hiddenNames),
        };
        final Set<String> listedNames = <String>{
          for (final SimpleIdentifier name in listed) name.name,
        };
        exported = <String, _Declaration>{
          for (final MapEntry<String, _Declaration> entry in exported.entries)
            if (listedNames.contains(entry.key) == show) entry.key: entry.value,
        };
      }
      names.addAll(exported);
    }
    _visiting.remove(path);
    return names;
  }

  void _declare(
    Map<String, _Declaration> names,
    CompilationUnit unit,
    String path,
  ) {
    for (final CompilationUnitMember member in unit.declarations) {
      for (final String name in _names(member)) {
        if (!name.startsWith('_')) {
          names[name] = _Declaration(member, path);
        }
      }
    }
  }

  CompilationUnit _parse(String path) => _units[path] ??= _parseFile(path);

  CompilationUnit _parseFile(String path) {
    if (!File(path).existsSync()) {
      throw ApiDumpException('$path does not exist');
    }
    try {
      return parseFile(
        path: path,
        featureSet: FeatureSet.latestLanguageVersion(),
      ).unit;
    } on ArgumentError catch (error) {
      throw ApiDumpException('$path does not parse: ${error.message}');
    }
  }

  String _resolve(String from, StringLiteral literal) {
    final String? uri = literal.stringValue;
    if (uri == null) {
      throw ApiDumpException('$from: an interpolated URI is not supported');
    }
    const String own = 'package:$packageName/';
    if (uri.startsWith(own)) {
      return _normalize('$root/lib/${uri.substring(own.length)}');
    }
    if (uri.contains(':')) {
      throw ApiDumpException(
        "$from: it exports $uri, another package's API; tool/dump_api.dart lists this package's own declarations only",
      );
    }
    return _normalize('${File(from).parent.path}/$uri');
  }
}

/// [path] without `.` and `..` segments, so that one file has one key.
String _normalize(String path) {
  final List<String> segments = <String>[];
  for (final String segment in path.split('/')) {
    if (segment == '..' &&
        segments.isNotEmpty &&
        segments.last != '..' &&
        segments.last.isNotEmpty) {
      segments.removeLast();
    } else if (segment != '.' && (segment.isNotEmpty || segments.isEmpty)) {
      segments.add(segment);
    }
  }
  return segments.join('/');
}

/// The names a top-level declaration introduces.
List<String> _names(CompilationUnitMember member) => switch (member) {
  ClassDeclaration() => <String>[member.namePart.typeName.lexeme],
  EnumDeclaration() => <String>[member.namePart.typeName.lexeme],
  MixinDeclaration() => <String>[member.name.lexeme],
  ExtensionDeclaration() => <String>[?member.name?.lexeme],
  ExtensionTypeDeclaration() => <String>[?_extensionTypeName(member)?.lexeme],
  TypeAlias() => <String>[member.name.lexeme],
  FunctionDeclaration() => <String>[member.name.lexeme],
  TopLevelVariableDeclaration() => <String>[
    for (final VariableDeclaration variable in member.variables.variables)
      variable.name.lexeme,
  ],
  _ => throw ApiDumpException(
    'a ${member.runtimeType} is not supported; extend tool/dump_api.dart',
  ),
};

/// The name of an extension type: the identifier after `extension type`, or
/// after `extension type const`.
Token? _extensionTypeName(ExtensionTypeDeclaration declaration) {
  final Token? name = declaration.typeKeyword.next;
  return name != null && name.lexeme == 'const' ? name.next : name;
}

/// The lines of the declaration exported as [name]: its own line, then those
/// of its public members.
List<_Line> _lines(String name, _Declaration declaration) {
  final CompilationUnitMember node = declaration.node;
  switch (node) {
    case ClassDeclaration(:final ClassBody body) ||
        MixinDeclaration(:final ClassBody body) ||
        ExtensionDeclaration(:final ClassBody body) ||
        ExtensionTypeDeclaration(:final ClassBody body):
      return <_Line>[
        _Line(
          name,
          '${_header(node, body.beginToken)}${_tags(const <String>[], node.metadata)}',
        ),
        for (final ClassMember member in body.members) ..._member(name, member),
      ];
    case EnumDeclaration(:final EnumBody body):
      final String constants = <String>[
        for (final EnumConstantDeclaration constant in body.constants)
          constant.name.lexeme,
      ].join(', ');
      return <_Line>[
        _Line(
          name,
          '${_header(node, body.beginToken)} { $constants }${_tags(const <String>[], node.metadata)}',
        ),
        for (final ClassMember member in body.members)
          // An enum's constructors can only make its constants.
          if (member is! ConstructorDeclaration) ..._member(name, member),
      ];
    case TypeAlias(:final Token semicolon):
      return <_Line>[
        _Line(
          name,
          '${_header(node, semicolon)}${_tags(const <String>[], node.metadata)}',
        ),
      ];
    case FunctionDeclaration(:final FunctionExpression functionExpression):
      return <_Line>[
        _Line(
          name,
          _signature(
            name,
            typeParameters: functionExpression.typeParameters,
            parameters: functionExpression.parameters,
            returnType: node.isSetter ? null : node.returnType,
            modifiers: <String>[
              if (node.externalKeyword != null) 'external',
              node.isGetter
                  ? 'getter'
                  : (node.isSetter ? 'setter' : 'function'),
            ],
            metadata: node.metadata,
          ),
        ),
      ];
    case TopLevelVariableDeclaration(:final VariableDeclarationList variables):
      return <_Line>[
        _Line(
          name,
          _variable(name, variables, const <String>[], node.metadata),
        ),
      ];
    default:
      throw ApiDumpException(
        '${declaration.path}: a ${node.runtimeType} is not supported; extend tool/dump_api.dart',
      );
  }
}

/// The lines of one member of [owner]; none for a private one.
List<_Line> _member(String owner, ClassMember member) {
  switch (member) {
    case MethodDeclaration():
      final String name =
          '${member.operatorKeyword != null ? 'operator' : ''}${member.name.lexeme}';
      if (name.startsWith('_')) {
        return const <_Line>[];
      }
      return <_Line>[
        _Line(
          '$owner.$name',
          _signature(
            '$owner.$name',
            typeParameters: member.typeParameters,
            parameters: member.parameters,
            returnType: member.isSetter ? null : member.returnType,
            modifiers: <String>[
              if (member.isStatic) 'static',
              if (member.externalKeyword != null) 'external',
              if (member.isGetter) 'getter',
              if (member.isSetter) 'setter',
            ],
            metadata: member.metadata,
          ),
        ),
      ];
    case ConstructorDeclaration():
      final String name = member.name?.lexeme ?? 'new';
      if (name.startsWith('_')) {
        return const <_Line>[];
      }
      return <_Line>[
        _Line(
          '$owner.$name',
          _signature(
            '$owner.$name',
            parameters: member.parameters,
            modifiers: <String>[
              if (member.externalKeyword != null) 'external',
              if (member.constKeyword != null) 'const',
              if (member.factoryKeyword != null) 'factory',
              'constructor',
            ],
            metadata: member.metadata,
          ),
        ),
      ];
    case FieldDeclaration(:final VariableDeclarationList fields):
      final List<String> modifiers = <String>[
        if (member.isStatic) 'static',
        if (member.externalKeyword != null) 'external',
        if (member.abstractKeyword != null) 'abstract',
        if (member.covariantKeyword != null) 'covariant',
      ];
      return <_Line>[
        for (final VariableDeclaration variable in fields.variables)
          if (!variable.name.lexeme.startsWith('_'))
            _Line(
              '$owner.${variable.name.lexeme}',
              _variable(
                '$owner.${variable.name.lexeme}',
                fields,
                modifiers,
                member.metadata,
              ),
            ),
      ];
    case PrimaryConstructorBody():
      // The body of the class's primary constructor, whose signature is part of
      // the class line.
      return const <_Line>[];
  }
}

/// `<symbol><type parameters>(<parameters>) -> <return type> [<tags>]`, each
/// part only when it is written.
String _signature(
  String symbol, {
  TypeParameterList? typeParameters,
  FormalParameterList? parameters,
  TypeAnnotation? returnType,
  required List<String> modifiers,
  required List<Annotation> metadata,
}) => <String>[
  symbol,
  if (typeParameters != null) _source(typeParameters),
  if (parameters != null) _source(parameters),
  if (returnType != null) ' -> ${_source(returnType)}',
  _tags(modifiers, metadata),
].join();

/// `<symbol> -> <type> [<modifiers> <keyword>]` for a field or a top-level
/// variable: the type only when it is written; `var` for a mutable one.
String _variable(
  String symbol,
  VariableDeclarationList list,
  List<String> modifiers,
  List<Annotation> metadata,
) {
  final TypeAnnotation? type = list.type;
  final List<String> all = <String>[
    ...modifiers,
    if (list.lateKeyword != null) 'late',
    switch (list.keyword?.lexeme) {
      final String keyword? when keyword != 'var' => keyword,
      _ => 'var',
    },
  ];
  return '$symbol${type == null ? '' : ' -> ${_source(type)}'}${_tags(all, metadata)}';
}

/// ` [<modifiers>, <annotations>]`, or nothing when there are none.
String _tags(List<String> modifiers, List<Annotation> metadata) {
  final List<String> parts = <String>[
    if (modifiers.isNotEmpty) modifiers.join(' '),
    for (final Annotation annotation in metadata) _source(annotation),
  ];
  return parts.isEmpty ? '' : ' [${parts.join(', ')}]';
}

/// A declaration's source from its first keyword up to [stop], the start of
/// its body: `abstract final class SallaPush`.
String _header(AnnotatedNode node, Token stop) {
  final List<Token> tokens = <Token>[];
  for (
    Token? token = node.firstTokenAfterCommentAndMetadata;
    token != null && token != stop && !token.isEof;
    token = token.next
  ) {
    tokens.add(token);
  }
  return _render(tokens);
}

/// The source of [node].
String _source(AstNode node) {
  final List<Token> tokens = <Token>[];
  for (
    Token? token = node.beginToken;
    token != null && !token.isEof;
    token = token.next
  ) {
    tokens.add(token);
    if (token == node.endToken) {
      break;
    }
  }
  return _render(tokens);
}

/// [tokens] without comments, with one space wherever the source has white
/// space, but none just inside brackets, and without trailing commas, so that
/// the dump never depends on how the code is formatted.
String _render(List<Token> tokens) {
  final StringBuffer text = StringBuffer();
  Token? previous;
  for (int index = 0; index < tokens.length; index++) {
    final Token token = tokens[index];
    if (token.type == TokenType.COMMA &&
        index + 1 < tokens.length &&
        _closes(tokens[index + 1])) {
      continue;
    }
    if (previous != null &&
        token.offset > previous.end &&
        !_opens(previous) &&
        !_closes(token)) {
      text.write(' ');
    }
    text.write(token.lexeme);
    previous = token;
  }
  return text.toString();
}

bool _opens(Token token) =>
    token.type == TokenType.OPEN_PAREN ||
    token.type == TokenType.OPEN_SQUARE_BRACKET ||
    token.type == TokenType.OPEN_CURLY_BRACKET ||
    token.type == TokenType.LT;

bool _closes(Token token) =>
    token.type == TokenType.CLOSE_PAREN ||
    token.type == TokenType.CLOSE_SQUARE_BRACKET ||
    token.type == TokenType.CLOSE_CURLY_BRACKET ||
    token.type == TokenType.GT;

/// Emits `blocks.g.dart`: the static block registry as const-friendly Dart.
library;

// Codegen writes long runs of buffer.writeln calls; cascades would hide the
// line structure of the emitted source.
// ignore_for_file: cascade_invocations

import 'literals.dart';

const _blockTyped = {
  'type',
  'name',
  'description',
  'longDescription',
  'category',
  'bgColor',
  'icon',
  'docsLink',
  'hideFromToolbar',
  'preview',
  'triggerAllowed',
  'authMode',
  'subBlocks',
  'tools',
  'inputs',
  'outputs',
  'triggers',
  'canvasPresentation',
  r'$meta',
};

const _subBlockTyped = {
  'id',
  'type',
  'title',
  'mode',
  'canonicalParamId',
  'placeholder',
  'condition',
  'required',
  'options',
  'dependsOn',
  'defaultValue',
  'hidden',
  'password',
  'selectorKey',
  'wandConfig',
};

String _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  return value is String ? dartString(value) : 'null';
}

String _bool(Map<String, Object?> map, String key) =>
    map[key] == true ? 'true' : 'false';

Map<String, Object?> _rest(Map<String, Object?> map, Set<String> typed) {
  final rest = <String, Object?>{};
  for (final entry in map.entries) {
    if (!typed.contains(entry.key)) rest[entry.key] = entry.value;
  }
  return rest;
}

String _subBlock(Map<String, Object?> sub, String indent) {
  final inner = '$indent  ';
  final buffer = StringBuffer('SubBlockData(\n');
  buffer.writeln('${inner}id: ${dartString(sub['id']! as String)},');
  buffer.writeln(
    '${inner}type: ${dartString(sub['type'] as String? ?? 'short-input')},',
  );
  buffer.writeln('${inner}title: ${_optionalString(sub, 'title')},');
  buffer.writeln('${inner}mode: ${_optionalString(sub, 'mode')},');
  buffer.writeln(
    '${inner}canonicalParamId: ${_optionalString(sub, 'canonicalParamId')},',
  );
  buffer.writeln(
    '${inner}placeholder: ${_optionalString(sub, 'placeholder')},',
  );
  buffer.writeln(
    '${inner}condition: ${dartLiteral(sub['condition'], indent: inner)},',
  );
  buffer.writeln(
    '${inner}required: ${dartLiteral(sub['required'], indent: inner)},',
  );
  buffer.writeln(
    '${inner}options: ${dartLiteral(sub['options'], indent: inner)},',
  );
  buffer.writeln(
    '${inner}dependsOn: ${dartLiteral(sub['dependsOn'], indent: inner)},',
  );
  buffer.writeln(
    '${inner}defaultValue: ${dartLiteral(sub['defaultValue'], indent: inner)},',
  );
  buffer.writeln('${inner}hidden: ${_bool(sub, 'hidden')},');
  buffer.writeln('${inner}password: ${_bool(sub, 'password')},');
  buffer.writeln(
    '${inner}selectorKey: ${_optionalString(sub, 'selectorKey')},',
  );
  buffer.writeln(
    '${inner}wandConfig: ${dartLiteral(sub['wandConfig'], indent: inner)},',
  );
  buffer.writeln(
    '${inner}extra: ${dartLiteral(_rest(sub, _subBlockTyped), indent: inner)},',
  );
  buffer.write('$indent)');
  return buffer.toString();
}

String _block(Map<String, Object?> block, String indent) {
  final inner = '$indent  ';
  final tools = block['tools'] as Map<String, Object?>? ?? const {};
  final config = tools['config'] as Map<String, Object?>? ?? const {};
  final access = (tools['access'] as List<Object?>? ?? const []).cast<String>();
  final subBlocks = (block['subBlocks'] as List<Object?>? ?? const [])
      .cast<Map<String, Object?>>();
  final icon = block['icon'];
  final buffer = StringBuffer('BlockData(\n');
  buffer.writeln('${inner}type: ${dartString(block['type']! as String)},');
  buffer.writeln(
    '${inner}name: ${dartString(block['name'] as String? ?? '')},',
  );
  buffer.writeln(
    '${inner}category: ${dartString(block['category'] as String? ?? 'blocks')},',
  );
  buffer.writeln(
    '${inner}description: ${_optionalString(block, 'description')},',
  );
  buffer.writeln(
    '${inner}longDescription: ${_optionalString(block, 'longDescription')},',
  );
  buffer.writeln('${inner}bgColor: ${_optionalString(block, 'bgColor')},');
  buffer.writeln(
    '${inner}icon: ${icon is Map ? (markerLiteral(icon) ?? 'null') : 'null'},',
  );
  buffer.writeln('${inner}docsLink: ${_optionalString(block, 'docsLink')},');
  buffer.writeln(
    '${inner}hideFromToolbar: ${_bool(block, 'hideFromToolbar')},',
  );
  buffer.writeln('${inner}preview: ${_bool(block, 'preview')},');
  buffer.writeln('${inner}triggerAllowed: ${_bool(block, 'triggerAllowed')},');
  buffer.writeln('${inner}authMode: ${_optionalString(block, 'authMode')},');
  buffer.writeln(
    '${inner}toolAccess: ${dartStringList(access, indent: inner)},',
  );
  buffer.writeln(
    '${inner}toolSelector: ${isFnMarker(config['tool']) ? markerLiteral(config['tool']! as Map) : 'null'},',
  );
  buffer.writeln(
    '${inner}toolParams: ${isFnMarker(config['params']) ? markerLiteral(config['params']! as Map) : 'null'},',
  );
  buffer.writeln(
    '${inner}inputs: ${dartLiteral(block['inputs'] ?? const <String, Object?>{}, indent: inner)},',
  );
  buffer.writeln(
    '${inner}outputs: ${dartLiteral(block['outputs'] ?? const <String, Object?>{}, indent: inner)},',
  );
  buffer.writeln(
    '${inner}triggers: ${dartLiteral(block['triggers'], indent: inner)},',
  );
  buffer.writeln(
    '${inner}canvasPresentation: ${dartLiteral(block['canvasPresentation'], indent: inner)},',
  );
  buffer.writeln(
    '${inner}meta: ${dartLiteral(block[r'$meta'], indent: inner)},',
  );
  buffer.writeln('${inner}subBlocks: <SubBlockData>[');
  for (final sub in subBlocks) {
    buffer.writeln('$inner  ${_subBlock(sub, '$inner  ')},');
  }
  buffer.writeln('$inner],');
  buffer.writeln(
    '${inner}extra: ${dartLiteral(_rest(block, _blockTyped), indent: inner)},',
  );
  buffer.write('$indent)');
  return buffer.toString();
}

/// Generates the source of `blocks.g.dart` from decoded `blocks.json`.
String generateBlocks(Map<String, Object?> blocks, String commit) {
  final buffer = StringBuffer(generatedHeader(commit, 'blocks.json'));
  buffer.writeln("import 'markers.g.dart';");
  buffer.writeln();
  buffer.writeln('''
/// One `SubBlockConfig` from the upstream block registry.
///
/// `condition`, `required` and `options` hold the upstream JSON shape (a map,
/// a bool, a list of option maps) or an [FnRef] when upstream used a function;
/// every field not modelled here is in [extra] under its upstream key.
class SubBlockData {
  const SubBlockData({
    required this.id,
    required this.type,
    required this.extra,
    this.title,
    this.mode,
    this.canonicalParamId,
    this.placeholder,
    this.condition,
    this.required,
    this.options,
    this.dependsOn,
    this.defaultValue,
    this.hidden = false,
    this.password = false,
    this.selectorKey,
    this.wandConfig,
  });

  final String id;
  final String type;
  final String? title;
  final String? mode;
  final String? canonicalParamId;
  final String? placeholder;
  final Object? condition;
  final Object? required;
  final Object? options;
  final Object? dependsOn;
  final Object? defaultValue;
  final bool hidden;
  final bool password;
  final String? selectorKey;
  final Object? wandConfig;
  final Map<String, Object?> extra;
}

/// One `BlockConfig` from `apps/sim/blocks/registry-maps.ts`.
class BlockData {
  const BlockData({
    required this.type,
    required this.name,
    required this.category,
    required this.subBlocks,
    required this.toolAccess,
    required this.inputs,
    required this.outputs,
    required this.extra,
    this.description,
    this.longDescription,
    this.bgColor,
    this.icon,
    this.docsLink,
    this.hideFromToolbar = false,
    this.preview = false,
    this.triggerAllowed = false,
    this.authMode,
    this.toolSelector,
    this.toolParams,
    this.triggers,
    this.canvasPresentation,
    this.meta,
  });

  final String type;
  final String name;
  final String category;
  final String? description;
  final String? longDescription;
  final String? bgColor;
  final IconRef? icon;
  final String? docsLink;
  final bool hideFromToolbar;
  final bool preview;
  final bool triggerAllowed;
  final String? authMode;
  final List<SubBlockData> subBlocks;
  final List<String> toolAccess;
  final FnRef? toolSelector;
  final FnRef? toolParams;
  final Map<String, Object?> inputs;
  final Map<String, Object?> outputs;
  final Object? triggers;
  final Object? canvasPresentation;
  final Object? meta;
  final Map<String, Object?> extra;
}

/// Lookup over the generated registry, keyed by block type.
class BlockRegistryData {
  const BlockRegistryData._();

  static BlockData? byType(String type) => blocks[type];

  static const List<String> types = <String>[''');
  final types = blocks.keys.toList()..sort();
  for (final type in types) {
    buffer.writeln('    ${dartString(type)},');
  }
  buffer.writeln('  ];');
  buffer.writeln();
  buffer.writeln(
    '  static const Map<String, BlockData> blocks = <String, BlockData>{',
  );
  for (final type in types) {
    final block = blocks[type]! as Map<String, Object?>;
    buffer.writeln('    ${dartString(type)}: ${_block(block, '    ')},');
  }
  buffer.writeln('  };');
  buffer.writeln('}');
  return buffer.toString();
}

/// Generates `markers.g.dart`, the marker classes shared by every generated file.
String generateMarkers(String commit) {
  final buffer = StringBuffer(generatedHeader(commit, 'manifest.json'));
  buffer.writeln(r'''
/// A function-valued upstream field that has no static representation.
///
/// [id] is `<owner>.<path>`, the key into `closures.json`; the Dart port keyed
/// on it lives in the workflow package.
class FnRef {
  const FnRef(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is FnRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FnRef($id)';
}

/// An icon component reference: `<set>/<name>`, the key into `icons.g.dart`.
class IconRef {
  const IconRef(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is IconRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'IconRef($id)';
}

/// A JavaScript regular expression literal that appeared in a config value.
class RegexRef {
  const RegexRef(this.source, this.flags);

  final String source;
  final String flags;

  @override
  String toString() => 'RegexRef(/$source/$flags)';
}''');
  return buffer.toString();
}

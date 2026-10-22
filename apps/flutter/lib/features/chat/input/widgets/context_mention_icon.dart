import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_design/sim_design.dart';

/// `getDocumentIcon(mimeType, filename)` (`components/icons/document-icons.tsx`).
SimIconData documentIcon(String mimeType, String filename) {
  final mime = mimeType.split(';').first.trim().toLowerCase();
  final dot = filename.lastIndexOf('.');
  final ext = dot == -1 ? '' : filename.substring(dot + 1).toLowerCase();
  const audio = {'mp3', 'm4a', 'wav', 'webm', 'ogg', 'flac', 'aac', 'opus'};
  const video = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
  if (mime.startsWith('audio/') || audio.contains(ext)) {
    return SimEmcnIcons.audioIcon;
  }
  if (mime.startsWith('video/') || video.contains(ext)) {
    return SimEmcnIcons.videoIcon;
  }
  if (mime == 'application/pdf' || ext == 'pdf') return SimEmcnIcons.pdfIcon;
  if (mime ==
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
      mime == 'application/msword' ||
      ext == 'docx' ||
      ext == 'doc') {
    return SimEmcnIcons.docxIcon;
  }
  if (mime ==
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      mime == 'application/vnd.ms-excel' ||
      ext == 'xlsx' ||
      ext == 'xls') {
    return SimEmcnIcons.xlsxIcon;
  }
  if (mime == 'text/csv' || ext == 'csv') return SimEmcnIcons.csvIcon;
  if (mime == 'text/plain' || ext == 'txt') return SimEmcnIcons.txtIcon;
  if (mime ==
          'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
      mime == 'application/vnd.ms-powerpoint' ||
      ext == 'pptx' ||
      ext == 'ppt') {
    return SimEmcnIcons.pptxIcon;
  }
  if (mime == 'application/zip' ||
      mime == 'application/x-zip-compressed' ||
      ext == 'zip') {
    return SimEmcnIcons.zipIcon;
  }
  if (mime == 'text/x-sim-chart' || ext == 'chart') {
    return SimEmcnIcons.chartFileIcon;
  }
  if (mime == 'text/x-sim-page') return SimEmcnIcons.defaultFileIcon;
  if (mime == 'text/html' || ext == 'html' || ext == 'htm') {
    return SimEmcnIcons.htmlIcon;
  }
  if (mime == 'application/json' || ext == 'json') {
    return SimEmcnIcons.jsonIcon;
  }
  if (mime == 'text/markdown' || ext == 'md' || ext == 'mdx') {
    return SimEmcnIcons.markdownIcon;
  }
  return SimEmcnIcons.defaultFileIcon;
}

/// `ContextMentionIcon` (`CHAT_CONTEXT_KIND_REGISTRY[kind].renderIcon`), or
/// `null` for kinds without an icon (`blocks`, `docs`, `slash_command`).
/// Integration brand icons are not bundled; integrations use the generic
/// integration glyph (known gap).
Widget? contextMentionIcon(
  ChatContext context, {
  double size = 12,
  Color? color,
}) {
  SimIconData? icon;
  switch (context.kind) {
    case ChatContextKind.browserTab:
      icon = SimEmcnIcons.globe;
    case ChatContextKind.terminalTab:
      icon = SimEmcnIcons.terminalWindow;
    case ChatContextKind.workflow:
    case ChatContextKind.currentWorkflow:
    case ChatContextKind.workflowBlock:
      icon = SimEmcnIcons.workflow;
    case ChatContextKind.knowledge:
      icon = SimEmcnIcons.database;
    case ChatContextKind.table:
    case ChatContextKind.tableSelection:
      icon = SimEmcnIcons.table;
    case ChatContextKind.dashboard:
      icon = SimEmcnIcons.dashboard;
    case ChatContextKind.file:
      icon = documentIcon('', context.label);
    case ChatContextKind.fileSelection:
      icon = documentIcon('', context.field('fileName') ?? context.label);
    case ChatContextKind.folder:
    case ChatContextKind.filefolder:
    case ChatContextKind.project:
      icon = SimEmcnIcons.folder;
    case ChatContextKind.workspace:
      icon = SimEmcnIcons.workspaces;
    case ChatContextKind.pastChat:
      icon = SimEmcnIcons.task;
    case ChatContextKind.logs:
      icon = SimEmcnIcons.library;
    case ChatContextKind.integration:
      icon = SimEmcnIcons.integration;
    case ChatContextKind.skill:
      return AgentSkillsIcon(size: size, color: color);
    case ChatContextKind.mcp:
      return McpIcon(size: size, color: color);
    case ChatContextKind.blocks:
    case ChatContextKind.docs:
    case ChatContextKind.slashCommand:
      return null;
  }
  return SimIcon(icon, size: size, color: color);
}

/// `AgentSkillsIcon` (`components/icons.tsx`): an outlined hexagon (stroke
/// 1.5) around a filled one, 16-unit viewBox, `currentColor`.
class AgentSkillsIcon extends StatelessWidget {
  const AgentSkillsIcon({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SvgPathPainter(
      color: color ?? SimTheme.of(context).colors.textIcon,
      strokes: const [('M8 1L14.06 4.5V11.5L8 15L1.94 11.5V4.5L8 1Z', 1.5)],
      fills: const ['M8 4.5L11 6.25V9.75L8 11.5L5 9.75V6.25L8 4.5Z'],
    ),
  );
}

/// `McpIcon` (`components/icons.tsx`), 16-unit viewBox, even-odd fill.
class McpIcon extends StatelessWidget {
  const McpIcon({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  static const String _path =
      'M14.56 7.88L14.5 7.93L8.7 13.62C8.68 13.64 8.67 13.66 8.66 13.68C8.65 13.7 8.64 13.72 8.64 13.75C8.64 13.77 8.65 13.8 8.66 13.82C8.67 13.84 8.68 13.86 8.7 13.88L8.7 13.88L9.89 15.05C9.99 15.15 10.05 15.29 10.06 15.44C10.06 15.58 10 15.72 9.9 15.83L9.89 15.84C9.78 15.94 9.64 16 9.49 16C9.34 16 9.2 15.94 9.09 15.84L7.9 14.67C7.77 14.55 7.68 14.41 7.61 14.25C7.54 14.09 7.51 13.92 7.51 13.75C7.51 13.58 7.54 13.41 7.61 13.25C7.68 13.1 7.77 12.95 7.9 12.83L13.7 7.14C14.01 6.84 14.19 6.42 14.2 5.98C14.2 5.55 14.04 5.13 13.73 4.81L13.7 4.78L13.67 4.75C13.35 4.44 12.91 4.26 12.47 4.26C12.02 4.26 11.58 4.44 11.26 4.75L6.48 9.44H6.48L6.41 9.5C6.31 9.61 6.16 9.67 6.01 9.67C5.86 9.67 5.72 9.61 5.61 9.5C5.51 9.4 5.45 9.26 5.45 9.12C5.44 8.97 5.5 8.83 5.6 8.73L5.61 8.72L10.46 3.96C11.11 3.32 11.12 2.28 10.49 1.63L10.46 1.6C10.14 1.29 9.7 1.11 9.25 1.11C8.81 1.11 8.37 1.29 8.05 1.6L1.64 7.9C1.53 8 1.38 8.06 1.23 8.06C1.08 8.06 0.94 8 0.83 7.9C0.73 7.79 0.67 7.66 0.67 7.51C0.67 7.36 0.72 7.22 0.82 7.12L0.83 7.11L7.25 0.81C7.79 0.29 8.51 0 9.26 0C10 0 10.72 0.29 11.26 0.81C11.89 1.43 12.19 2.3 12.06 3.17C12.94 3.05 13.83 3.34 14.47 3.96L14.5 3.99C14.76 4.25 14.97 4.54 15.11 4.88C15.25 5.21 15.33 5.56 15.33 5.92C15.34 6.28 15.27 6.64 15.14 6.98C15.01 7.31 14.81 7.62 14.56 7.87M12.87 6.32C12.97 6.22 13.03 6.08 13.03 5.94C13.03 5.79 12.98 5.65 12.88 5.55L12.87 5.54C12.76 5.43 12.61 5.37 12.46 5.37C12.31 5.37 12.17 5.43 12.06 5.54L7.32 10.19C7 10.5 6.56 10.68 6.11 10.68C5.66 10.68 5.23 10.5 4.91 10.19C4.76 10.04 4.63 9.86 4.55 9.66C4.46 9.46 4.42 9.25 4.41 9.03C4.41 8.81 4.45 8.6 4.53 8.4C4.61 8.2 4.73 8.01 4.88 7.86L4.91 7.83L9.66 3.17C9.76 3.07 9.82 2.93 9.82 2.79C9.83 2.64 9.77 2.5 9.67 2.4L9.66 2.39C9.55 2.28 9.41 2.22 9.26 2.22C9.11 2.22 8.96 2.28 8.86 2.39L4.11 7.04C3.85 7.3 3.64 7.6 3.49 7.94C3.35 8.28 3.28 8.64 3.28 9.01C3.28 9.38 3.35 9.74 3.49 10.08C3.64 10.41 3.85 10.72 4.11 10.98C4.65 11.5 5.36 11.79 6.11 11.79C6.86 11.79 7.58 11.5 8.12 10.98L12.87 6.32Z';

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SvgPathPainter(
      color: color ?? SimTheme.of(context).colors.textIcon,
      fills: const [_path],
      evenOdd: true,
    ),
  );
}

/// Absolute `M L H V C Z` path data (all the two icons above use).
Path parseSvgPath(String data) {
  final path = Path();
  final tokens = RegExp(
    r'[MLHVCZmlhvcz]|-?\d*\.?\d+(?:e-?\d+)?',
  ).allMatches(data).map((m) => m[0]!).toList();
  var i = 0;
  var command = 'M';
  var x = 0.0;
  var y = 0.0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final token = tokens[i];
    if (RegExp('[A-Za-z]').hasMatch(token)) {
      command = token;
      i++;
      if (command == 'Z' || command == 'z') {
        path.close();
        continue;
      }
    }
    switch (command) {
      case 'M':
        x = next();
        y = next();
        path.moveTo(x, y);
        command = 'L';
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'C':
        final x1 = next();
        final y1 = next();
        final x2 = next();
        final y2 = next();
        x = next();
        y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
      default:
        i++;
    }
  }
  return path;
}

class _SvgPathPainter extends CustomPainter {
  const _SvgPathPainter({
    required this.color,
    this.strokes = const [],
    this.fills = const [],
    this.evenOdd = false,
  });

  final Color color;
  final List<(String, double)> strokes;
  final List<String> fills;
  final bool evenOdd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 16, size.height / 16);
    for (final fill in fills) {
      final path = parseSvgPath(fill)
        ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
      canvas.drawPath(path, Paint()..color = color);
    }
    for (final (data, width) in strokes) {
      canvas.drawPath(
        parseSvgPath(data),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SvgPathPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fills != fills ||
      oldDelegate.strokes != strokes;
}

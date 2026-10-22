import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/input/composer_attachments.dart';
import 'package:sim_app/features/chat/input/widgets/context_mention_icon.dart';
import 'package:sim_design/sim_design.dart';

/// `AttachedFilesList`: 48px media thumbnails and 48px-tall file cards
/// (max min(220px, 100%)) wrapping with a 6px gap, 6px above the editor.
class AttachedFilesList extends StatelessWidget {
  const AttachedFilesList({
    required this.attachments,
    required this.onOpen,
    required this.onRemove,
    super.key,
    this.resolveUrl,
  });

  final List<ComposerAttachment> attachments;
  final ValueChanged<ComposerAttachment> onOpen;
  final ValueChanged<String> onRemove;

  /// Resolves an app-relative preview path to a loadable URL (null: no
  /// network previews, the type icon stays).
  final String Function(String path)? resolveUrl;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      identifier: 'chat-input.attachments',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < attachments.length; i++)
                _AttachmentCard(
                  file: attachments[i],
                  first: i == 0,
                  maxWidth: math.min(220, constraints.maxWidth),
                  onOpen: onOpen,
                  onRemove: onRemove,
                  resolveUrl: resolveUrl,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentCard extends StatefulWidget {
  const _AttachmentCard({
    required this.file,
    required this.first,
    required this.maxWidth,
    required this.onOpen,
    required this.onRemove,
    required this.resolveUrl,
  });

  final ComposerAttachment file;
  final bool first;
  final double maxWidth;
  final ValueChanged<ComposerAttachment> onOpen;
  final ValueChanged<String> onRemove;
  final String Function(String path)? resolveUrl;

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  bool _hovered = false;
  bool _previewFailed = false;

  Widget? _preview() {
    if (_previewFailed) return null;
    final file = widget.file;
    if (!file.isImage) return null;
    final bytes = file.previewBytes;
    Widget error(BuildContext _, Object _, StackTrace? _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _previewFailed = true);
      });
      return const SizedBox.shrink();
    }

    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: error,
      );
    }
    final url = file.previewUrl;
    final resolve = widget.resolveUrl;
    if (url == null || resolve == null) return null;
    return Image.network(resolve(url), fit: BoxFit.cover, errorBuilder: error);
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final file = widget.file;
    final icon = documentIcon(file.type, file.name);
    final fill = _hovered
        ? (sim.isDark ? c.surface6 : c.surfaceActive)
        : c.surface5;
    final decoration = BoxDecoration(
      color: fill,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(SimRadii.lg),
    );
    final ext = fileExtension(file.name);
    Widget card;
    if (file.isMedia) {
      final preview = _preview();
      card = Container(
        width: 48,
        height: 48,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: SimIcon(icon, size: 18, color: c.textIcon)),
            ?preview,
          ],
        ),
      );
    } else {
      card = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 8, right: 20, top: 7, bottom: 7),
          decoration: decoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: sim.isDark ? c.surface3 : c.surface7,
                  borderRadius: BorderRadius.circular(SimRadii.md),
                ),
                alignment: Alignment.center,
                child: SimIcon(icon, size: 16, color: c.textIcon),
              ),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sim.text.small.copyWith(
                        color: c.textBody,
                        height: 1.25,
                      ),
                    ),
                    if (ext.isNotEmpty)
                      Text(
                        ext.toUpperCase(),
                        maxLines: 1,
                        style: sim.text.caption.copyWith(
                          color: c.textIcon,
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (file.uploading) {
      card = Stack(
        children: [
          card,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: (sim.isDark ? c.surface4 : c.surface5).withValues(
                  alpha: 0.7,
                ),
                borderRadius: BorderRadius.circular(SimRadii.lg),
              ),
              child: Center(child: SimSpinner(color: c.textIcon)),
            ),
          ),
        ],
      );
    }
    final label = file.isImage && !_previewFailed
        ? 'Preview ${file.name}'
        : 'Open ${file.name}';
    return Semantics(
      container: true,
      identifier: widget.first ? 'chat-input.attachment' : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Semantics(
              button: true,
              label: label,
              child: GestureDetector(
                onTap: () => widget.onOpen(file),
                child: card,
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Visibility(
                visible: !file.uploading,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Semantics(
                  container: true,
                  identifier: widget.first
                      ? 'chat-input.attachment.remove'
                      : null,
                  button: true,
                  label: 'Remove ${file.name}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: file.uploading
                        ? null
                        : () => widget.onRemove(file.id),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.surface2,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      alignment: Alignment.center,
                      child: SimIcon(SimIcons.x, size: 10, color: c.textBody),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

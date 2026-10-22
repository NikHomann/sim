import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/platform/sidebar_browser.dart';
import 'package:sim_design/sim_design.dart';

/// `MAX_FILE_SIZE` of `help-modal.tsx` (20 MB).
const int helpMaxImageBytes = 20 * 1024 * 1024;

/// `ACCEPTED_IMAGE_TYPES`.
const List<String> helpAcceptedImageTypes = <String>[
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
];

/// `SUCCESS_RESET_DELAY_MS`.
const Duration helpSuccessResetDelay = Duration(milliseconds: 2000);

/// The submit status label of the footer.
enum HelpSubmitStatus { idle, submitting, error, success }

/// Form state and rules of the Contact support modal (`help-modal.tsx`):
/// zod validation on submit (subject and message required), image intake
/// (a batch is dropped whole when any file is over 20 MB or not an
/// accepted type), the multipart `POST /api/help`, the "Success" label
/// reset after 2 s with the form cleared, "Error" on failure.
class HelpFormController extends ChangeNotifier {
  HelpFormController({
    required this.submitRequest,
    required this.userAgent,
    this.workspaceId,
    this.workflowId,
  });

  final Future<void> Function(HelpRequest request) submitRequest;
  final String userAgent;
  final String? workspaceId;
  final String? workflowId;

  final TextEditingController subject = TextEditingController();
  final TextEditingController message = TextEditingController();
  HelpRequestType type = HelpRequestType.bug;
  final List<PickedFile> images = <PickedFile>[];
  String? subjectError;
  String? messageError;
  HelpSubmitStatus status = HelpSubmitStatus.idle;
  Timer? _successTimer;
  bool _disposed = false;

  bool get isSubmitting => status == HelpSubmitStatus.submitting;

  String get submitLabel => switch (status) {
    HelpSubmitStatus.submitting => 'Submitting...',
    HelpSubmitStatus.error => 'Error',
    HelpSubmitStatus.success => 'Success',
    HelpSubmitStatus.idle => 'Submit',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setType(HelpRequestType value) {
    type = value;
    _notify();
  }

  /// `processFiles`: all-or-nothing intake of a picked batch.
  void addImages(List<PickedFile> files) {
    if (files.isEmpty) return;
    final valid = files.every(
      (f) =>
          f.size <= helpMaxImageBytes &&
          helpAcceptedImageTypes.contains(f.mimeType),
    );
    if (!valid) return;
    images.addAll(files);
    _notify();
  }

  void removeImage(int index) {
    images.removeAt(index);
    _notify();
  }

  /// Validates and posts; returns whether the request went out and
  /// succeeded.
  Future<bool> submit() async {
    if (isSubmitting) return false;
    final subjectText = subject.text.trim();
    final messageText = message.text.trim();
    subjectError = subjectText.isEmpty ? 'Subject is required' : null;
    messageError = messageText.isEmpty ? 'Message is required' : null;
    if (subjectError != null || messageError != null) {
      _notify();
      return false;
    }
    status = HelpSubmitStatus.submitting;
    _notify();
    try {
      await submitRequest(
        HelpRequest(
          subject: subjectText,
          message: messageText,
          type: type,
          userAgent: userAgent,
          workspaceId: workspaceId,
          workflowId: workflowId,
          images: <HelpImage>[
            for (final image in images)
              HelpImage(
                filename: image.name,
                bytes: image.bytes,
                contentType: image.mimeType,
              ),
          ],
        ),
      );
      if (_disposed) return true;
      status = HelpSubmitStatus.success;
      subject.clear();
      message.clear();
      type = HelpRequestType.bug;
      images.clear();
      _successTimer?.cancel();
      _successTimer = Timer(helpSuccessResetDelay, () {
        status = HelpSubmitStatus.idle;
        _notify();
      });
      _notify();
      return true;
    } on Object catch (error) {
      developer.log('Help request failed', name: 'sim_app.help', error: error);
      if (_disposed) return false;
      status = HelpSubmitStatus.error;
      _notify();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _successTimer?.cancel();
    subject.dispose();
    message.dispose();
    super.dispose();
  }
}

const List<SimChipDropdownOption> _requestTypes = <SimChipDropdownOption>[
  SimChipDropdownOption(value: 'bug', label: 'Bug report'),
  SimChipDropdownOption(value: 'feedback', label: 'Feedback'),
  SimChipDropdownOption(value: 'feature_request', label: 'Feature request'),
  SimChipDropdownOption(value: 'other', label: 'Other'),
];

/// Opens the Contact support modal (`ChipModal size='md'`, 500px).
Future<void> showHelpModal(
  BuildContext context, {
  required HelpRepository? repository,
  required String? workspaceId,
  required String? workflowId,
  SidebarBrowser browser = const SidebarBrowser(),
}) {
  final controller = HelpFormController(
    submitRequest: (request) async {
      if (repository == null) throw StateError('No help repository');
      await repository.submit(request);
    },
    userAgent: browser.userAgent,
    workspaceId: workspaceId,
    workflowId: workflowId,
  );
  return showSimChipModal<void>(
    context,
    semanticsLabel: 'Contact support',
    dismissDisabled: () => false,
    builder: (context) => Parity(
      'shell.sidebar.help-modal',
      child: HelpModalContent(controller: controller, browser: browser),
    ),
  ).whenComplete(controller.dispose);
}

/// The modal body: header, Request / Subject / Message / Attach images
/// fields, image previews, and the Cancel + Submit footer.
class HelpModalContent extends StatelessWidget {
  const HelpModalContent({
    required this.controller,
    super.key,
    this.browser = const SidebarBrowser(),
  });

  final HelpFormController controller;
  final SidebarBrowser browser;

  Future<void> _pick() async {
    final files = await browser.pickFiles(
      accept: helpAcceptedImageTypes.join(','),
      multiple: true,
    );
    controller.addImages(files);
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final modal = SimModalScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SimChipModalHeader(title: 'Contact support', onClose: modal.close),
          SimChipModalBody(
            children: <Widget>[
              SimChipModalField.dropdown(
                title: 'Request',
                options: _requestTypes,
                value: controller.type.wireName,
                placeholder: 'Select a request type',
                onChanged: (value) => controller.setType(
                  HelpRequestType.values.firstWhere(
                    (t) => t.wireName == value,
                  ),
                ),
              ),
              SimChipModalField.input(
                title: 'Subject',
                controller: controller.subject,
                placeholder: 'Brief description of your request',
                error: controller.subjectError,
              ),
              SimChipModalField.textarea(
                title: 'Message',
                controller: controller.message,
                placeholder: 'Please provide details about your request...',
                rows: 6,
                error: controller.messageError,
              ),
              SimChipModalField(
                title: 'Attach images (optional)',
                child: _DropZone(onPressed: () => unawaited(_pick())),
              ),
              if (controller.images.isNotEmpty)
                SimChipModalField(
                  title: 'Uploaded images',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (final (i, image) in controller.images.indexed)
                        _ImagePreview(
                          image: image,
                          onRemove: () => controller.removeImage(i),
                          border: c.border,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          SimChipModalFooter(
            onCancel: modal.close,
            cancelEnabled: !controller.isSubmitting,
            primaryAction: SimChipModalAction(
              label: controller.submitLabel,
              enabled: !controller.isSubmitting,
              onPressed: () => unawaited(controller.submit()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return SimPressable(
      semanticsLabel: 'Drop images here or click to browse',
      onPressed: onPressed,
      builder: (context, state) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: state.hovered ? c.surfaceHover : SimChipChrome.filledFill(c),
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.lg),
        ),
        child: Column(
          spacing: 4,
          children: <Widget>[
            SimIcon(SimEmcnIcons.upload, size: 16, color: c.textIcon),
            Text(
              'Drop images here or click to browse',
              style: sim.text.small.copyWith(color: c.textBody),
            ),
            Text(
              'PNG, JPEG, WebP, GIF (max 20MB each)',
              style: sim.text.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({
    required this.image,
    required this.onRemove,
    required this.border,
  });

  final PickedFile image;
  final VoidCallback onRemove;
  final Color border;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return SizedBox(
      width: 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: widget.border),
          borderRadius: BorderRadius.circular(SimRadii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 80,
                  maxHeight: 120,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Image.memory(
                      Uint8List.fromList(widget.image.bytes),
                      fit: BoxFit.contain,
                    ),
                    if (_hovered)
                      Positioned.fill(
                        child: SimPressable(
                          semanticsLabel: 'Remove image',
                          onPressed: widget.onRemove,
                          builder: (context, _) => const ColoredBox(
                            color: Color(0x80000000),
                            child: Center(
                              child: SimIcon(
                                SimEmcnIcons.x,
                                size: 18,
                                color: SimColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                widget.image.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sim.text.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

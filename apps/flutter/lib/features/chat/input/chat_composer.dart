import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/input/composer_attachments.dart';
import 'package:sim_app/features/chat/input/composer_context_source.dart';
import 'package:sim_app/features/chat/input/composer_controller.dart';
import 'package:sim_app/features/chat/input/composer_drafts.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/chip_clipboard_codec.dart';
import 'package:sim_app/features/chat/input/model/composer_models.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';
import 'package:sim_app/features/chat/input/platform/composer_platform.dart';
import 'package:sim_app/features/chat/input/widgets/animated_placeholder.dart';
import 'package:sim_app/features/chat/input/widgets/attached_files_list.dart';
import 'package:sim_app/features/chat/input/widgets/caret_menus.dart';
import 'package:sim_app/features/chat/input/widgets/composer_toolbar.dart';
import 'package:sim_app/features/chat/input/widgets/context_mention_icon.dart';
import 'package:sim_app/features/chat/input/widgets/drop_overlay.dart';
import 'package:sim_app/features/chat/input/widgets/prompt_editor.dart';
import 'package:sim_app/features/workspace_shell/chrome/paste_admission_guard.dart'
    show PasteLimit;
import 'package:sim_design/sim_design.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:sim_app/features/chat/input/composer_attachments.dart'
    show ComposerAttachment, ComposerUploader, HttpComposerUploader;
export 'package:sim_app/features/chat/input/composer_context_source.dart';
export 'package:sim_app/features/chat/input/composer_controller.dart'
    show ComposerController;
export 'package:sim_app/features/chat/input/composer_drafts.dart'
    show ComposerDraft, ComposerDraftStore;
export 'package:sim_app/features/chat/input/model/chat_context.dart';
export 'package:sim_app/features/chat/input/model/composer_models.dart';
export 'package:sim_app/features/chat/input/model/composer_resources.dart';
export 'package:sim_app/features/chat/input/platform/composer_platform.dart'
    show ComposerPickedFile;

/// The `md` breakpoint of `isMobileViewport()` (`width < 768px`).
const double touchMobileBreakpoint = 768;

/// A drag payload of in-app resources dropped on the composer
/// (`application/x-sim-resource[s]` upstream): inserted as chips.
@immutable
class ComposerResourceDrag {
  const ComposerResourceDrag(this.resources);

  final List<ComposerResource> resources;
}

/// The host's handle on a mounted [ChatComposer] (`UserInputHandle` plus the
/// editor inserts other surfaces use).
class ChatComposerController {
  ChatComposerController({String text = ''})
    : editor = ComposerController(text: text);

  /// The text, contexts and editing rules.
  final ComposerController editor;
  _ChatComposerState? _state;

  /// `loadQueuedMessage`: text, chips and attachments of a queued message,
  /// focused with the caret at the end.
  void loadQueuedMessage(ComposerQueuedMessage message) {
    editor
      ..setText(message.content)
      ..contexts = message.contexts;
    _state?._attachments.restore(message.fileAttachments);
    _state?._focusAtEnd();
  }

  /// `populatePrompt`: a curated prompt, bare integration names opted into
  /// `@` mentions, focused with the caret at the end; never submits.
  void populatePrompt(String text) {
    editor.setText(editor.mentionifyIntegrations(text));
    _state?._focusAtEnd();
  }

  /// `insertContext`: appends a chip pushed from another surface.
  void appendContext(ChatContext context) {
    editor.appendContext(context);
    _state?._focusAtEnd();
  }

  /// `insertContextChips` (highlight-to-chat) at the caret.
  void insertContextChips(List<ChatContext> contexts) =>
      editor.insertContextChips(contexts);

  /// `insertResources` (drag and drop of resources).
  void insertResources(List<ComposerResource> resources) =>
      editor.insertResources(resources);

  /// Attaches files through the upload pipeline.
  Future<void> addFiles(List<ComposerPickedFile> files) =>
      _state?._attachments.addFiles(files) ?? Future<void>.value();

  void focus() => _state?._focusNode.requestFocus();

  void dispose() => editor.dispose();
}

/// The Mothership chat composer (`UserInput`): prompt editor with inline
/// chips and caret menus, attachments, the toolbar (resources, attach,
/// skills, mode, effort, send/stop), drafts and drag-and-drop.
///
/// Voice input is not offered (the mic stays hidden, as upstream does when
/// `/api/settings/voice` reports it unavailable).
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.workspaceId,
    required this.onSubmit,
    super.key,
    this.chatId,
    this.variant = ComposerVariant.conversation,
    this.controller,
    this.isStreaming = false,
    this.onStop,
    this.onSendQueuedHead,
    this.onEditQueuedTail,
    this.contextSource,
    this.uploader,
    this.draftStore,
    this.mode = ComposerMode.agent,
    this.onModeChange,
    this.planModeEnabled = false,
    this.modelSelectorEnabled = false,
    this.effort,
    this.onEffortChange,
    this.modelSelection,
    this.onModelSelectionChange,
    this.onContextAdd,
    this.onContextRemove,
    this.toasts,
    this.resolveUrl,
    this.autofocus = true,
    this.defaultValue = '',
  });

  final String workspaceId;

  /// The chat the composer belongs to; `null` on a new chat. Keys the draft
  /// (`<ws>:<chatId|new>`) and decides where an effort pick goes.
  final String? chatId;
  final ComposerVariant variant;
  final ChatComposerController? controller;

  /// Text, contexts in the text, uploaded attachments, effort and mode.
  final ValueChanged<ComposerSubmission> onSubmit;

  /// While the engine streams the send button shows Stop.
  final bool isStreaming;
  final VoidCallback? onStop;

  /// Enter on an empty composer while streaming sends the queued head.
  final VoidCallback? onSendQueuedHead;

  /// ArrowUp on an empty composer (no attachments) recalls the queued tail;
  /// the host then calls [ChatComposerController.loadQueuedMessage].
  final VoidCallback? onEditQueuedTail;

  /// Data for the `@` / `+` / `/` menus and auto-mention.
  final ComposerContextSource? contextSource;

  /// The attachment upload pipeline; without one the Attach chip is inert.
  final ComposerUploader? uploader;

  /// Drafts; without one nothing is restored or saved.
  final ComposerDraftStore? draftStore;

  /// Hero only: the conversation mode and its setter (Shift+Tab cycles).
  final ComposerMode mode;
  final ValueChanged<ComposerMode>? onModeChange;

  /// Flag `mothership-plan-mode` (adds Plan).
  final bool planModeEnabled;

  /// Flag `mothership-model-selector` (Model menu, Fast toggle, Max).
  final bool modelSelectorEnabled;

  /// The effort the chat runs at (the engine's pick or the stored chat
  /// effort; the new-chat pick on a new chat); `null` for the default.
  final ComposerEffort? effort;

  /// Records an effort pick: the new-chat pick for a new chat, else
  /// persisted for the chat (`PUT …/effort`); a throw rolls the pick back
  /// with "Couldn't change reasoning effort".
  final Future<void> Function(ComposerEffort effort)? onEffortChange;

  /// Flagged model preference (persisted by the host).
  final ComposerModelSelection? modelSelection;
  final ValueChanged<ComposerModelSelection>? onModelSelectionChange;

  /// A chip added interactively (menu pick, drop, skill) — Home opens its
  /// resource tab; and a context whose last token left the text.
  final ValueChanged<ChatContext>? onContextAdd;
  final void Function(ChatContext context, List<ChatContext> remaining)?
  onContextRemove;

  final SimToasts? toasts;

  /// Turns an app-relative path (`/api/files/serve/…`) into a full URL for
  /// previews and "open" (the app's `SimHttpClient.resolveUrl`).
  final String Function(String path)? resolveUrl;

  /// Focus on mount (desktop, window focused, nothing else editable).
  final bool autofocus;

  /// A seeded value (`defaultValue`); wins over the draft text.
  final String defaultValue;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    implements ComposerClipboardTarget, ComposerDropTarget {
  late ChatComposerController _handle;
  bool _ownsHandle = false;
  late final FocusNode _focusNode = FocusNode(debugLabel: 'chat-input');
  late final ComposerAttachmentsController _attachments;
  late final AnimatedPlaceholderText _placeholder;
  final GlobalKey<PromptEditorState> _editorKey = GlobalKey();
  final GlobalKey _rootKey = GlobalKey();
  final GlobalKey _plusKey = GlobalKey();

  List<ComposerResourceGroup> _groups = const [];
  bool _inventoryRequested = false;
  bool _hydrating = false;
  List<ComposerSkill> _skills = const [];
  List<ComposerMcpServer> _mcpServers = const [];

  DraftAutosave? _autosave;
  bool _draftLoaded = false;

  ComposerEffort? _effortPick;
  bool _dragging = false;
  bool _ownsFocus = false;
  bool _touchMobile = false;
  void Function()? _removeClipboard;
  void Function()? _removeDrop;

  ComposerController get _editor => _handle.editor;
  SimToasts get _toasts => widget.toasts ?? SimToasts.instance;

  String get _draftKey =>
      ComposerDraftStore.draftKey(widget.workspaceId, widget.chatId);

  @override
  void initState() {
    super.initState();
    _handle = widget.controller ?? ChatComposerController();
    _ownsHandle = widget.controller == null;
    _handle._state = this;
    _attachments = ComposerAttachmentsController(
      uploader: widget.uploader,
      onError: (message, description) =>
          _toasts.error(message, description: description),
    )..addListener(_onAttachmentsChanged);
    _placeholder = AnimatedPlaceholderText(
      enabled: widget.variant == ComposerVariant.hero,
    );
    _wireEditor();
    if (widget.defaultValue.isNotEmpty) _editor.setText(widget.defaultValue);
    final store = widget.draftStore;
    if (store != null) {
      _autosave = DraftAutosave(store);
      unawaited(_restoreDraft(store));
    } else {
      _draftLoaded = true;
    }
    unawaited(_loadCatalog());
    _removeClipboard = installComposerClipboard(this);
    if (composerFileDropSupported) _removeDrop = installComposerFileDrop(this);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autofocus());
    }
  }

  void _wireEditor() {
    _editor
      ..addListener(_onEditorChanged)
      ..onSubmit = _handleEnterSubmit
      ..touchMobile = _touchMobile
      ..onArrowUpOnEmpty = _handleArrowUpOnEmpty
      ..onCycleMode = _cycleMode
      ..onContextAdd = ((context) => widget.onContextAdd?.call(context))
      ..onContextRemove = ((context, remaining) =>
          widget.onContextRemove?.call(context, remaining))
      ..onPasteTooLarge = _warnPasteTooLarge
      ..chipIconBuilder = _chipIcon;
  }

  void _unwireEditor() {
    _editor
      ..removeListener(_onEditorChanged)
      ..onSubmit = null
      ..onArrowUpOnEmpty = null
      ..onCycleMode = null
      ..onContextAdd = null
      ..onContextRemove = null
      ..onPasteTooLarge = null
      ..chipIconBuilder = null;
  }

  @override
  void didUpdateWidget(ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        widget.controller != null) {
      _unwireEditor();
      if (_ownsHandle) _handle.dispose();
      _handle = widget.controller!;
      _ownsHandle = false;
      _handle._state = this;
      _wireEditor();
    }
    _attachments.uploader = widget.uploader;
    if (oldWidget.defaultValue != widget.defaultValue &&
        widget.defaultValue.isNotEmpty) {
      _editor.setText(widget.defaultValue);
    }
    if (oldWidget.isStreaming && !widget.isStreaming && _ownsFocus) {
      _focusNode.requestFocus();
    }
    if (oldWidget.workspaceId != widget.workspaceId) {
      _inventoryRequested = false;
      unawaited(_loadCatalog());
    }
  }

  @override
  void dispose() {
    _removeClipboard?.call();
    _removeDrop?.call();
    _autosave?.flush();
    _unwireEditor();
    if (identical(_handle._state, this)) _handle._state = null;
    if (_ownsHandle) _handle.dispose();
    _attachments
      ..removeListener(_onAttachmentsChanged)
      ..dispose();
    _placeholder.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget? _chipIcon(ChatContext context) => contextMentionIcon(
    context,
    color: SimTheme.of(this.context).colors.textIcon,
  );

  void _autofocus() {
    if (!mounted) return;
    final primary = FocusManager.instance.primaryFocus;
    final editable =
        primary?.context?.findAncestorStateOfType<EditableTextState>() != null;
    if (editable && primary != _focusNode) return;
    _focusNode.requestFocus();
  }

  void _focusAtEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _editor.selection = TextSelection.collapsed(offset: _editor.text.length);
    });
  }

  Future<void> _restoreDraft(ComposerDraftStore store) async {
    final draft = await store.read(_draftKey);
    if (!mounted) return;
    _draftLoaded = true;
    if (draft == null) return;
    if (draft.contexts.isNotEmpty) _editor.contexts = draft.contexts;
    if (draft.fileAttachments.isNotEmpty) {
      _attachments.restore(draft.fileAttachments);
    }
    final typedBefore = widget.defaultValue.isEmpty && _editor.text.isNotEmpty;
    if (draft.text.isNotEmpty && !typedBefore) {
      if (widget.defaultValue.isEmpty) _editor.setText(draft.text, seed: true);
      _focusAtEnd();
    }
  }

  Future<void> _loadCatalog() async {
    final source = widget.contextSource;
    if (source == null) return;
    final ws = widget.workspaceId;
    final results = await Future.wait<Object>([
      source.loadSkills(ws),
      source.loadMcpServers(ws),
      source.loadIntegrations(),
    ]);
    if (!mounted || ws != widget.workspaceId) return;
    setState(() {
      _skills = results[0] as List<ComposerSkill>;
      _mcpServers = results[1] as List<ComposerMcpServer>;
    });
    _editor.updateCatalog(
      skills: _skills,
      mcpServers: _mcpServers,
      integrations: results[2] as List<ComposerIntegration>,
    );
  }

  /// Starts the inventory lists (first focus or the `+` menu).
  void _warmInventory() {
    final source = widget.contextSource;
    if (source == null || _inventoryRequested) return;
    _inventoryRequested = true;
    setState(() => _hydrating = true);
    final ws = widget.workspaceId;
    unawaited(
      source
          .loadInventory(ws)
          .then(
            (groups) {
              if (!mounted || ws != widget.workspaceId) return;
              setState(() {
                _groups = groups;
                _hydrating = false;
              });
            },
            onError: (Object _) {
              if (mounted) setState(() => _hydrating = false);
            },
          ),
    );
  }

  void _onEditorChanged() {
    _scheduleDraftSave();
    if (mounted) setState(() {});
  }

  void _onAttachmentsChanged() {
    _scheduleDraftSave();
    if (mounted) setState(() {});
  }

  void _scheduleDraftSave() {
    final autosave = _autosave;
    if (autosave == null || !_draftLoaded) return;
    autosave.schedule(
      _draftKey,
      ComposerDraft(
        text: _editor.text,
        fileAttachments: _attachments.uploaded,
        contexts: _editor.contexts,
      ),
    );
  }

  bool get _canSubmit =>
      (_editor.text.trim().isNotEmpty || _attachments.hasUploaded) &&
      !widget.isStreaming &&
      !_attachments.hasUploading;

  ({ComposerEffort effort, ComposerModelSelection? modelSelection})
  get _modelSettings => resolveModelSettings(
    advanced: widget.modelSelectorEnabled,
    effort: _effortPick ?? widget.effort,
    modelSelection: widget.modelSelection,
    plan: widget.mode == ComposerMode.plan,
  );

  void _clearComposer() {
    _editor.clearComposer();
    _autosave?.cancel();
    final store = widget.draftStore;
    if (store != null) unawaited(store.clear(_draftKey));
    _attachments.clear();
  }

  void _submit() {
    final settings = _modelSettings;
    widget.onSubmit(
      ComposerSubmission(
        text: _editor.plainValue,
        contexts: _editor.activeContexts,
        fileAttachments: _attachments.uploaded,
        effort: settings.effort,
        mode: widget.mode,
        modelSelection: settings.modelSelection,
      ),
    );
    _clearComposer();
  }

  /// Enter policy (`handleEnterSubmit`).
  void _handleEnterSubmit() {
    if (_attachments.hasUploading) return;
    final hasPayload =
        _editor.text.trim().isNotEmpty || _attachments.hasUploaded;
    if (!hasPayload) {
      if (widget.isStreaming) widget.onSendQueuedHead?.call();
      return;
    }
    _submit();
  }

  bool _handleArrowUpOnEmpty() {
    if (_attachments.attachments.isNotEmpty) return false;
    final recall = widget.onEditQueuedTail;
    if (recall == null) return false;
    recall();
    return true;
  }

  List<ComposerMode> get _modes =>
      conversationModes(planEnabled: widget.planModeEnabled);

  bool _cycleMode({required bool repeat}) {
    final onChange = widget.onModeChange;
    final modes = _modes;
    if (onChange == null || modes.length < 2) return false;
    if (repeat) return true;
    final index = modes.indexOf(widget.mode);
    onChange(modes[(index + 1) % modes.length]);
    return true;
  }

  void _warnPasteTooLarge() => _toasts.warning(
    'Paste is too large for a message',
    description:
        'Messages support up to 1,000,000 characters. Attach the content as '
        'a file to send more without slowing the editor.',
  );

  /// One path for every pick: the host's [ChatComposer.onEffortChange]
  /// records it in the engine's effort store (the new-chat pick, in memory)
  /// or persists it for an existing chat (`PUT …/effort`).
  Future<void> _setEffort(ComposerEffort effort) async {
    final previous = _effortPick;
    setState(() => _effortPick = effort);
    final persist = widget.onEffortChange;
    if (persist == null) return;
    try {
      await persist(effort);
    } on Object {
      if (!mounted) return;
      if (_effortPick == effort) setState(() => _effortPick = previous);
      _toasts.error("Couldn't change reasoning effort");
    }
  }

  Future<void> _pickFiles() async {
    if (!composerFilePickerSupported) return;
    final files = await pickComposerFiles(accept: composerAcceptAttribute);
    if (files.isEmpty || !mounted) return;
    await _attachments.addFiles(files);
  }

  void _openPlusMenu() {
    _warmInventory();
    final anchor = _plusKey.currentContext;
    if (anchor == null) return;
    var search = '';
    late final SimMenuHandle handle;
    final c = SimTheme.of(context).colors;
    List<SimMenuEntry> entries() {
      final groups = [
        for (final group in _groups)
          if (group.type != ComposerResourceType.integration &&
              group.items.isNotEmpty)
            group,
      ];
      SimMenuItem row(ComposerResource item) => SimMenuItem(
        label: item.name,
        leading: resourceRowIcon(item, c.textIcon),
        onSelect: () => _editor.insertResource(item),
      );
      final q = search.toLowerCase().trim();
      return [
        SimMenuSearch(
          placeholder: 'Search resources',
          onChanged: (value) {
            search = value;
            handle.rebuild();
          },
        ),
        if (q.isEmpty)
          for (final group in groups)
            SimMenuSub(
              label: group.type.label,
              entries: [for (final item in group.items) row(item)],
            )
        else
          ...() {
            final matches = [
              for (final group in groups)
                for (final item in group.items)
                  if (item.matches(q)) item,
            ];
            if (matches.isEmpty) {
              return <SimMenuEntry>[
                SimMenuCustom(
                  SizedBox(
                    height: SimLayout.menuRowHeight,
                    child: Center(
                      child: Text(
                        'No results',
                        style: SimTheme.of(
                          context,
                        ).text.caption.copyWith(color: c.textMuted),
                      ),
                    ),
                  ),
                ),
              ];
            }
            return <SimMenuEntry>[
              for (var i = 0; i < matches.length; i++) ...[
                if (i == 0 || matches[i - 1].type != matches[i].type)
                  SimMenuLabel(matches[i].type.label),
                row(matches[i]),
              ],
            ];
          }(),
      ];
    }

    handle = SimDropdownMenu.show(
      anchor,
      side: SimSide.top,
      sideOffset: 8,
      width: resourceMenuWidth,
      minWidth: resourceMenuWidth,
      maxWidth: resourceMenuWidth,
      semanticsIdentifier: 'chat-input.plus-menu',
      entries: entries,
      onClose: () {
        if (mounted) _focusNode.requestFocus();
      },
    );
  }

  Future<void> _openAttachment(ComposerAttachment file) async {
    final resolve = widget.resolveUrl;
    final key = file.key;
    final path = key != null
        ? mothershipAttachmentUrl(key)
        : (file.path.isEmpty ? null : file.path);
    if (path == null || resolve == null) return;
    await launchUrl(Uri.parse(resolve(path)), webOnlyWindowName: '_blank');
  }

  // ComposerClipboardTarget (web clipboard bridge).

  @override
  bool get hasFocus => _focusNode.hasFocus;

  @override
  bool onPaste({
    required String text,
    required String? selectionPayload,
    required List<ComposerPickedFile> files,
  }) {
    if (files.isNotEmpty) {
      unawaited(_attachments.addFiles(files));
      return true;
    }
    final selection = decodeSelectionClipboard(
      selectionPayload,
      widget.workspaceId,
    );
    return _editor.handlePastedText(text, selectionContext: selection);
  }

  @override
  ({String text, String? selectionPayload})? onCopy({required bool cut}) {
    final sole = _editor.soleSelectionChip();
    ({String text, String? selectionPayload})? result;
    if (sole != null) {
      final sel = _editor.selection;
      result = (
        text: sel.textInside(_editor.text),
        selectionPayload: encodeSelectionClipboard(sole, widget.workspaceId),
      );
    } else {
      final serialized = _editor.clipboardTextForSelection();
      if (serialized != null) {
        result = (text: serialized, selectionPayload: null);
      }
    }
    if (result != null && cut) _editor.deleteSelection();
    return result;
  }

  // ComposerDropTarget (web OS file drop).

  @override
  bool containsGlobal(double x, double y) {
    final box = _rootKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(Offset(x, y));
  }

  @override
  void onDragEnter() => setState(() => _dragging = true);

  @override
  void onDragLeave() => setState(() => _dragging = false);

  @override
  void onDrop(List<ComposerPickedFile> files) {
    unawaited(_attachments.addFiles(files));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty || !mounted) return;
    _editor.pasteText(text);
  }

  Map<Type, Action<Intent>> get _actions => {
    PasteTextIntent: _ComposerPasteAction(_pasteFromClipboard),
    CopySelectionTextIntent: _ComposerCopyAction(this),
  };

  /// `isTouchMobileViewport()`: `width < 768` and a coarse pointer. Read
  /// on every dependency change so a resize / rotation updates it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _touchMobile =
        MediaQuery.sizeOf(context).width < touchMobileBreakpoint &&
        composerCoarsePointer();
    _editor.touchMobile = _touchMobile;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final hero = widget.variant == ComposerVariant.hero;
    final settings = _modelSettings;
    final modes = _modes;
    final effortOptions = settings.modelSelection != null
        ? ComposerEffort.values
        : simpleEffortOptions;

    List<Widget> leading(double gap, double width) => [
      KeyedSubtree(
        key: _plusKey,
        child: ComposerRoundChip(
          icon: SimEmcnIcons.plus,
          label: 'Add resources',
          identifier: 'chat-input.add',
          onPressed: _openPlusMenu,
        ),
      ),
      ComposerRoundChip(
        icon: SimEmcnIcons.paperclip,
        label: 'Attach file',
        identifier: 'chat-input.attach',
        onPressed: () => unawaited(_pickFiles()),
      ),
      ComposerRoundChip(
        icon: SimEmcnIcons.slash,
        label: 'Skills',
        identifier: 'chat-input.skills',
        onPressed: () {
          _focusNode.requestFocus();
          _editor.insertSlashTrigger();
        },
      ),
      if (hero && widget.onModeChange != null && modes.length >= 2)
        ComposerModeSelector(
          value: widget.mode,
          modes: modes,
          onChanged: widget.onModeChange,
        ),
    ];

    List<Widget> trailing(double gap, double width) {
      final narrow = width <= 320;
      final model = settings.modelSelection;
      return [
        if (widget.modelSelectorEnabled && model != null) ...[
          if (model.model != ComposerModel.opus55)
            ComposerFastToggle(
              enabled: model.fastMode,
              onChanged: (fast) => widget.onModelSelectionChange?.call(
                ComposerModelSelection(model: model.model, fastMode: fast),
              ),
            ),
          ComposerModelChip(
            selection: model,
            narrow: narrow,
            onChanged: (next) => widget.onModelSelectionChange?.call(
              ComposerModelSelection(
                model: next,
                fastMode: model.fastMode,
              ).normalized(),
            ),
          ),
        ],
        ComposerEffortChip(
          effort: settings.effort,
          options: effortOptions,
          narrow: narrow,
          onChanged: (effort) => unawaited(_setEffort(effort)),
        ),
        ComposerSendButton(
          isStreaming: widget.isStreaming,
          canSubmit: _canSubmit,
          onSubmit: _submit,
          onStop: widget.onStop,
        ),
      ];
    }

    final editor = PromptEditor(
      key: _editorKey,
      controller: _editor,
      focusNode: _focusNode,
      placeholder: hero
          ? _placeholder
          : const _ConstantString('Send message to Sim'),
      minHeight: hero ? PromptEditorMetrics.heroMinHeight : 0,
      onFirstFocus: _warmInventory,
      onPasteFromToolbar: _pasteFromClipboard,
      menus: PromptEditorMenus(
        groups: _groups,
        hydrating: _hydrating,
        skills: _skills,
        mcpServers: _mcpServers,
      ),
      onResourcePicked: _editor.insertResource,
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttachedFilesList(
          attachments: _attachments.attachments,
          resolveUrl: widget.resolveUrl,
          onOpen: (file) => unawaited(_openAttachment(file)),
          onRemove: _attachments.remove,
        ),
        PasteLimit(
          maxBytes: ComposerPasteLimits.bytes,
          maxCharacters: ComposerPasteLimits.characters,
          child: Actions(actions: _actions, child: editor),
        ),
        ComposerToolbar(leading: leading, trailing: trailing),
      ],
    );

    final box = Container(
      key: _rootKey,
      constraints: const BoxConstraints(maxWidth: 704),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: sim.isDark ? c.surface4 : SimColors.white,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: hero ? sim.shadows.ambient : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          if (_dragging) const ComposerDropOverlay(),
        ],
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: Semantics(
        container: true,
        identifier: 'chat-input.root',
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => _ownsFocus = focused,
          child: TextFieldTapRegion(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!_focusNode.hasFocus) _focusNode.requestFocus();
              },
              child: DragTarget<ComposerResourceDrag>(
                onAcceptWithDetails: (details) {
                  _editor.insertResources(details.data.resources);
                  _focusNode.requestFocus();
                },
                builder: (context, candidate, rejected) =>
                    DefaultTextStyle.merge(
                      style: sim.text.inter(SimTextStyles.sizeSm),
                      child: box,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConstantString extends ValueListenable<String> {
  const _ConstantString(this.value);

  @override
  final String value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Desktop paste through the composer's rules (web pastes natively and the
/// clipboard bridge handles it).
class _ComposerPasteAction extends ContextAction<PasteTextIntent> {
  _ComposerPasteAction(this._paste);

  final Future<void> Function() _paste;

  @override
  Object? invoke(PasteTextIntent intent, [BuildContext? context]) {
    if (kIsWeb) return callingAction?.invoke(intent);
    unawaited(_paste());
    return null;
  }
}

/// Desktop copy / cut writing portable chip links; plain selections keep
/// the field's own copy.
class _ComposerCopyAction extends ContextAction<CopySelectionTextIntent> {
  _ComposerCopyAction(this._state);

  final _ChatComposerState _state;

  @override
  Object? invoke(CopySelectionTextIntent intent, [BuildContext? context]) {
    final editor = _state._editor;
    final serialized = kIsWeb ? null : editor.clipboardTextForSelection();
    if (serialized == null) return callingAction?.invoke(intent);
    unawaited(Clipboard.setData(ClipboardData(text: serialized)));
    if (intent.collapseSelection) editor.deleteSelection();
    return null;
  }
}

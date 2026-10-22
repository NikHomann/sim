import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/input/model/auto_mention.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/chat_tokens.dart';
import 'package:sim_app/features/chat/input/model/chip_clipboard_codec.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';

/// `PASTE_LIMITS` / `PASTE_RENDER_THRESHOLDS` used by the chat composer.
abstract final class ComposerPasteLimits {
  static const int characters = 1000000;
  static const int bytes = 4000000;

  /// Above this the editor drops chip rendering (plain-text mode).
  static const int enhancedTextCharacters = 256 * 1024;
}

/// UTF-8 length of [value] without encoding (lone surrogates count 3).
int composerUtf8Length(String value) {
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code <= 0x7f) {
      bytes += 1;
    } else if (code <= 0x7ff) {
      bytes += 2;
    } else if (code >= 0xd800 && code <= 0xdbff && i + 1 < value.length) {
      final next = value.codeUnitAt(i + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        bytes += 4;
        i++;
      } else {
        bytes += 3;
      }
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

/// `assessTextPaste` with the chat limits on the payload and the result.
bool isPasteWithinChatLimits(String pasted, TextEditingValue current) {
  if (pasted.length > ComposerPasteLimits.characters) return false;
  if (pasted.length > ComposerPasteLimits.bytes) return false;
  final selection = current.selection.isValid
      ? current.selection
      : TextSelection.collapsed(offset: current.text.length);
  final resultChars =
      current.text.length - (selection.end - selection.start) + pasted.length;
  if (resultChars > ComposerPasteLimits.characters) return false;
  if (resultChars * 3 <= ComposerPasteLimits.bytes) return true;
  final pastedBytes = composerUtf8Length(pasted);
  if (pastedBytes > ComposerPasteLimits.bytes) return false;
  final keptBytes =
      composerUtf8Length(selection.textBefore(current.text)) +
      composerUtf8Length(selection.textAfter(current.text));
  return keptBytes + pastedBytes <= ComposerPasteLimits.bytes;
}

/// The outcome of confirming a caret-menu row from the keyboard
/// (`PlusMenuHandle.selectActive`).
enum ComposerMenuSelectResult {
  /// A row was inserted.
  selected,

  /// The lists are loaded and nothing matches: the key falls through.
  empty,

  /// The lists are still loading: the key is swallowed.
  hydrating,
}

/// What the field's key handler drives on an open caret menu.
abstract interface class ComposerMenuHandle {
  void moveActive(int delta);
  ComposerMenuSelectResult selectActive();
}

/// One key press as the editor sees it (modifiers resolved by the caller,
/// so the rules are testable without a hardware keyboard).
@immutable
class ComposerKey {
  const ComposerKey(
    this.key, {
    this.character,
    this.shift = false,
    this.meta = false,
    this.control = false,
    this.alt = false,
    this.repeat = false,
  });

  /// From a raw event plus the current modifier state.
  factory ComposerKey.fromEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    return ComposerKey(
      event.logicalKey,
      character: event.character,
      shift: keyboard.isShiftPressed,
      meta: keyboard.isMetaPressed,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      repeat: event is KeyRepeatEvent,
    );
  }

  final LogicalKeyboardKey key;
  final String? character;
  final bool shift;
  final bool meta;
  final bool control;
  final bool alt;
  final bool repeat;

  bool get plain => !shift && !meta && !control && !alt;
  bool get isEnter =>
      key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
}

class _DismissedMention {
  _DismissedMention(this.start);

  final int start;
  bool triggerSelected = false;
}

final RegExp _whitespace = RegExp(r'\s');
final RegExp _slashBoundary = RegExp(r'''[\s.,;:!?(){}\[\]"'`\\<>]''');

/// The composer's editing brain (port of `usePromptEditor`): the text, the
/// registered contexts, the `@` / `/` trigger state, chip atomicity (atomic
/// delete, caret hop, no typing inside, selection snapping), auto-mention,
/// the paste/copy rules, and [buildTextSpan], which paints every context
/// token as normal text whose first glyph is replaced by a [WidgetSpan]
/// exactly one glyph advance wide (one code unit), so offsets stay text
/// offsets and wrapping matches plain text.
class ComposerController extends TextEditingController {
  ComposerController({
    String text = '',
    List<ChatContext> contexts = const [],
    void Function(VoidCallback callback)? deferSelectionSnap,
  }) : _deferSnap = deferSelectionSnap ?? _postFrame,
       super(text: text) {
    _contexts = filterContextsPresentInMessage(contexts, text);
    _lastText = text;
    addListener(_onValueChanged);
  }

  static void _postFrame(VoidCallback callback) {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => callback())
      ..scheduleFrame();
  }

  final void Function(VoidCallback callback) _deferSnap;

  List<ChatContext> _contexts = const [];
  IntegrationMatcher _integrations = IntegrationMatcher(const []);
  SlashMatcher _slash = SlashMatcher(skills: const [], mcpServers: const []);

  TriggerQuery? _mention;
  _DismissedMention? _dismissedMention;
  TriggerQuery? _slashQuery;
  int? _dismissedSlashStart;

  bool _programmatic = false;
  bool _syncingSelection = false;
  String _lastText = '';
  bool _lastComposing = false;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);
  TextSelection _prevSelection = const TextSelection.collapsed(offset: 0);

  /// The seeded text still untouched (re-chipified once skills load).
  String? _seed;

  /// Attached by the caret menus while they are open.
  ComposerMenuHandle? mentionMenu;
  ComposerMenuHandle? skillsMenu;

  /// Host key policy (`PromptEditorKeyPolicy` + the mode shortcut).
  VoidCallback? onSubmit;
  bool Function()? onArrowUpOnEmpty;

  /// Shift+Tab: returns whether a mode change was possible (>= 2 modes).
  bool Function({required bool repeat})? onCycleMode;

  /// Touch-mobile viewports insert a newline on Enter.
  bool touchMobile = false;

  /// Interactive context adds (menu pick, drop, skill pick); paste is silent.
  void Function(ChatContext context)? onContextAdd;

  /// Fired for every context the text no longer references.
  void Function(ChatContext context, List<ChatContext> remaining)?
  onContextRemove;

  /// Paste refused by the chat limits (the host shows the warning toast).
  VoidCallback? onPasteTooLarge;

  /// Paints a chip glyph's icon (the composer supplies the kind registry).
  Widget? Function(ChatContext context)? chipIconBuilder;

  List<ChatContext> get contexts => _contexts;

  /// Replaces the registered contexts (draft / queued-message restore).
  set contexts(List<ChatContext> value) {
    _contexts = List.unmodifiable(value);
    notifyListeners();
  }

  /// The open `@` query, `null` when the mention menu is closed.
  TriggerQuery? get mentionQuery => _mention;

  /// The open `/` query, `null` when the skills menu is closed.
  TriggerQuery? get slashQuery => _slashQuery;

  bool get menuOpen => _mention != null || _slashQuery != null;

  /// `>256 KiB` without a skill chip: no chip rendering, 240px cap.
  bool get plainTextMode =>
      text.length > ComposerPasteLimits.enhancedTextCharacters &&
      !text.contains(skillChipTrigger);

  /// The outgoing text: skill sentinels restored to `/`.
  String get plainValue => restoreSkillTriggerText(text);

  /// Contexts whose token is still in the text (`getActiveContexts`).
  List<ChatContext> get activeContexts =>
      filterContextsPresentInMessage(_contexts, text);

  List<ChipRange> get chipRanges => computeChipRanges(text, _contexts);

  /// Supplies the skill / MCP / integration catalogs for auto-mention. A
  /// still-untouched seed is re-chipified once the catalogs fill.
  void updateCatalog({
    List<ComposerSkill>? skills,
    List<ComposerMcpServer>? mcpServers,
    List<ComposerIntegration>? integrations,
    String? ownerWorkspaceId,
  }) {
    if (integrations != null) _integrations = IntegrationMatcher(integrations);
    if (skills != null || mcpServers != null) {
      _slash = SlashMatcher(
        skills: skills ?? const [],
        mcpServers: mcpServers ?? const [],
        ownerWorkspaceId: ownerWorkspaceId,
      );
    }
    final seed = _seed;
    if (seed == null) return;
    if (text != seed) {
      _seed = null;
      return;
    }
    final converted = applyAutoMentions(seed);
    if (converted != seed) {
      _setProgrammatic(
        TextEditingValue(
          text: converted,
          selection: TextSelection.collapsed(offset: converted.length),
        ),
      );
    }
    _seed = (skills?.isNotEmpty ?? false) || (mcpServers?.isNotEmpty ?? false)
        ? null
        : converted;
  }

  /// `mentionifyIntegrations` with the current integration catalog.
  String mentionifyIntegrations(String text) => _integrations.mentionify(text);

  /// Bulk auto-mention (integration `@` canonicalisation, then skill `/`
  /// triggers), registering the contexts it finds.
  String applyAutoMentions(String text) {
    final integration = _integrations.convertText(text);
    final slash = _slash.convertText(integration.text);
    var next = mergeIntegrationContexts(_contexts, integration.contexts);
    next = SlashMatcher.merge(next, slash.contexts);
    if (!identical(next, _contexts)) _contexts = List.unmodifiable(next);
    return slash.text;
  }

  void _setProgrammatic(TextEditingValue next) {
    _programmatic = true;
    try {
      value = next;
    } finally {
      _programmatic = false;
    }
  }

  void _resetTriggers() {
    _mention = null;
    _dismissedMention = null;
    _slashQuery = null;
    _dismissedSlashStart = null;
  }

  /// Replaces the text (`setValue`): chipified unless [chipify] is false;
  /// [seed] keeps re-chipifying it while it stays untouched. Caret at end.
  void setText(String text, {bool chipify = true, bool seed = false}) {
    final next = chipify ? applyAutoMentions(text) : text;
    if (seed) _seed = next;
    _resetTriggers();
    _setProgrammatic(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );
  }

  /// Empties text and contexts and closes both menus (`clear`). Clearing is
  /// not a removal: [onContextRemove] does not fire.
  void clearComposer() {
    _resetTriggers();
    _contexts = const [];
    _setProgrammatic(TextEditingValue.empty);
  }

  void _addContext(ChatContext context, {bool notify = true}) {
    if (!isContextAlreadySelected(context, _contexts)) {
      _contexts = List.unmodifiable([..._contexts, context]);
    }
    if (notify) onContextAdd?.call(context);
  }

  TextSelection get _safeSelection => selection.isValid
      ? selection
      : TextSelection.collapsed(offset: text.length);

  bool _needsSpaceBefore(String current, int at) =>
      at > 0 && !_whitespace.hasMatch(current[at - 1]);

  /// Appends a context supplied by another surface as `@label ` with a
  /// ` (n)` suffix on label collisions (`insertContext`).
  void appendContext(ChatContext context) {
    final current = text;
    var resolved = context;
    if (context.kind == ChatContextKind.browserTab &&
        context.fields['selection'] != null) {
      resolved = context.copyWith(label: 'Browser');
    }
    final base = resolved.label;
    var label = base;
    var suffix = 1;
    bool used(String candidate) =>
        _contexts.any((c) => c.label == candidate) ||
        RegExp(
          '(^|\\s)@${RegExp.escape(candidate)}(?![A-Za-z0-9_])',
        ).hasMatch(current);
    while (used(label)) {
      label = '$base ($suffix)';
      suffix++;
    }
    if (label != resolved.label) resolved = resolved.copyWith(label: label);
    final insert =
        '${current.isNotEmpty && !_whitespace.hasMatch(current[current.length - 1]) ? ' ' : ''}@$label ';
    final next = '$current$insert';
    _resetTriggers();
    _addContext(resolved);
    _setProgrammatic(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );
  }

  /// Inserts a picked context as `@label `, replacing the `@query` being
  /// typed (or at the caret), caret after the trailing space
  /// (`insertMention`). Folders reuse an existing chip for the same target.
  ChatContext insertMention(ChatContext candidate) {
    var context = candidate;
    if (candidate.kind == ChatContextKind.folder ||
        candidate.kind == ChatContextKind.filefolder) {
      context = _contexts.firstWhere(
        (c) => c.kind == candidate.kind && areContextsEqual(c, candidate),
        orElse: () => candidate.copyWith(
          label: uniqueContextLabel(candidate.label, _contexts),
        ),
      );
    }
    final current = text;
    final range = _mention;
    final int start;
    final int end;
    if (range != null) {
      start = range.start;
      end = range.end;
    } else {
      start = _safeSelection.start;
      end = start;
    }
    final insert =
        '${_needsSpaceBefore(current, start) ? ' ' : ''}@${context.label} ';
    final next = current.replaceRange(start, end, insert);
    _mention = null;
    _dismissedMention = null;
    _addContext(context);
    _setProgrammatic(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + insert.length),
      ),
    );
    return context;
  }

  /// `insertResource`: maps a resource to its context and inserts it.
  ChatContext? insertResource(ComposerResource resource) {
    final mapped = resource.toContext();
    if (mapped == null) return null;
    return insertMention(mapped);
  }

  /// `insertResources` (drag-drop path).
  void insertResources(List<ComposerResource> resources) {
    resources.forEach(insertResource);
  }

  void _insertSlashChip(ChatContext context) {
    final current = text;
    final range = _slashQuery;
    final start = range?.start ?? _safeSelection.start;
    final end = range?.end ?? start;
    final insert =
        '${_needsSpaceBefore(current, start) ? ' ' : ''}$skillChipTrigger${context.label} ';
    final next = current.replaceRange(start, end, insert);
    _slashQuery = null;
    _dismissedSlashStart = null;
    _addContext(context);
    _setProgrammatic(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + insert.length),
      ),
    );
  }

  /// `handleSkillSelect`.
  void insertSkill(ComposerSkill skill) {
    final existing = _contexts.where(
      (c) => c.kind == ChatContextKind.skill && c.field('skillId') == skill.id,
    );
    final label = existing.isNotEmpty
        ? existing.first.label
        : uniqueContextLabel(skill.name, _contexts);
    _insertSlashChip(ChatContext.skill(skill.id, label));
  }

  /// `handleMcpSelect`.
  void insertMcpServer(ComposerMcpServer server) => _insertSlashChip(
    ChatContext.mcp(
      server.id,
      server.name,
      managedConnectorId: server.managedConnectorId,
    ),
  );

  /// `insertContextChips`: contexts pushed programmatically at the caret.
  void insertContextChips(List<ChatContext> contexts) {
    var attached = _contexts;
    final prepared = <ChatContext>[];
    for (final context in contexts) {
      final next = prepareContextForInsert(context, attached);
      if (next == null) continue;
      prepared.add(next);
      attached = [...attached, next];
    }
    if (prepared.isEmpty) return;
    final current = text;
    final at = _safeSelection.start;
    final insert =
        '${_needsSpaceBefore(current, at) ? ' ' : ''}${prepared.map((c) => '@${c.label} ').join()}';
    prepared.forEach(_addContext);
    _setProgrammatic(
      TextEditingValue(
        text: current.replaceRange(at, _safeSelection.end, insert),
        selection: TextSelection.collapsed(offset: at + insert.length),
      ),
    );
  }

  /// The Skills toolbar chip: inserts `/` (with a leading space when needed)
  /// at the caret and opens the skills menu.
  void insertSlashTrigger() {
    final current = text;
    final sel = _safeSelection;
    final insert = '${_needsSpaceBefore(current, sel.start) ? ' ' : ''}/';
    final next = current.replaceRange(sel.start, sel.end, insert);
    _dismissedSlashStart = null;
    _setProgrammatic(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      ),
    );
    _syncSlash(next, sel.start + insert.length);
    notifyListeners();
  }

  /// Escape / outside click on the mention menu: the token stays dismissed
  /// until the caret leaves it.
  void dismissMentionMenu() {
    final range = _mention;
    if (range == null) return;
    _dismissedMention = _DismissedMention(range.start);
    _mention = null;
    notifyListeners();
  }

  /// Escape / outside click on the skills menu: dismissed until the next
  /// edit.
  void dismissSkillsMenu() {
    final range = _slashQuery;
    if (range == null) return;
    _dismissedSlashStart = range.start;
    _slashQuery = null;
    notifyListeners();
  }

  /// Where [next] inserts text into [previous] without removing any, or
  /// `null` when the edit is not a pure insertion.
  static int? _insertionStart(String previous, String next) {
    var at = 0;
    while (at < previous.length &&
        previous.codeUnitAt(at) == next.codeUnitAt(at)) {
      at++;
    }
    return next.endsWith(previous.substring(at)) ? at : null;
  }

  /// The edit pipeline for user input (`handleInputChange`): inserting
  /// inside a chip is refused whatever its length, a one-character keystroke runs the auto-mention
  /// fast path, a multi-character insertion the bulk conversion. Composing
  /// (IME) text passes through untouched.
  TextEditingValue processUserEdit(
    TextEditingValue previous,
    TextEditingValue next,
  ) {
    if (next.composing.isValid) return next;
    if (previous.text == next.text) return next;
    final prevSel = previous.selection;
    if (prevSel.isValid &&
        prevSel.isCollapsed &&
        next.text.length > previous.text.length) {
      // Any length: a keystroke, an emoji (surrogate pair) or an IME commit,
      // whether it lands at the caret or (web) at a drifted offset.
      final ranges = computeChipRanges(previous.text, _contexts);
      final at = _insertionStart(previous.text, next.text);
      final chip =
          findRangeContaining(ranges, prevSel.start) ??
          (at == null ? null : findRangeContaining(ranges, at));
      if (chip != null) {
        return previous.copyWith(
          selection: TextSelection.collapsed(offset: chip.end),
        );
      }
    }
    final hasMentionQuery = _mention != null || _dismissedMention != null;
    if (_dismissedMention?.triggerSelected ?? false) _dismissedMention = null;
    if (hasMentionQuery) return next;
    final caret = next.selection.isValid
        ? next.selection.extentOffset
        : next.text.length;
    if (next.text.length == previous.text.length + 1) {
      var text = next.text;
      final integration = _integrations.processKeystroke(
        previous.text,
        text,
        caret,
      );
      if (integration != null) {
        text = integration.text;
        _contexts = List.unmodifiable(
          mergeIntegrationContexts(_contexts, [integration.context]),
        );
      }
      final slash = _slash.processKeystroke(previous.text, text, caret);
      if (slash != null) {
        text = slash.text;
        _contexts = List.unmodifiable(
          SlashMatcher.merge(_contexts, [slash.context]),
        );
      }
      if (text == next.text) return next;
      final shift = text.length - next.text.length;
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret + shift),
      );
    }
    if (next.text.length > previous.text.length + 1 &&
        next.text.length <= ComposerPasteLimits.enhancedTextCharacters) {
      final converted = applyAutoMentions(next.text);
      if (converted == next.text) return next;
      final caretAfter = applyAutoMentions(
        next.text.substring(0, caret.clamp(0, next.text.length)),
      ).length;
      return TextEditingValue(
        text: converted,
        selection: TextSelection.collapsed(offset: caretAfter),
      );
    }
    return next;
  }

  /// Applies a user edit through [processUserEdit] (toolbar paste, drop).
  void applyUserEdit(TextEditingValue next) {
    value = processUserEdit(value, next);
  }

  void _onValueChanged() {
    final currentText = text;
    final sel = selection;
    final composing = value.composing.isValid;
    final committed = _lastComposing && !composing;
    _lastComposing = composing;
    final textChanged = currentText != _lastText;
    final selectionChanged = sel != _lastSelection;
    _lastText = currentText;
    if (selectionChanged) {
      _prevSelection = _lastSelection.isValid ? _lastSelection : sel;
      _lastSelection = sel;
    }
    if (textChanged) {
      if (!_programmatic && _seed != null && currentText != _seed) {
        _seed = null;
      }
      final present = filterContextsPresentInMessage(_contexts, currentText);
      if (!identical(present, _contexts)) {
        final removed = [
          for (final c in _contexts)
            if (!present.contains(c)) c,
        ];
        _contexts = List.unmodifiable(present);
        for (final c in removed) {
          onContextRemove?.call(c, _contexts);
        }
      }
    }
    if (_programmatic || _syncingSelection) return;
    if (composing) return;
    if (!sel.isValid) return;
    if (textChanged || committed) {
      _dismissedSlashStart = null;
      final caret = sel.extentOffset;
      _syncMention(currentText, caret, sel);
      _syncSlash(currentText, caret);
      return;
    }
    if (selectionChanged) _adjustSelection(sel);
  }

  /// `handleSelectAdjust`: snap a selection edge inside a chip to a chip
  /// boundary (deferred one frame and dropped if the selection moved
  /// again), otherwise sync the menus at the focus position.
  void _adjustSelection(TextSelection sel) {
    final ranges = chipRanges;
    final start = sel.start;
    final end = sel.end;
    final startChip = findRangeContaining(ranges, start);
    final endChip = start == end ? startChip : findRangeContaining(ranges, end);
    final prev = _prevSelection;
    final snapped = snapSelectionToChips(
      (start: start, end: end),
      (start: prev.start, end: prev.end),
      startChip?.bounds,
      endChip?.bounds,
    );
    if (snapped.start != start || snapped.end != end) {
      final observed = sel;
      _deferSnap(() {
        if (selection != observed) return;
        final backward = observed.baseOffset > observed.extentOffset;
        selection = backward
            ? TextSelection(
                baseOffset: snapped.end,
                extentOffset: snapped.start,
              )
            : TextSelection(
                baseOffset: snapped.start,
                extentOffset: snapped.end,
              );
      });
      return;
    }
    final focus = sel.extentOffset;
    final hadMention = _mention;
    final hadSlash = _slashQuery;
    _syncMention(text, focus, sel);
    _syncSlash(text, focus);
    if (hadMention != _mention || hadSlash != _slashQuery) notifyListeners();
  }

  void _syncMention(String text, int caret, TextSelection sel) {
    final dismissed = _dismissedMention;
    if (dismissed != null) {
      dismissed.triggerSelected =
          sel.start <= dismissed.start && sel.end > dismissed.start;
      if (dismissed.triggerSelected) return;
    }
    final active = activeMentionQuery(text, caret, _contexts);
    final openable = active != null && !active.query.contains(RegExp('[\r\n]'));
    if (!openable) {
      _mention = null;
      _dismissedMention = null;
      return;
    }
    if (active.start == _dismissedMention?.start) {
      _mention = null;
      return;
    }
    _dismissedMention = null;
    _mention = active;
  }

  void _syncSlash(String text, int caret) {
    final active = activeSlashQuery(text, caret, _contexts);
    final openable = active != null && !_slashBoundary.hasMatch(active.query);
    if (!openable) {
      _slashQuery = null;
      _dismissedSlashStart = null;
      return;
    }
    if (active.start == _dismissedSlashStart) {
      _slashQuery = null;
      return;
    }
    _slashQuery = active;
  }

  void _setSelection(TextSelection next) {
    _syncingSelection = true;
    try {
      selection = next;
    } finally {
      _syncingSelection = false;
    }
  }

  /// The editor's key rules (`handleKeyDown` + the mode shortcut).
  KeyEventResult handleKey(ComposerKey key) {
    final composing = value.composing.isValid;
    final k = key.key;
    if (_mention != null && !composing) {
      final menu = mentionMenu;
      if (k == LogicalKeyboardKey.arrowDown) {
        menu?.moveActive(1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        menu?.moveActive(-1);
        return KeyEventResult.handled;
      }
      if ((k == LogicalKeyboardKey.tab || key.isEnter) && !key.shift) {
        final result = menu?.selectActive() ?? ComposerMenuSelectResult.empty;
        if (result != ComposerMenuSelectResult.empty) {
          return KeyEventResult.handled;
        }
      }
      if (k == LogicalKeyboardKey.escape) {
        dismissMentionMenu();
        return KeyEventResult.handled;
      }
    }
    if (_slashQuery != null && !composing) {
      final menu = skillsMenu;
      if (k == LogicalKeyboardKey.arrowDown) {
        menu?.moveActive(1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        menu?.moveActive(-1);
        return KeyEventResult.handled;
      }
      if ((k == LogicalKeyboardKey.tab || key.isEnter) && !key.shift) {
        final result = menu?.selectActive() ?? ComposerMenuSelectResult.empty;
        if (result == ComposerMenuSelectResult.selected) {
          return KeyEventResult.handled;
        }
      }
      if (k == LogicalKeyboardKey.escape) {
        dismissSkillsMenu();
        return KeyEventResult.handled;
      }
    }
    if (k == LogicalKeyboardKey.arrowUp && key.plain && text.isEmpty) {
      if (onArrowUpOnEmpty?.call() ?? false) return KeyEventResult.handled;
    }
    if (key.isEnter && !key.shift && !composing && !touchMobile) {
      final submit = onSubmit;
      if (submit != null) {
        submit();
        return KeyEventResult.handled;
      }
    }
    final sel = _safeSelection;
    final collapsed = sel.isCollapsed;
    if ((k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) &&
        collapsed &&
        !key.meta) {
      final caret = sel.start;
      ChipRange? target;
      for (final r in chipRanges) {
        final hit = k == LogicalKeyboardKey.backspace
            ? caret > r.start && caret <= r.end
            : caret >= r.start && caret < r.end;
        if (hit) {
          target = r;
          break;
        }
      }
      if (target != null) {
        final result = deleteChipRange(text, target);
        value = TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.caret),
        );
        return KeyEventResult.handled;
      }
    }
    if (collapsed &&
        key.plain &&
        !composing &&
        (k == LogicalKeyboardKey.arrowLeft ||
            k == LogicalKeyboardKey.arrowRight)) {
      final left = k == LogicalKeyboardKey.arrowLeft;
      final probe = left
          ? (sel.start - 1).clamp(0, text.length)
          : (sel.start + 1).clamp(0, text.length);
      final r = findRangeContaining(chipRanges, probe);
      if (r != null) {
        _setSelection(TextSelection.collapsed(offset: left ? r.start : r.end));
        _lastSelection = selection;
        return KeyEventResult.handled;
      }
    }
    final character = key.character;
    if (character != null &&
        character.runes.length == 1 &&
        !key.meta &&
        !key.control &&
        collapsed &&
        character.codeUnitAt(0) >= 0x20) {
      final r = findRangeContaining(chipRanges, sel.start);
      if (r != null) {
        _setSelection(TextSelection.collapsed(offset: r.end));
        _lastSelection = selection;
        return KeyEventResult.handled;
      }
    }
    if (k == LogicalKeyboardKey.tab &&
        key.shift &&
        !key.alt &&
        !key.control &&
        !key.meta &&
        !composing &&
        !menuOpen) {
      final cycle = onCycleMode;
      if (cycle != null && cycle(repeat: key.repeat)) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// The composer's paste rules for a plain-text payload (`handlePaste`):
  /// a Sim selection context becomes a chip; over-limit text is refused
  /// ([onPasteTooLarge]); portable chip links become chips without
  /// notifying [onContextAdd]. Returns whether the paste was consumed;
  /// otherwise the caller performs the native paste.
  bool handlePastedText(String pasted, {ChatContext? selectionContext}) {
    final sel = _safeSelection;
    if (selectionContext != null) {
      final prepared = prepareContextForInsert(selectionContext, _contexts);
      if (prepared != null) {
        final insert =
            '${_needsSpaceBefore(text, sel.start) ? ' ' : ''}@${prepared.label} ';
        _addContext(prepared, notify: false);
        _setProgrammatic(
          TextEditingValue(
            text: text.replaceRange(sel.start, sel.end, insert),
            selection: TextSelection.collapsed(
              offset: sel.start + insert.length,
            ),
          ),
        );
        return true;
      }
    }
    if (pasted.isNotEmpty && !isPasteWithinChatLimits(pasted, value)) {
      onPasteTooLarge?.call();
      return true;
    }
    final rewritten = rewritePastedChipLinks(pasted);
    if (rewritten == null) return false;
    final needsSpace =
        _needsSpaceBefore(text, sel.start) &&
        RegExp('^[@/$skillChipTrigger]').hasMatch(rewritten.text);
    final insert = needsSpace ? ' ${rewritten.text}' : rewritten.text;
    for (final c in rewritten.contexts) {
      _addContext(c, notify: false);
    }
    _setProgrammatic(
      TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, insert),
        selection: TextSelection.collapsed(offset: sel.start + insert.length),
      ),
    );
    return true;
  }

  /// Plain paste after [handlePastedText] declined: replaces the selection
  /// and runs the multi-character auto-mention path.
  void pasteText(String pasted) {
    if (handlePastedText(pasted)) return;
    final sel = _safeSelection;
    applyUserEdit(
      TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, pasted),
        selection: TextSelection.collapsed(offset: sel.start + pasted.length),
      ),
    );
  }

  /// The clipboard text for the current selection (`writeSanitizedClipboard`):
  /// portable links for chips, `/` for skill sentinels. `null` when the raw
  /// selection is already what the clipboard should hold.
  String? clipboardTextForSelection() {
    final sel = _safeSelection;
    if (sel.isCollapsed) return null;
    final selected = sel.textInside(text);
    final serialized = serializeSelectionForClipboard(selected, _contexts);
    return serialized == selected ? null : serialized;
  }

  /// The lone selection chip of the current selection, which travels on
  /// `text/x-sim-selection` instead of a portable link.
  ChatContext? soleSelectionChip() {
    final sel = _safeSelection;
    if (sel.isCollapsed) return null;
    final selected = sel.textInside(text);
    final chips = selectionContextsInText(selected, _contexts);
    if (chips.length != 1) return null;
    final rest = selected.replaceFirst(chipDisplayToken(chips.single), '');
    return rest.trim().isEmpty ? chips.single : null;
  }

  /// Removes the selected text (cut after the clipboard was written).
  void deleteSelection() {
    final sel = _safeSelection;
    if (sel.isCollapsed) return;
    value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, ''),
      selection: TextSelection.collapsed(offset: sel.start),
    );
  }

  final Map<(String, TextStyle?), double> _advanceCache = {};

  double _glyphAdvance(String glyph, TextStyle? style) {
    return _advanceCache.putIfAbsent((glyph, style), () {
      final painter = TextPainter(
        text: TextSpan(text: glyph, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    });
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final current = text;
    if (plainTextMode || _contexts.isEmpty || current.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final ranges = computeMentionHighlightRanges(
      current,
      extractContextTokens(_contexts),
    );
    if (ranges.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final byLabel = <String, ChatContext>{};
    for (final c in _contexts) {
      byLabel.putIfAbsent(c.label, () => c);
    }
    final composingRange = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final composingStyle = (style ?? const TextStyle()).merge(
      const TextStyle(decoration: TextDecoration.underline),
    );
    final children = <InlineSpan>[];
    void plain(int from, int to) {
      if (to <= from) return;
      if (!composingRange.isValid ||
          composingRange.end <= from ||
          composingRange.start >= to) {
        children.add(TextSpan(text: current.substring(from, to)));
        return;
      }
      final a = composingRange.start.clamp(from, to);
      final b = composingRange.end.clamp(from, to);
      if (a > from) children.add(TextSpan(text: current.substring(from, a)));
      children.add(
        TextSpan(text: current.substring(a, b), style: composingStyle),
      );
      if (to > b) children.add(TextSpan(text: current.substring(b, to)));
    }

    var last = 0;
    for (final range in ranges) {
      plain(last, range.start);
      final glyph = range.token.substring(0, 1);
      final chipContext = byLabel[stripMentionTrigger(range.token)];
      final icon = chipContext == null
          ? null
          : chipIconBuilder?.call(chipContext);
      final fontSize = style?.fontSize ?? 14;
      children
        ..add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ComposerChipGlyph(
              width: _glyphAdvance(glyph, style),
              height: fontSize,
              first: identical(range, ranges.first),
              child: icon,
            ),
          ),
        )
        ..add(TextSpan(text: range.token.substring(1)));
      last = range.end;
    }
    plain(last, current.length);
    return TextSpan(style: style, children: children);
  }

  @override
  void dispose() {
    removeListener(_onValueChanged);
    super.dispose();
  }
}

/// The invisible trigger glyph of a chip: a box exactly one glyph advance
/// wide with the 12px kind icon centred and nudged down 1.25px
/// (`absolute inset-0 m-auto size-[12px] translate-y-[1.25px]`).
class ComposerChipGlyph extends StatelessWidget {
  const ComposerChipGlyph({
    required this.width,
    required this.height,
    super.key,
    this.first = false,
    this.child,
  });

  final double width;
  final double height;
  final bool first;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget glyph = SizedBox(
      width: width,
      height: height,
      child: child == null
          ? null
          : OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: 12,
              maxHeight: 12,
              child: Transform.translate(
                offset: const Offset(0, 1.25),
                child: SizedBox.square(dimension: 12, child: child),
              ),
            ),
    );
    if (first) {
      glyph = Semantics(
        container: true,
        identifier: 'chat-input.chip',
        child: glyph,
      );
    }
    return glyph;
  }
}

/// Routes every user text edit through [ComposerController.processUserEdit]
/// (chip guard, auto-mention). Formatters do not run for selection-only
/// updates; composing (IME) updates pass through unchanged.
class ComposerEditFormatter extends TextInputFormatter {
  ComposerEditFormatter(this.controller);

  final ComposerController controller;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => controller.processUserEdit(oldValue, newValue);
}

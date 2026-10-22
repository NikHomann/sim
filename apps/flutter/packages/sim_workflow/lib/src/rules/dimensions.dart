/// Ports of `packages/workflow-renderer/src/dimensions.ts` (upstream
/// 27b53561): the shared block, note, container and handle geometry.
library;

/// Port of `BLOCK_DIMENSIONS`.
abstract final class BlockDimensions {
  static const double fixedWidth = 250;
  static const double noteWidth = 320;
  static const double noteExpandedWidth = 520;
  static const double noteExpandedHeight = 400;
  static const double headerHeight = 40;
  static const double minHeight = 100;

  /// Shortest card the border renderer reliably paints.
  static const double minPaintedHeight = 48;
  static const double workflowContentPadding = 16;

  /// One rendered summary row (text-sm line box).
  static const double workflowRowHeight = 20;

  /// `gap-2` between sections inside the card's content column.
  static const double workflowContentGap = 8;

  /// The error-output row.
  static const double workflowErrorRowHeight = 24;

  /// Chips row (the 20px ChipTag itself).
  static const double workflowChipsRowHeight = 20;

  /// Natural-language summary line height.
  static const double workflowSentenceLineHeight = 24;

  /// Total vertical spacing around an empty note's single text line.
  static const double noteContentPadding = 10;
  static const double noteMinContentHeight = 20;

  /// Tallest a note grows inline before its content starts scrolling.
  static const double noteContentViewportHeight = 200;

  /// Inset of the subflow Start card from the top of the container body.
  static const double subflowStartTopOffset = 12;
  static const double subflowStartHeight = 34;
  static const double subflowStartWidth = 58;
}

/// `NOTE_BLOCK_MIN_HEIGHT`: header + padding + one content line.
const double noteBlockMinHeight =
    BlockDimensions.headerHeight +
    BlockDimensions.noteContentPadding +
    BlockDimensions.noteMinContentHeight;

/// `NOTE_BLOCK_MAX_HEIGHT`: header + the content viewport.
const double noteBlockMaxHeight =
    BlockDimensions.headerHeight + BlockDimensions.noteContentViewportHeight;

/// Port of `clampNoteBlockTotalHeight`.
double clampNoteBlockTotalHeight(double totalHeight) =>
    totalHeight.clamp(noteBlockMinHeight, noteBlockMaxHeight);

/// Port of `getNoteBlockHeight`: the height a note paints at before measuring.
double getNoteBlockHeight({required bool isEmpty}) =>
    isEmpty ? noteBlockMinHeight : noteBlockMaxHeight;

/// Port of `clampNoteBlockHeight`: clamps measured *content*, adding the header.
double clampNoteBlockHeight(double contentHeight) =>
    clampNoteBlockTotalHeight(BlockDimensions.headerHeight + contentHeight);

/// Port of `estimateNoteBlockHeight`: a stable first frame from the line count.
double estimateNoteBlockHeight(String content) {
  if (content.trim().isEmpty) return getNoteBlockHeight(isEmpty: true);
  final lineCount = content.split('\n').length.clamp(1, 1 << 30);
  return clampNoteBlockHeight(
    BlockDimensions.noteContentPadding +
        lineCount * BlockDimensions.noteMinContentHeight,
  );
}

/// Port of `CONTAINER_DIMENSIONS`: a container's box and the gutter it keeps
/// around the blocks inside it.
abstract final class ContainerDimensions {
  static const double defaultWidth = 500;
  static const double defaultHeight = 300;
  static const double minWidth = 400;
  static const double minHeight = 200;
  static const double headerHeight = 40;
  static const double leftPadding = 24;
  static const double rightPadding = 80;
  static const double topPadding = 24;
  static const double bottomPadding = 80;
}

/// Port of `HANDLE_POSITIONS`.
abstract final class HandlePositions {
  /// Error knob center inset from the card's right edge.
  static const double errorRightOffset = 30;

  /// Y of the first condition-row handle: 40 header + 8 padding + half row.
  static const double conditionStartY = 58;

  /// Row pitch: 20px row height + 8px flex gap.
  static const double conditionRowHeight = 28;

  /// Y of every port on a loop/parallel container, derived from the Start
  /// card geometry (40 + 12 + 34 / 2 = 69).
  static const double subflowConnectionY =
      BlockDimensions.headerHeight +
      BlockDimensions.subflowStartTopOffset +
      BlockDimensions.subflowStartHeight / 2;
}

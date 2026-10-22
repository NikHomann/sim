/// Shell measurements (`02-design-system.md` §4 and §1e) and per-component
/// geometry literals that consumers need to lay out against.
abstract final class SimLayout {
  // Sidebar
  static const double sidebarExpandedDefault = 224;
  static const double sidebarExpandedMin = 224;
  static const double sidebarExpandedMax = 400;

  /// Sidebar max is `min(400, 30vw)`.
  static const double sidebarExpandedMaxViewportFraction = 0.30;
  static const double sidebarCollapsedRail = 48;
  static const double sidebarResizeHandle = 8;
  static const double sidebarSectionGap = 16;
  static const double sidebarItemGap = 1;
  static const double sidebarRailChip = 32;
  static const double sidebarSectionTitleRow = 18;
  static const double sidebarHeaderPadding = 8;
  static const double workspaceSwitcherWidth = 256;

  // Workflow panels
  static const double panelDefault = 320;
  static const double panelMin = 290;
  static const double panelMaxViewportFraction = 0.40;
  static const double terminalDefault = 206;
  static const double terminalMin = 30;
  static const double terminalMaxViewportFraction = 0.70;
  static const double editorConnectionsDefault = 172;
  static const double editorConnectionsMin = 30;
  static const double editorConnectionsMax = 300;
  static const double outputPanelDefault = 560;
  static const double outputPanelMin = 280;
  static const double homeChatResourceDefaultFraction = 0.5;
  static const double homeChatResourceMin = 280;
  static const double homeChatResourceMaxFraction = 0.8;
  static const double homeChatColumnMin = 480;
  static const double terminalBlockColumn = 240;
  static const double electronTitleBar = 38;

  // Chrome rhythm
  static const double spacingUnit = 4;
  static const double borderWidth = 1;
  static const double chipHeight = 30;
  static const double chipPaddingX = 8;
  static const double chipGap = 6;
  static const double chipIconSize = 16;
  static const double iconSize = 14;
  static const double menuRowHeight = 28;
  static const double menuRowHeightSm = 24;
  static const double menuPadding = 4;
  static const double menuSideOffset = 6;
  static const double menuMinWidth = 128;
  static const double menuMaxWidth = 220;
  static const double submenuMaxWidth = 280;
  static const double menuMaxHeight = 420;
  static const double popoverSideOffset = 14;
  static const double popoverSideOffsetTop = 20;
  static const double popoverCollisionPadding = 8;
  static const double popoverMaxHeight = 400;
  static const double popoverMinWidth = 160;
  static const double popoverMinWidthSm = 140;
  static const double tooltipOffset = 16;
  static const double tooltipEdgeGutter = 16;
  static const double tooltipEdgeThreshold = 360;
  static const double tooltipMaxWidth = 256;
  static const double touchTarget = 44;
  static const double chipTagHeight = 20;
  static const double buttonIconSize = 20;
  static const double scrollFadeBand = 12;

  /// `--overflow-fade-size` in `overflow-text.tsx` at upstream commit
  /// 27b53561 is 16px; `02-design-system.md` §1e records 18px. The code wins.
  static const double overflowFade = 16;
  static const double scrollbarThickness = 8;

  // Modal
  static const double modalMaxHeightFraction = 0.84;
  static const double modalWidthFraction = 0.90;
  static const double modalFullWidthFraction = 0.95;
  static const double modalSm = 440;
  static const double modalMd = 500;
  static const double modalLg = 600;
  static const double modalXl = 800;
  static const double modalFull = 1200;
  static const double modalOverlayBlur = 2;
  static const double chipModalShellPadding = 3;
  static const double chipModalLabelGap = 9;
  static const double chipModalFieldGutter = 8;
  static const double chipModalBodyGap = 16;
  static const double chipModalBodyPaddingTop = 16;
  static const double chipModalBodyPaddingBottom = 18;
  static const double chipModalHeaderPaddingX = 16;
  static const double chipModalHeaderPaddingTop = 12;
  static const double chipModalFooterPaddingX = 16;
  static const double chipModalFooterPaddingY = 8;

  // Settings sections
  static const double settingsDividerMarginTop = 9;
  static const double settingsDividerMarginBottom = 12;
  static const double settingsSectionGap = 28;

  // Toast
  static const double toastWidth = 280;
  static const double toastViewportInset = 16;
  static const double toastBoundaryInset = 12;
  static const int toastStackLimit = 3;
  static const double toastCollapsedOffset = 13;
  static const double toastCollapsedScaleStep = 0.05;
  static const double toastExpandGap = 8;
  static const double toastEstimatedHeight = 56;

  // Search palette
  static const double searchPaletteTopFraction = 0.15;
  static const double searchPaletteWidth = 500;

  // Tab strip
  static const double tabStripHeight = 34;
  static const double tabStripBand = 30;
  static const double tabStripInline = 8;
  static const double tabStripMaxTabWidth = 200;
  static const double tabStripLargeBand = 42;
  static const double tabStripLargeHeightAttached = 46;
  static const double tabStripLargeHeightFloating = 42;
}

import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// Opens an emcn context menu the way `useContextMenu` + a 1×1 fixed
/// trigger do: `align='start' side='bottom' sideOffset={4}` against a 1px
/// box at [globalPosition] puts the menu's top-left 5px below the point;
/// `modal={false}`, closed by an outside press, Escape or a selection.
SimMenuHandle showSidebarContextMenu(
  BuildContext context,
  Offset globalPosition, {
  required List<SimMenuEntry> Function() entries,
  VoidCallback? onClose,
  String? semanticsIdentifier,
}) => SimDropdownMenu.showAt(
  context,
  globalPosition + const Offset(0, 5),
  entries: entries,
  modal: false,
  onClose: onClose,
  semanticsIdentifier: semanticsIdentifier,
);

/// The keyboard/"…" anchor of `getContextMenuPosition`: the control's
/// top-right for "…" buttons (`rect.right, rect.top`).
Offset moreButtonAnchor(Rect globalRect) => globalRect.topRight;

/// A `DropdownMenuItem` row with its leading 14px emcn glyph.
SimMenuItem sidebarMenuItem(
  SimIconData glyph,
  String label,
  VoidCallback onSelect, {
  bool enabled = true,
  String? semanticsIdentifier,
}) => SimMenuItem(
  label: label,
  leading: SimIcon(glyph),
  onSelect: onSelect,
  enabled: enabled,
  semanticsIdentifier: semanticsIdentifier,
);

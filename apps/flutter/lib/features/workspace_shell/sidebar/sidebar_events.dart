import 'dart:async';

/// The sidebar's window events (`sidebar-scroll-to-item`,
/// `open-help-modal`): anything in the app can ask the mounted sidebar to
/// scroll a row into view or to open the Contact support modal (the search
/// palette's "Help" page does).
///
/// The palette also runs the sidebar's own create-folder and import flows
/// through here (`sidebar.tsx:1945-1947` hands `handleCreateFolder` and
/// `handleImportWorkflow` to `SearchModal`): the mounted sidebar registers
/// them, and the palette offers the rows only while one is registered.
class SidebarEvents {
  SidebarEvents._();

  static final StreamController<String> _scrollToItem =
      StreamController<String>.broadcast(sync: true);
  static final StreamController<void> _openHelpModal =
      StreamController<void>.broadcast(sync: true);

  /// `sidebar-scroll-to-item {itemId}`.
  static Stream<String> get scrollToItemRequests => _scrollToItem.stream;

  /// `open-help-modal`.
  static Stream<void> get openHelpModalRequests => _openHelpModal.stream;

  static void scrollToItem(String itemId) => _scrollToItem.add(itemId);

  static void openHelpModal() => _openHelpModal.add(null);

  static void Function()? _createFolder;
  static void Function()? _importWorkflow;

  /// The mounted sidebar's root "Create folder" (`handleCreateFolder`).
  static void Function()? get createFolder => _createFolder;

  /// The mounted sidebar's "Import workflow" (`handleImportWorkflow`);
  /// `null` while no import flow exists (the parser is Phase 2).
  static void Function()? get importWorkflow => _importWorkflow;

  /// Registers the sidebar's flows; returns the unregister call, which only
  /// clears what this registration set (a newer sidebar mount wins).
  static void Function() registerSidebarActions({
    required void Function() createFolder,
    void Function()? importWorkflow,
  }) {
    _createFolder = createFolder;
    _importWorkflow = importWorkflow;
    return () {
      if (identical(_createFolder, createFolder)) _createFolder = null;
      if (identical(_importWorkflow, importWorkflow)) _importWorkflow = null;
    };
  }
}

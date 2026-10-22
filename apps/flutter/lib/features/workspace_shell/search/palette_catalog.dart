/// The palette's canvas catalogue (`stores/modals/search/store.ts`
/// `initializeData`): blocks, triggers, tools, tool operations, and the
/// integration directory.
///
/// The real catalogue is built from the generated block registry
/// (`generated/blocks.json`, 17 MB) with permission-group filtering,
/// `getTriggersForSidebar` and `getToolOperationsIndex`; that loader and the
/// brand icons it needs arrive with the canvas in Phase 2. Until then the
/// shell uses [PaletteCatalog.empty] and those groups simply do not render.
library;

import 'dart:async';

import 'package:sim_app/features/workspace_shell/search/palette_models.dart';

/// The catalogue the palette ranks its canvas groups from.
abstract interface class PaletteCatalog {
  /// A catalogue with nothing in it (Phase 1).
  const factory PaletteCatalog.empty() = InMemoryPaletteCatalog;

  /// `category === 'blocks'` (no starter, no `hideFromToolbar`) plus Loop
  /// and Parallel.
  List<PaletteBlockItem> get blocks;

  /// `getTriggersForSidebar()`: Start, Schedule, Webhook Trigger, then A–Z.
  List<PaletteBlockItem> get triggers;

  /// `category === 'tools'`.
  List<PaletteBlockItem> get tools;

  /// `getToolOperationsIndex()` filtered to allowed blocks/operations.
  List<PaletteToolOperationItem> get toolOperations;

  /// The integration directory (`INTEGRATIONS` with an icon, allowed blocks).
  List<PaletteIntegrationItem> get integrations;
}

/// A fixed in-memory catalogue (tests, and the Phase 1 empty catalogue).
class InMemoryPaletteCatalog implements PaletteCatalog {
  const InMemoryPaletteCatalog({
    this.blocks = const [],
    this.triggers = const [],
    this.tools = const [],
    this.toolOperations = const [],
    this.integrations = const [],
  });

  @override
  final List<PaletteBlockItem> blocks;
  @override
  final List<PaletteBlockItem> triggers;
  @override
  final List<PaletteBlockItem> tools;
  @override
  final List<PaletteToolOperationItem> toolOperations;
  @override
  final List<PaletteIntegrationItem> integrations;
}

/// `window.dispatchEvent(new CustomEvent('add-block-from-toolbar', …))`:
/// canvas selections are published here; the Phase 2 canvas subscribes.
class AddBlockBus {
  AddBlockBus();

  /// The process-wide bus the shell and the canvas share.
  static final AddBlockBus instance = AddBlockBus();

  final StreamController<AddBlockRequest> _controller =
      StreamController<AddBlockRequest>.broadcast(sync: true);

  Stream<AddBlockRequest> get requests => _controller.stream;

  void dispatch(AddBlockRequest request) => _controller.add(request);
}

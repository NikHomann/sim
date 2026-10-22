import 'package:flutter/foundation.dart';

/// One node of the Tables / Files rail flyout (`FlyoutEntry` of
/// `components/folders/flyout-entries.ts`), already in display order.
sealed class RailResourceEntry {
  const RailResourceEntry({
    required this.id,
    required this.name,
    this.pinned = false,
  });

  final String id;
  final String name;
  final bool pinned;
}

class RailResourceFolderEntry extends RailResourceEntry {
  const RailResourceFolderEntry({
    required super.id,
    required super.name,
    super.pinned,
    this.children = const <RailResourceEntry>[],
  });

  final List<RailResourceEntry> children;
}

class RailResourceItemEntry extends RailResourceEntry {
  const RailResourceItemEntry({
    required super.id,
    required super.name,
    required this.href,
    super.pinned,
  });

  final String href;
}

/// What a rail flyout renders; [loading] while the list or its folders are
/// pending or placeholder (`rail-resource-flyout.tsx:615-617`).
@immutable
class RailResourceListing {
  const RailResourceListing({
    this.loading = false,
    this.entries = const <RailResourceEntry>[],
  });

  static const RailResourceListing empty = RailResourceListing();
  static const RailResourceListing pending = RailResourceListing(loading: true);

  final bool loading;
  final List<RailResourceEntry> entries;
}

/// Tables / Files data for the collapsed rail (`useTablesList` /
/// `useWorkspaceFiles` + their folders and pins). Those query layers are
/// Phase 4; the default source reports an empty, loaded listing.
// ignore: one_member_abstracts, the seam the Phase 4 query layers implement
abstract class RailResourceSource {
  const RailResourceSource();

  ValueListenable<RailResourceListing> listing(String workspaceId);
}

class EmptyRailResourceSource extends RailResourceSource {
  const EmptyRailResourceSource();

  static final ValueNotifier<RailResourceListing> _empty =
      ValueNotifier<RailResourceListing>(RailResourceListing.empty);

  @override
  ValueListenable<RailResourceListing> listing(String workspaceId) => _empty;
}

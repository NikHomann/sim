import 'dart:async';
import 'dart:io' show Platform;

import 'package:sim_app/features/workspace_shell/sidebar/shared/platform/picked_file.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:sim_app/features/workspace_shell/sidebar/shared/platform/picked_file.dart';

/// Desktop fallbacks of the browser primitives.
class SidebarBrowser {
  const SidebarBrowser();

  /// No page origin outside the browser.
  String? get origin => null;

  bool get isMac => Platform.isMacOS;

  String get userAgent => 'Sim Desktop (${Platform.operatingSystem})';

  /// `window.location.assign(url)`: no page to reload outside the browser.
  void assign(String url) {}

  /// `window.open(url, '_blank', 'noopener,noreferrer')`.
  void openNewTab(String url) => unawaited(
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
  );

  /// The hidden `<input type=file>`; desktop has no picker wired yet.
  Future<List<PickedFile>> pickFiles({
    required String accept,
    bool multiple = false,
  }) async => const <PickedFile>[];
}

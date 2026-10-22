import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';

/// Loads the bytes of a server-relative image (`/api/files/serve/…`) with
/// the session: the app's [SimHttpClient] (cookie jar on desktop).
typedef BackendImageLoader = Future<Uint8List> Function(String path);

/// A workspace logo or user avatar URL as the API returns it
/// (`contracts/workspaces.ts`: `/…` or `https://…`), rendered on every
/// platform:
/// - absolute `http(s)` URLs load directly;
/// - server-relative paths on web resolve against the page origin (the
///   browser sends the session cookie to its own origin);
/// - server-relative paths on desktop have no host of their own: they load
///   through the authenticated client against the configured Sim origin.
///
/// [fallback] shows while loading and when the image fails.
class BackendImage extends StatefulWidget {
  const BackendImage({
    required this.url,
    required this.fallback,
    required this.size,
    super.key,
    this.semanticLabel,
  });

  final String url;
  final Widget fallback;
  final double size;
  final String? semanticLabel;

  /// Desktop loader; tests replace it.
  @visibleForTesting
  static BackendImageLoader? loaderOverride;

  /// Whether relative paths go through the client (desktop) or straight to
  /// the page origin (web); tests flip it.
  @visibleForTesting
  static bool? loadRelativeThroughClient;

  static final LinkedHashMap<String, Future<Uint8List>> _cache =
      LinkedHashMap<String, Future<Uint8List>>();
  static const int _cacheSize = 64;

  /// Drops cached bytes (sign-out, tests).
  static void clearCache() => _cache.clear();

  static bool _isAbsolute(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  static Future<Uint8List> _load(String path) {
    final cached = _cache.remove(path);
    if (cached != null) return _cache[path] = cached;
    final loader = loaderOverride ?? _clientLoader;
    final future = loader(path);
    _cache[path] = future;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first)?.ignore();
    unawaited(future.then<void>((_) {}, onError: (_) => _cache.remove(path)));
    return future;
  }

  static Future<Uint8List> _clientLoader(String path) async {
    final response = await locator<SimHttpClient>().stream(
      method: 'GET',
      path: path,
    );
    final builder = BytesBuilder(copy: false);
    await response.bytes.forEach(builder.add);
    return builder.takeBytes();
  }

  @override
  State<BackendImage> createState() => _BackendImageState();
}

class _BackendImageState extends State<BackendImage> {
  Future<Uint8List>? _bytes;

  bool get _throughClient =>
      !BackendImage._isAbsolute(widget.url) &&
      (BackendImage.loadRelativeThroughClient ??
          (!kIsWeb && locator.isRegistered<SimHttpClient>()));

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(BackendImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    _bytes = _throughClient ? BackendImage._load(widget.url) : null;
  }

  String _networkUrl() {
    if (BackendImage._isAbsolute(widget.url)) return widget.url;
    if (locator.isRegistered<SimHttpClient>()) {
      return locator<SimHttpClient>().resolveUrl(widget.url);
    }
    return widget.url;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return Image.network(
        _networkUrl(),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (context, error, stack) => widget.fallback,
      );
    }
    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return widget.fallback;
        return Image.memory(
          data,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          semanticLabel: widget.semanticLabel,
          errorBuilder: (context, error, stack) => widget.fallback,
        );
      },
    );
  }
}

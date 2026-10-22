import 'package:flutter/material.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/shared/brand_icons.dart';
import 'package:sim_design/sim_design.dart';

/// `ApplicationLoading` (`app/_shell/application-loading.tsx:16-33`,
/// `shell.loading`): a `--bg` surface with the brand mark centred — the
/// brand wordmark image (32px tall, at most 240px wide), else a non-default
/// brand name in 18px `--text-tertiary`, else the Sim wordmark 67×32 in
/// `--text-tertiary`. [brand] defaults to the merged org brand.
class ApplicationLoading extends StatelessWidget {
  const ApplicationLoading({super.key, this.brand});

  final BrandConfig? brand;

  BrandConfig _resolveBrand() {
    if (brand != null) return brand!;
    if (locator.isRegistered<BrandingCubit>()) {
      return locator<BrandingCubit>().state.brand;
    }
    return const BrandConfig();
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final resolved = _resolveBrand();
    final wordmarkUrl = resolved.wordmarkUrl;
    Widget mark;
    if (wordmarkUrl != null && wordmarkUrl.isNotEmpty) {
      mark = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 32),
        child: Image.network(wordmarkUrl, height: 32, fit: BoxFit.contain),
      );
    } else if (resolved.name != const BrandConfig().name) {
      mark = Text(
        resolved.name,
        style: sim.text.lg.copyWith(color: c.textTertiary),
      );
    } else {
      mark = SimWordmark(width: 67, height: 32, color: c.textTertiary);
    }
    return Semantics(
      identifier: 'shell.loading',
      container: true,
      liveRegion: true,
      label: 'Loading ${resolved.name}',
      child: ColoredBox(
        color: c.bg,
        child: Center(child: ExcludeSemantics(child: mark)),
      ),
    );
  }
}

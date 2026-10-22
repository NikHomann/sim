import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/home/home_http.dart';
import 'package:sim_design/sim_design.dart';

/// `ON_DEMAND_UNLIMITED` (dollars at or above it read as unlimited).
const double onDemandUnlimitedDollars = 999999;

/// `CREDIT_MULTIPLIER`: $1 = 200 credits.
const int creditMultiplier = 200;

/// `formatCredits` (`lib/billing/credits/conversion.ts:133-136`): "∞" at
/// the unlimited threshold, else `round(dollars × 200)` with en-US
/// grouping.
String formatCredits(double dollars) {
  if (dollars >= onDemandUnlimitedDollars) return '∞';
  final credits = (dollars * creditMultiplier).round();
  final digits = credits.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '${credits < 0 ? '-' : ''}$grouped';
}

/// The chip's label: `remainingDollars === null` → "Available".
String creditsLabel(double? remainingDollars) =>
    remainingDollars == null ? 'Available' : formatCredits(remainingDollars);

/// `canManageWorkspaceBilling` (`lib/billing/workspace-permissions.ts`).
bool canManageWorkspaceBilling(WorkspaceHostContext host, String? userId) {
  if (host.hostOrganizationId != null) {
    return host.viewer.isHostOrganizationAdmin;
  }
  return host.workspace.billedAccountUserId == userId;
}

/// The tooltip of the non-manager tag (`credits-chip.tsx:53-55`).
String creditsUnavailableMessage(WorkspaceHostContext host) =>
    host.hostOrganizationId != null
    ? 'Contact an organization admin to manage this workspace’s billing.'
    : 'Only the workspace owner can manage billing.';

/// `GET /api/workspaces/{id}/credit-availability`.
@immutable
class CreditAvailability {
  const CreditAvailability({required this.remainingDollars, this.scope});

  final double? remainingDollars;

  /// `payer`, `member` or `effective`.
  final String? scope;
}

/// Loads credit availability (30 s stale, `workspace-usage.ts:34-41`).
// ignore: one_member_abstracts, the seam tests implement.
abstract class CreditAvailabilitySource {
  /// The availability, or null while loading or after a failure.
  ValueListenable<CreditAvailability?> load(String workspaceId);
}

/// [CreditAvailabilitySource] over [HomeHttp].
class HttpCreditAvailabilitySource implements CreditAvailabilitySource {
  HttpCreditAvailabilitySource({required this.http, required this.queries});

  final HomeHttp? http;
  final QueryClient queries;

  @override
  ValueListenable<CreditAvailability?> load(String workspaceId) {
    final cached = queries.getQueryData<CreditAvailability>(
      <Object?>['workspace-usage', 'credit-availability', workspaceId],
    );
    final result = ValueNotifier<CreditAvailability?>(cached);
    final client = http;
    if (client == null) return result;
    unawaited(
      queries
          .fetchQuery<CreditAvailability>(
            <Object?>['workspace-usage', 'credit-availability', workspaceId],
            (_) async {
              final json = await client.get(
                '/api/workspaces/$workspaceId/credit-availability',
              );
              final map = json is Map ? json : const <String, Object?>{};
              final dollars = map['remainingDollars'];
              return CreditAvailability(
                remainingDollars: dollars is num ? dollars.toDouble() : null,
                scope: map['scope'] is String ? map['scope']! as String : null,
              );
            },
            staleTime: const Duration(seconds: 30),
          )
          .then((value) => result.value = value, onError: (Object _) {}),
    );
    return result;
  }
}

/// `CreditsChip` (`credits-chip.tsx`): nothing without billing, for an
/// enterprise owner, while loading or without data; a clickable `Chip`
/// opening the upgrade page for a billing manager; otherwise a mono
/// `ChipTag` with the owner/admin tooltip.
class CreditsChip extends StatefulWidget {
  const CreditsChip({
    required this.workspaceId,
    required this.billingEnabled,
    required this.host,
    required this.userId,
    required this.source,
    required this.onUpgrade,
    super.key,
  });

  final String workspaceId;
  final bool billingEnabled;
  final WorkspaceHostContext? host;
  final String? userId;
  final CreditAvailabilitySource source;

  /// `router.push(/workspace/{id}/upgrade?reason=credits)`.
  final VoidCallback onUpgrade;

  @override
  State<CreditsChip> createState() => _CreditsChipState();
}

class _CreditsChipState extends State<CreditsChip> {
  ValueListenable<CreditAvailability?>? _availability;

  bool get _enabled {
    final host = widget.host;
    return widget.billingEnabled &&
        host != null &&
        !host.ownerBilling.isEnterprise;
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(CreditsChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasEnabled =
        oldWidget.billingEnabled &&
        oldWidget.host != null &&
        !oldWidget.host!.ownerBilling.isEnterprise;
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.source != widget.source ||
        wasEnabled != _enabled) {
      _availability?.removeListener(_changed);
      _availability = null;
      _bind();
    }
  }

  void _bind() {
    // The request only goes out with billing on and a non-enterprise owner.
    if (!_enabled) return;
    _availability = widget.source.load(widget.workspaceId)
      ..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _availability?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final availability = _availability?.value;
    if (!_enabled || host == null || availability == null) {
      return const SizedBox.shrink();
    }
    final label = creditsLabel(availability.remainingDollars);
    if (!canManageWorkspaceBilling(host, widget.userId)) {
      return SimTooltip(
        message: creditsUnavailableMessage(host),
        child: Semantics(
          label: 'Workspace credits remaining',
          child: SimChipTag(label: label, leftIcon: SimEmcnIcons.credit),
        ),
      );
    }
    return SimChip(
      label: label,
      leftIcon: SimEmcnIcons.credit,
      semanticsLabel: 'Workspace credits remaining — upgrade plan',
      onPressed: widget.onUpgrade,
    );
  }
}

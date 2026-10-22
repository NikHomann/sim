import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';
import 'package:sim_app/features/workspace_shell/modals/create_workspace_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/emails_input.dart';
import 'package:sim_design/sim_design.dart';

/// `MAX_LISTED_FAILURE_REASONS`.
const int maxListedFailureReasons = 3;

/// `buildInviteFailureMessage` (`invite-modal.tsx:64-82`): one failure →
/// its reason; several → a headline, up to three distinct reasons and
/// "And N more.".
String buildInviteFailureMessage(
  List<BatchInvitationFailure> failures,
  int attemptedCount,
) {
  if (failures.length == 1) return failures.first.error;
  final headline = failures.length >= attemptedCount
      ? 'None of the ${failures.length} invitations could be sent.'
      : '${failures.length} of $attemptedCount invitations could not be sent.';
  final reasons = <String>{for (final f in failures) f.error}.toList();
  final listed = reasons.take(maxListedFailureReasons).toList();
  final remaining = reasons.length - listed.length;
  return <String>[
    headline,
    ...listed,
    if (remaining > 0) 'And $remaining more.',
  ].join(' ');
}

/// The success toast (`invite-modal.tsx:254-264`), or null when nothing
/// was added or sent.
String? inviteSuccessMessage(BatchInvitationResult result) {
  final parts = <String>[
    if (result.added.isNotEmpty)
      '${result.added.length} member${result.added.length == 1 ? '' : 's'} added',
    if (result.successful.isNotEmpty)
      '${result.successful.length} invite${result.successful.length == 1 ? '' : 's'} sent',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// What the invite modal needs from the shell.
class InviteModalConfig {
  const InviteModalConfig({
    required this.workspaceId,
    this.workspaceName,
    this.organizationId,
    this.inviteDisabledReason,
    this.canInvite = true,
    this.isOrganizationAdmin,
  });

  /// The switcher's props (`workspace-header.tsx:849-857`): the active
  /// workspace's name (`activeWorkspace?.name || 'Workspace'`), its
  /// `organizationId` and `inviteDisabledReason`, and `canInvite =
  /// userPermissions.canAdmin`.
  factory InviteModalConfig.forWorkspace(
    Workspace? active, {
    required String workspaceId,
    required bool canInvite,
  }) {
    final name = active?.name;
    return InviteModalConfig(
      workspaceId: workspaceId,
      workspaceName: name != null && name.isNotEmpty ? name : 'Workspace',
      organizationId: active?.organizationId,
      inviteDisabledReason: active?.inviteDisabledReason,
      canInvite: canInvite,
    );
  }

  /// The workspace the invite starts from; null from organization settings
  /// (an organization-only invite).
  final String? workspaceId;
  final String? workspaceName;
  final String? organizationId;
  final String? inviteDisabledReason;

  /// `userPermissions.canAdmin` of the switcher.
  final bool canInvite;
  final bool? isOrganizationAdmin;

  bool get isOrganizationInvite => organizationId != null;
  bool get organizationOnly => isOrganizationInvite && workspaceId == null;
}

/// Opens `InviteModal` (`invite-modal.tsx:110-370`, `modal.invite`).
Future<void> showInviteModal(
  BuildContext context, {
  required InviteModalConfig config,
}) {
  final pending = ValueNotifier<bool>(false);
  final session = locator<SessionCubit>().state;
  final host = locator.isRegistered<WorkspaceHostCubit>()
      ? locator<WorkspaceHostCubit>().state.context
      : null;
  final shape = locator.isRegistered<DeploymentShapeCubit>()
      ? locator<DeploymentShapeCubit>().state.shape
      : null;
  return showSimChipModal<void>(
    context,
    semanticsLabel:
        'Invite teammates to '
        '${config.organizationOnly
            ? 'organization'
            : (config.workspaceName?.isNotEmpty ?? false)
            ? config.workspaceName
            : 'workspace'}',
    dismissDisabled: () => pending.value,
    builder: (context) => InviteModal(
      config: config,
      pending: pending,
      invitations: locator<InvitationsCubit>(),
      workspaces: locator<WorkspacesCubit>(),
      organizations: locator.isRegistered<OrganizationsRepository>()
          ? locator<OrganizationsRepository>()
          : null,
      toasts: locator.isRegistered<SimToasts>()
          ? locator<SimToasts>()
          : SimToasts.instance,
      sessionEmail: session.user?.email,
      sessionUserId: session.user?.id,
      billingEnabled: shape?.billingEnabled ?? false,
      hostOrganizationId: host?.hostOrganizationId,
      isHostOrganizationAdmin: host?.viewer.isHostOrganizationAdmin ?? false,
    ),
  ).whenComplete(pending.dispose);
}

class InviteModal extends StatefulWidget {
  const InviteModal({
    required this.config,
    required this.pending,
    required this.invitations,
    required this.workspaces,
    required this.toasts,
    required this.sessionEmail,
    required this.sessionUserId,
    super.key,
    this.organizations,
    this.billingEnabled = false,
    this.hostOrganizationId,
    this.isHostOrganizationAdmin = false,
  });

  final InviteModalConfig config;
  final ValueNotifier<bool> pending;
  final InvitationsCubit invitations;
  final WorkspacesCubit workspaces;
  final OrganizationsRepository? organizations;
  final SimToasts toasts;
  final String? sessionEmail;
  final String? sessionUserId;
  final bool billingEnabled;
  final String? hostOrganizationId;
  final bool isHostOrganizationAdmin;

  @override
  State<InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends State<InviteModal> {
  List<String> _emails = const [];
  late List<String> _selectedWorkspaceIds = [
    ?widget.config.workspaceId,
  ];
  WorkspacePermission _access = WorkspacePermission.write;
  InvitationMembership _membership = InvitationMembership.member;
  String? _error;
  bool _submitting = false;
  List<AdminWorkspace>? _adminWorkspaces;
  OrganizationPlanSeats? _seats;

  InviteModalConfig get _config => widget.config;

  bool get _canGrantOrganizationAdmin =>
      _config.isOrganizationInvite &&
      (_config.isOrganizationAdmin ??
          (widget.hostOrganizationId == _config.organizationId &&
              widget.isHostOrganizationAdmin));

  @override
  void initState() {
    super.initState();
    final orgId = _config.organizationId;
    final userId = widget.sessionUserId;
    if (orgId != null && !_config.organizationOnly && userId != null) {
      unawaited(_loadAdminWorkspaces(userId, orgId));
    }
    if (orgId != null &&
        widget.billingEnabled &&
        _canGrantOrganizationAdmin &&
        widget.organizations != null) {
      unawaited(_loadSeats(orgId));
    }
  }

  Future<void> _loadAdminWorkspaces(String userId, String orgId) async {
    try {
      final rows = await widget.workspaces.adminWorkspaces(
        userId,
        organizationId: orgId,
      );
      if (mounted) setState(() => _adminWorkspaces = rows);
    } on Object catch (error) {
      developer.log('admin workspaces', name: 'sim_app.invite', error: error);
    }
  }

  Future<void> _loadSeats(String orgId) async {
    try {
      final seats = await widget.organizations!.planSeats(orgId);
      if (mounted) setState(() => _seats = seats);
    } on Object {
      // Advisory only.
    }
  }

  List<SimChipDropdownOption> get _workspaceOptions {
    if (!_config.isOrganizationInvite) {
      final id = _config.workspaceId;
      return id == null
          ? const []
          : [
              SimChipDropdownOption(
                value: id,
                label: _config.workspaceName ?? 'This workspace',
              ),
            ];
    }
    return [
      for (final w in _adminWorkspaces ?? const <AdminWorkspace>[])
        if (w.canInvite || w.id == _config.workspaceId)
          SimChipDropdownOption(value: w.id, label: w.name),
    ];
  }

  List<SimChipDropdownOption> get _membershipOptions => [
    const SimChipDropdownOption(value: 'member', label: 'Member'),
    if (_canGrantOrganizationAdmin)
      const SimChipDropdownOption(value: 'admin', label: 'Admin'),
    if (!_config.organizationOnly)
      const SimChipDropdownOption(value: 'external', label: 'External'),
  ];

  String? get _seatLimitReason {
    final seats = _seats;
    if (seats == null || !_canGrantOrganizationAdmin) return null;
    final enterprise = seats.subscriptionPlan == 'enterprise';
    if (!enterprise || seats.totalSeats <= 0) return null;
    final available = (seats.totalSeats - seats.usedSeats).clamp(0, 1 << 30);
    if (_membership == InvitationMembership.external ||
        _emails.length <= available) {
      return null;
    }
    return 'Only $available seat${available == 1 ? '' : 's'} available — '
        'invites beyond that may fail. External collaborators and existing '
        'members do not use seats.';
  }

  String? _validateEmail(String email) {
    final reason = quickValidateEmailReason(email);
    if (reason != null) return reason;
    final own = widget.sessionEmail;
    if (own != null && own.toLowerCase() == email) {
      return 'You cannot invite yourself';
    }
    return null;
  }

  bool get _sendDisabled =>
      !_config.canInvite ||
      (_config.inviteDisabledReason?.isNotEmpty ?? false) ||
      _submitting ||
      _emails.isEmpty ||
      (!_config.organizationOnly && _selectedWorkspaceIds.isEmpty) ||
      (_config.organizationOnly && !_canGrantOrganizationAdmin);

  Future<void> _send() async {
    if (_sendDisabled) return;
    final close = SimModalScope.of(context).close;
    final attempted = _emails;
    setState(() {
      _error = null;
      _submitting = true;
    });
    widget.pending.value = true;
    try {
      final result = await widget.invitations.sendBatch(
        workspaceIds: _selectedWorkspaceIds,
        emails: attempted,
        permission: _access,
        membership: _config.isOrganizationInvite ? _membership : null,
        organizationId: _config.organizationId,
      );
      widget.pending.value = false;
      final success = inviteSuccessMessage(result);
      if (success != null) widget.toasts.success(success);
      if (result.failed.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _emails = [for (final f in result.failed) f.email];
          _error = buildInviteFailureMessage(result.failed, attempted.length);
        });
        return;
      }
      close();
    } on Object catch (error) {
      widget.pending.value = false;
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = errorMessageOf(
          error,
          'An unexpected error occurred. Please try again.',
        );
      });
    }
  }

  Widget _id(String id, Widget child) =>
      Semantics(identifier: id, container: true, child: child);

  @override
  Widget build(BuildContext context) {
    SimChipModalScope.maybeOf(
      context,
    )?.setPrimary(() => unawaited(_send()), enabled: !_sendDisabled);
    final modal = SimModalScope.of(context);
    final editable = !_submitting && _config.canInvite;
    final workspaceOptions = _workspaceOptions;
    final disabledReason = _config.inviteDisabledReason;
    return _id(
      'modal.invite',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SimChipModalHeader(title: 'Invite teammates'),
          SimChipModalBody(
            children: <Widget>[
              _id(
                'modal.invite.emails',
                SimChipModalField(
                  title: 'Emails',
                  hint: disabledReason ?? _seatLimitReason,
                  enabled: editable,
                  child: EmailsInput(
                    value: _emails,
                    enabled: editable,
                    validate: _validateEmail,
                    placeholder: _config.canInvite
                        ? 'Enter emails'
                        : ((disabledReason?.isNotEmpty ?? false)
                              ? disabledReason!
                              : 'Only administrators can invite new teammates'),
                    onChanged: (next) => setState(() {
                      _emails = next;
                      _error = null;
                    }),
                  ),
                ),
              ),
              if (!_config.organizationOnly) ...<Widget>[
                _id(
                  'modal.invite.workspaces',
                  SimChipModalField(
                    title: 'Workspaces',
                    child: SimChipDropdown(
                      options: workspaceOptions,
                      multiple: true,
                      values: _selectedWorkspaceIds,
                      onValuesChanged: (next) =>
                          setState(() => _selectedWorkspaceIds = next),
                      allLabel: 'Select workspaces',
                      showAllOption: false,
                      searchable: _config.isOrganizationInvite,
                      searchPlaceholder: 'Search workspaces...',
                      fullWidth: true,
                      enabled: editable && workspaceOptions.length > 1,
                      semanticsLabel: 'Workspaces',
                    ),
                  ),
                ),
                _id(
                  'modal.invite.access',
                  SimChipModalField.dropdown(
                    title: 'Workspace access',
                    options: const <SimChipDropdownOption>[
                      SimChipDropdownOption(value: 'admin', label: 'Admin'),
                      SimChipDropdownOption(value: 'write', label: 'Write'),
                      SimChipDropdownOption(value: 'read', label: 'Read'),
                    ],
                    value: _access.name,
                    placeholder: 'Select access',
                    align: SimAlign.start,
                    enabled: editable,
                    onChanged: (next) => setState(
                      () => _access = WorkspacePermission.values.byName(next),
                    ),
                  ),
                ),
              ],
              if (_config.isOrganizationInvite)
                _id(
                  'modal.invite.membership',
                  SimChipModalField.dropdown(
                    title: _config.organizationOnly
                        ? 'Role'
                        : 'Organization membership',
                    options: _membershipOptions,
                    value: _membership.name,
                    placeholder: 'Select membership',
                    align: SimAlign.start,
                    enabled: editable,
                    hint: _membership == InvitationMembership.external
                        ? 'Access to the selected workspaces only — no seat. '
                              'Only available for people already on a paid '
                              'Sim plan.'
                        : null,
                    onChanged: (next) => setState(
                      () => _membership = InvitationMembership.values.byName(
                        next,
                      ),
                    ),
                  ),
                ),
              _id('modal.invite.error', SimChipModalError(_error)),
            ],
          ),
          SimChipModalFooterShell(
            children: <Widget>[
              SimChip(
                label: 'Cancel',
                enabled: !_submitting,
                onPressed: modal.close,
              ),
              _id(
                'modal.invite.submit',
                SimChip(
                  label: _submitting ? 'Sending...' : 'Send invites',
                  variant: SimChipVariant.primary,
                  enabled: !_sendDisabled,
                  onPressed: () => unawaited(_send()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

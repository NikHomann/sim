import { isChangelogEnabled } from '@/lib/changelog/feature-flag'
import { isComputerUseAvailable } from '@/lib/computer-use/availability.server'
import { defineAuthorizedWorkspaceUseCase, defineWorkspaceOperation } from '@/lib/core/application'
import { isDashboardsEnabled } from '@/lib/dashboards/feature-flag'
import {
  hasDesktopBackgroundExecutor,
  isDesktopBackgroundExecutorAvailable,
} from '@/lib/desktop/executor/availability'
import { isMothershipModelSelectorEnabled, isPlanModeEnabled } from '@/lib/mothership/feature-flags'
import { isProjectsEnabled } from '@/lib/projects/rollout.server'
import { isWorkflowTestsEnabled } from '@/lib/workflow-tests/feature-flag'
import { resolveActiveWorkspaceApplicationContext } from '@/lib/workspaces/application/context'

export const workspaceFeatureFlagOperations = {
  /** permission-group-exempt: reports which rollouts the workspace shell draws for a caller who can already read it; every gated action authorizes itself */
  read: defineWorkspaceOperation({
    id: 'workspaces.feature_flags.read',
    minimumRole: 'read',
    workspaceApiKey: 'deny',
    capability: 'none',
    principalKinds: ['session'],
  }),
} as const

interface ReadWorkspaceFeatureFlagsInput {
  workspaceId: string
}

/**
 * The flags `workspace/[workspaceId]/layout.tsx` resolves for `FeatureFlagsProvider`
 * and the sidebar's desktop-executor entry, from the same inputs: the host
 * organization for the organization-scoped rollouts and the viewer for the
 * per-user ones.
 */
export const readWorkspaceFeatureFlags = defineAuthorizedWorkspaceUseCase({
  operation: workspaceFeatureFlagOperations.read,
  resolveContext: ({ input }: { input: ReadWorkspaceFeatureFlagsInput }) =>
    resolveActiveWorkspaceApplicationContext(input.workspaceId),
  authorizationOptions: {},
  execute: async ({ principal, context }) => {
    const hostOrganizationId = context.workspaceOrganizationId
    const [
      dashboards,
      workflowTests,
      changelog,
      modelSelector,
      computerUse,
      planMode,
      projects,
      desktopExecutorRegistered,
    ] = await Promise.all([
      isDashboardsEnabled(hostOrganizationId),
      isWorkflowTestsEnabled(hostOrganizationId),
      isChangelogEnabled(hostOrganizationId),
      isMothershipModelSelectorEnabled(),
      isComputerUseAvailable(hostOrganizationId),
      isPlanModeEnabled(principal.userId).catch(() => false),
      isProjectsEnabled(),
      hasDesktopBackgroundExecutor(principal.userId),
    ])

    return {
      flags: {
        dashboards,
        'workflow-tests': workflowTests,
        changelog,
        'mothership-model-selector': modelSelector,
        'mothership-computer-use': computerUse,
        'mothership-plan-mode': planMode,
        projects,
      },
      desktopExecutor: {
        available: isDesktopBackgroundExecutorAvailable(),
        registered: desktopExecutorRegistered,
      },
    }
  },
})

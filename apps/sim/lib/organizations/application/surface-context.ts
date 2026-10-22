import { createLogger } from '@sim/logger'
import { canUseBenchmarks } from '@/lib/benchmarks/config'
import { isChangelogEnabled } from '@/lib/changelog/feature-flag'
import { isComputerUseAvailable } from '@/lib/computer-use/availability.server'
import { defineAuthorizedOrganizationUseCase } from '@/lib/core/application/authorized-organization-use-case'
import { defineOrganizationOperation } from '@/lib/core/application/organization-operation'
import { OrchestrationError } from '@/lib/core/orchestration/types'
import { isDashboardsEnabled } from '@/lib/dashboards/feature-flag'
import { isMothershipModelSelectorEnabled } from '@/lib/mothership/feature-flags'
import type { OrganizationInput } from '@/lib/organizations/application/reads'
import { getOrganizationSurfaceContext } from '@/lib/organizations/surface'
import { isProjectsEnabled } from '@/lib/projects/rollout.server'
import { isWorkflowTestsEnabled } from '@/lib/workflow-tests/feature-flag'

const logger = createLogger('OrganizationSurfaceContext')

export const organizationSurfaceOperations = {
  /** permission-group-exempt: the viewer's own standing in an organization they belong to and which rollouts its shell draws; every gated action authorizes itself */
  read: defineOrganizationOperation({
    id: 'organizations.surface_context.read',
    minimumRole: 'member',
    capability: 'none',
    principalKinds: ['session'],
  }),
} as const

/**
 * What `o/[organizationId]/layout.tsx` resolves before it renders: the surface
 * context for `OrganizationProvider`, the flags for `FeatureFlagsProvider`, and
 * the sidebar's benchmark entry, from the same inputs.
 */
export const readOrganizationSurfaceContext = defineAuthorizedOrganizationUseCase({
  operation: organizationSurfaceOperations.read,
  async execute({ input, context }: { input: OrganizationInput; context: { userId: string } }) {
    const [
      surface,
      modelSelector,
      dashboards,
      benchmarkEnabled,
      computerUse,
      workflowTests,
      changelog,
      projects,
    ] = await Promise.all([
      getOrganizationSurfaceContext(input.organizationId, context.userId),
      isMothershipModelSelectorEnabled(),
      isDashboardsEnabled(input.organizationId),
      canUseBenchmarks(context.userId).catch(() => {
        logger.warn('Could not resolve benchmark navigation access')
        return false
      }),
      isComputerUseAvailable(input.organizationId),
      isWorkflowTestsEnabled(input.organizationId),
      isChangelogEnabled(input.organizationId),
      isProjectsEnabled(),
    ])
    if (!surface) throw new OrchestrationError('not_found', 'Organization not found')

    return {
      context: surface,
      flags: {
        dashboards,
        'workflow-tests': workflowTests,
        changelog,
        'mothership-model-selector': modelSelector,
        'mothership-computer-use': computerUse,
        'mothership-plan-mode': benchmarkEnabled,
        'mothership-memory-spaces': benchmarkEnabled,
        projects,
      },
      benchmarkEnabled,
    }
  },
})

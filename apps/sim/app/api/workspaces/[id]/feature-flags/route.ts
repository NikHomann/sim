import { getWorkspaceFeatureFlagsContract } from '@/lib/api/contracts/workspaces'
import {
  defineInternalJsonRoute,
  internalOrchestrationErrorPolicy,
  internalRateLimits,
  internalSessionAuth,
} from '@/lib/api/server/routes'
import {
  readWorkspaceFeatureFlags,
  workspaceFeatureFlagOperations,
} from '@/lib/workspaces/application/feature-flags'

export const GET = defineInternalJsonRoute({
  contract: getWorkspaceFeatureFlagsContract,
  auth: internalSessionAuth,
  operation: workspaceFeatureFlagOperations.read,
  rateLimit: internalRateLimits.user({ bucketName: 'workspace-feature-flags' }),
  errorPolicy: internalOrchestrationErrorPolicy,
  mapInput: ({ params }) => ({ workspaceId: params.id }),
  useCase: readWorkspaceFeatureFlags,
})

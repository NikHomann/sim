import { getOrganizationSurfaceContextContract } from '@/lib/api/contracts/organization'
import {
  defineInternalJsonRoute,
  internalRateLimits,
  internalSessionAuth,
} from '@/lib/api/server/routes'
import { internalOrganizationErrorPolicy } from '@/lib/api/server/routes/organizations'
import {
  organizationSurfaceOperations,
  readOrganizationSurfaceContext,
} from '@/lib/organizations/application/surface-context'

export const GET = defineInternalJsonRoute({
  contract: getOrganizationSurfaceContextContract,
  auth: internalSessionAuth,
  operation: organizationSurfaceOperations.read,
  rateLimit: internalRateLimits.user({
    bucketName: 'organization-surface-context',
  }),
  errorPolicy: internalOrganizationErrorPolicy,
  mapInput: ({ params }) => ({ organizationId: params.id }),
  useCase: readOrganizationSurfaceContext,
})

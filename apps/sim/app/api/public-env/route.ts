import type { NextRequest } from 'next/server'
import { NextResponse } from 'next/server'
import { getPublicEnvContract } from '@/lib/api/contracts/public-env'
import { parseRequest } from '@/lib/api/server'
import { withRouteHandler } from '@/lib/core/utils/with-route-handler'
import { readPublicEnv } from '@/app/_shell/public-env-script'

export const dynamic = 'force-dynamic'

/**
 * The `NEXT_PUBLIC_*` transport as JSON, for a client that is not served the
 * root layout's HTML. Unauthenticated because every page already embeds these
 * values; read per request, as `RuntimePublicEnvScript` does, and never cached
 * so a restarted self-hosted image is not answered from the previous snapshot.
 */
export const GET = withRouteHandler(async (request: NextRequest) => {
  const parsed = await parseRequest(getPublicEnvContract, request, {})
  if (!parsed.success) return parsed.response

  return NextResponse.json(readPublicEnv(), {
    headers: { 'Cache-Control': 'no-store' },
  })
})

import { z } from 'zod'
import { defineRouteContract } from '@/lib/api/contracts/types'

/**
 * The `NEXT_PUBLIC_*` snapshot the root layout embeds in its HTML, for a client
 * that never renders that HTML. The key pattern is the guard: the route reads
 * `process.env` by prefix, and a value without it fails validation at the client
 * instead of being read as configuration.
 */
export const getPublicEnvContract = defineRouteContract({
  method: 'GET',
  path: '/api/public-env',
  response: {
    mode: 'json',
    schema: z.record(
      z.string().regex(/^NEXT_PUBLIC_/i, 'Only NEXT_PUBLIC_* values are public'),
      z.string()
    ),
  },
})

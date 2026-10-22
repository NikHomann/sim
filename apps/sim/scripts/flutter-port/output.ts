import { mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import type { Portable } from '@/scripts/flutter-port/portable'

export class OutputDir {
  constructor(readonly root: string) {}

  /** Removes a path the script owns so stale files from an earlier run never survive. */
  clear(relative: string): void {
    rmSync(join(this.root, relative), { recursive: true, force: true })
  }

  writeText(relative: string, text: string): void {
    const target = join(this.root, relative)
    mkdirSync(dirname(target), { recursive: true })
    writeFileSync(target, text)
  }

  writeBytes(relative: string, bytes: Uint8Array): void {
    const target = join(this.root, relative)
    mkdirSync(dirname(target), { recursive: true })
    writeFileSync(target, bytes)
  }

  writeJson(relative: string, value: Portable | Record<string, unknown>): void {
    this.writeText(relative, `${JSON.stringify(value, null, 2)}\n`)
  }
}

# Third-party assets bundled in `sim_design`

| Asset | Path | Source | License |
|---|---|---|---|
| Inter variable (InterVariable.ttf, v4.1) | `assets/fonts/InterVariable.ttf` | https://github.com/rsms/inter/releases/tag/v4.1 (`Inter-4.1.zip`) | SIL Open Font License 1.1 — full text in `assets/fonts/LICENSE-Inter-OFL.txt` (copyright 2016 The Inter Project Authors) |
| Season Sans Uprights VF (SeasonSansUprightsVF.ttf) | `assets/fonts/SeasonSansUprightsVF.ttf` | Converted from `apps/sim/app/_styles/fonts/season/SeasonSansUprightsVF.woff2` at upstream commit `27b53561def7db4eaa9ad2f12c04ea1a0eaaf91c` with `wawoff2` (`woff2_decompress.js`), a lossless WOFF2 → TTF unpack | **Open question.** The upstream repository ships the WOFF2 without a license file (`apps/sim/app/_styles/fonts/season/` holds only the font and `season.ts`; `apps/sim/public/brand/fonts/` has the same file and no license). Season Sans is a commercial typeface; the terms under which the Sim product embeds it, and whether they cover redistribution in a Flutter bundle (web and Windows), must be confirmed by the owner of the upstream license before the port ships (`docs/port/00-plan.md` §9). |
| Icon SVGs | `assets/icons/*.svg` | Hand-ported from `packages/emcn/src/icons/*.tsx` (upstream, Apache-2.0 like the rest of the repository) | Apache-2.0 (repository `LICENSE`) |

The Mono stack (`SimFonts.mono`) bundles nothing: it names Martian Mono first,
which is not loaded in product either, and falls through to the platform
monospace face.

`tools/check_licenses.dart` (L0 gate, `docs/port/04-test-plan.md`) is expected
to read this table.

## Decision record

- 2026-10-21: the project owner confirmed that Season Sans may be bundled in the Flutter web bundle and the Windows installer (no license file exists in the upstream repo; the font ships there as `apps/sim/app/_styles/fonts/season/SeasonSansUprightsVF.woff2`). See `docs/port/00-plan.md` §9.

# Xen Orchestra for riscv64

Community builds of [Xen Orchestra](https://github.com/vatesfr/xen-orchestra) for `linux/riscv64`,
one per upstream release. Not affiliated with or supported by Vates.

Each [release](../../releases) (kept for 90 days, the newest always kept) is a complete, built source tree: xo-server, the XO 5 (`xo-web`) and
XO 6 (`@xen-orchestra/web`) UIs, and `node_modules` with riscv64 native addons. The source is
upstream's, unmodified, at the commit named in the release notes.

## How it is built

Upstream marks each release with a `feat: release X.Y.Z` commit on `master`. A daily workflow
([release.yml](.github/workflows/release.yml)) looks for a new one and builds it:

| part | where | why |
|---|---|---|
| rolldown and lightningcss napi bindings | x86, cross-compiled at the lockfile's versions | npm ships no riscv64 binaries for them |
| xo-web (XO 5) | x86 runner, riscv64 container under QEMU user-mode | on native riscv64 hardware the build crashes V8 (heap corruption in the gulp/browserify step); under QEMU it completes |
| install, xo-server, XO 6, packaging | native riscv64 ([RISE](https://riseproject.dev) runner `ubuntu-24.04-riscv`) | |

Riscv64-specific build settings: `CXXFLAGS=-DLEVELDB_ATOMIC_PRESENT` (leveldb 1.20 in leveldown has
no riscv64 AtomicPointer), `libfuse-dev` for fuse-native, and a single retry under
`node --predictable` for workspace builds that hit V8 crashes.

## Running it

Needs Node.js >= 22.23 for riscv64 ([unofficial-builds](https://unofficial-builds.nodejs.org/download/release/))
and libfuse2. Unpack, write a config from `packages/xo-server/sample.config.toml`, then
`node packages/xo-server/dist/cli.mjs`. See upstream's
[install-from-sources documentation](https://docs.xen-orchestra.com/getting-started/install-from-sources).

## Licence

Xen Orchestra is AGPL-3.0. The build scripts here are under the same licence.

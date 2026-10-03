# Xen Orchestra for riscv64

Community builds of [Xen Orchestra](https://github.com/vatesfr/xen-orchestra) for `linux/riscv64`,
one per upstream release. Not affiliated with or supported by Vates.

Each [release](../../releases) (kept for 90 days, the newest always kept) is a complete, built source tree: xo-server, the XO 5 (`xo-web`) and
XO 6 (`@xen-orchestra/web`) UIs, and `node_modules` with riscv64 native addons. The source is
upstream's at the commit named in the release notes, with one source change: `fuse-native` is aliased to
[`@cocalc/fuse-native`](https://www.npmjs.com/package/@cocalc/fuse-native), because the original links a bundled
x86-64 libfuse and cannot build on riscv64 ([scripts/patch-source.sh](scripts/patch-source.sh)).
One build tool is also patched after install: `index-modules` sorts its directory listing, so
xo-server's generated module indexes come out in the same order on every machine
([scripts/patch-node-modules.sh](scripts/patch-node-modules.sh)); this only changes import order.

## How it is built

Upstream marks each release with a `feat: release X.Y.Z` commit on `master`. A daily workflow
([release.yml](.github/workflows/release.yml)) looks for a new one and builds it:

| step | where | why |
|---|---|---|
| rolldown and lightningcss napi bindings | x86, cross-compiled at the lockfile's versions | npm ships no riscv64 binaries for them |
| full build: xo-server, xo-web (XO 5), XO 6 | x86 runner, riscv64 container under QEMU user-mode | reference build; xo-web only builds here |
| xo-server and XO 6 again | native riscv64 ([RISE](https://riseproject.dev) runner `ubuntu-24.04-riscv`) | real-hardware build |
| check | native runner | every output file must be byte-identical to the QEMU build, or nothing is released |
| package, release, prune | native runner | complete tree, sha256, releases older than 90 days deleted |

Why the check: Node.js on real riscv64 hardware (seen on SpaceMiT K1 and on the RISE runners, Node 22 to
27-pre) corrupts its own heap during some large builds. Usually that crashes, sometimes it only throws
nonsense errors, and nothing guarantees a build that finishes is correct. The same builds under QEMU have
always completed, and the outputs are reproducible, so the QEMU build is the reference.

Riscv64-specific build settings: `CXXFLAGS=-DLEVELDB_ATOMIC_PRESENT` (leveldb 1.20 in leveldown has
no riscv64 AtomicPointer), `libfuse-dev` for fuse-native, and a single retry under
`node --predictable` for workspace builds that hit V8 crashes.

## Known issue: Node.js on riscv64 hardware

Node.js corrupts its own heap now and then on real riscv64 hardware (seen on SpaceMiT K1 and on the
EM-RV1 machines behind the RISE runners, Node 22 through 27-pre). During builds this is why every
output is checked against a QEMU build. At runtime it can also hit xo-server: one CI start crashed in
`node-openssl-cert` with a nonsense "Received type number (63)" error before the UIs were mounted.
Other starts, including three on a K1 board, came up fine. If xo-server dies with an error like that,
restart it. Not yet reported upstream: no small reproducer yet.

## Running it

Needs Node.js >= 22.23 for riscv64 ([unofficial-builds](https://unofficial-builds.nodejs.org/download/release/))
and libfuse2. Unpack, write a config from `packages/xo-server/sample.config.toml`, then
`node packages/xo-server/dist/cli.mjs`. See upstream's
[install-from-sources documentation](https://docs.xen-orchestra.com/getting-started/install-from-sources).

On boards whose MMU is Sv39 (`grep mmu /proc/cpuinfo`; the SpacemiT K1 is one), set
`NODE_OPTIONS=--disable-wasm-trap-handler`. Without it, 6.9.0 on a K1 started but connected to no host:
every login failed with `WebAssembly.instantiate(): Out of memory: Cannot allocate Wasm memory`, raised
by undici's WebAssembly HTTP parser. Sv39 gives a process 256 GB of address space, and V8 reserves large
guard regions per WebAssembly memory unless its trap handler is off, which is the likely cause; 6.8.2
did not hit it on the same board, and why is not established
([#2](https://github.com/gounthar/xen-orchestra-riscv64/issues/2)). With systemd, as a drop-in:

```ini
# /etc/systemd/system/xo-server.service.d/wasm-sv39.conf
[Service]
Environment=NODE_OPTIONS=--disable-wasm-trap-handler
```

## Licence

Xen Orchestra is AGPL-3.0. The build scripts here are under the same licence.

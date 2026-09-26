// Build a workspace and its workspace dependencies in dependency order,
// without turbo (turbo ships no riscv64 binary). Keeps going on failure
// and prints one line per package, so a run maps every broken build.
// Usage: node .github/scripts/build-deps.mjs <workspace-name>...
//
// BUILT_LIST: file of workspaces already built by an earlier step; they are
// skipped (rebuilding runs their clean script and breaks dependants) and
// every success is appended to it.
// PREDICTABLE_SHIM: directory holding a `node` wrapper that adds
// --predictable. A failed build is retried once with it first on PATH, to
// tell a V8 crash on riscv64 apart from a real build error.
import { execFileSync, spawnSync } from 'node:child_process'
import { appendFileSync, existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const builtList = process.env.BUILT_LIST
const built = new Set(
  builtList !== undefined && existsSync(builtList) ? readFileSync(builtList, 'utf8').split('\n').filter(Boolean) : []
)
const shim = process.env.PREDICTABLE_SHIM
const build = (location, env = process.env) =>
  spawnSync('yarn', ['--cwd', location, 'run', 'build'], { stdio: 'inherit', env }).status

const raw = execFileSync('yarn', ['--silent', 'workspaces', 'info', '--json'], { encoding: 'utf8' })
const info = JSON.parse(raw.slice(raw.indexOf('{')))

const order = []
const seen = new Set()
const visit = name => {
  if (seen.has(name)) return
  seen.add(name)
  if (info[name] === undefined) throw new Error(`unknown workspace: ${name}`)
  for (const dep of info[name].workspaceDependencies) visit(dep)
  order.push(name)
}
process.argv.slice(2).forEach(visit)

let failed = 0
for (const name of order) {
  const { location } = info[name]
  const pkg = JSON.parse(readFileSync(join(location, 'package.json'), 'utf8'))
  if (pkg.scripts?.build === undefined) continue
  if (built.has(name)) {
    console.log(`BUILD skip ${name} (built by an earlier step)`)
    continue
  }
  const start = Date.now()
  let status = build(location)
  let how = ''
  if (status !== 0 && shim !== undefined) {
    status = build(location, { ...process.env, PATH: `${shim}:${process.env.PATH}` })
    how = status === 0 ? ' [only with --predictable]' : ' [also with --predictable]'
  }
  const secs = Math.round((Date.now() - start) / 1000)
  console.log(`BUILD ${status === 0 ? 'ok  ' : 'FAIL'} ${name} (${secs}s)${how}`)
  if (status === 0) {
    built.add(name)
    if (builtList !== undefined) appendFileSync(builtList, name + '\n')
  } else failed++
}
console.log(`${order.length} workspaces in closure, ${failed} build(s) failed`)
process.exitCode = failed === 0 ? 0 : 1

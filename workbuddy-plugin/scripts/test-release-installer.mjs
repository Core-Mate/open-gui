import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import { mkdir, mkdtemp, readFile, realpath, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
if (process.platform !== 'darwin') { console.log('Release installer execution requires macOS.'); process.exit(0) }
const root = fileURLToPath(new URL('..', import.meta.url))
const temporary = await realpath(await mkdtemp(join(tmpdir(), 'opengui-workbuddy-installer-')))
try {
 const home = join(temporary, 'home with spaces'), config = join(home, '.workbuddy'), bin = join(home, 'bin')
 await mkdir(bin, { recursive: true })
 // Only the isolated test host is considered stopped; never quit the real app.
 await writeFile(join(bin, 'pgrep'), '#!/bin/sh\nexit "${TEST_HOST_RUNNING:-1}"\n', {mode:0o755})
 const runtime = join(config, 'opengui/runtime', `node-v22.23.2-darwin-${process.arch}`)
 await mkdir(join(runtime, 'bin'), { recursive: true })
 await writeFile(join(runtime, 'bin/node'), '#!/bin/sh\nexec ' + JSON.stringify(process.execPath) + ' "$@"\n', { mode:0o755 })
 const digest = createHash('sha256').update(await readFile(join(runtime, 'bin/node'))).digest('hex')
 const sha = process.arch === 'arm64' ? '61130f394c1630d211dd50aecc4353d379480f36d3ac913cd85dbba1aed585c6' : '58e99022c2ff89395576cc7fd4d98cea24bb68081475d5f88b801ee8729fb026'
 await writeFile(join(runtime, '.verified'), sha + '\n' + digest + '\n')
 await writeFile(join(config, 'mcp.json'), JSON.stringify({mcpServers:{other:{command:'keep-me'}}}))
 await writeFile(join(config, 'settings.json'), JSON.stringify({custom:true,hooks:{Stop:[{hooks:[{type:'command',command:'other-hook'}]}]}}))
 const archive = join(root, 'dist/opengui-mcp-0.2.0.tgz')
 const run = (extra={}) => spawnSync('bash', [join(root, 'scripts/install-macos.command'), '--archive', archive], {encoding:'utf8',env:{...process.env,HOME:home,PATH:bin+':'+process.env.PATH,...extra}})
 let result=run({TEST_HOST_RUNNING:'0'}); assert.notEqual(result.status,0); assert.match(result.stderr,/Quit WorkBuddy/)
 for (let i=0;i<2;i++) {
  result=run(); assert.equal(result.status,0,result.stderr+'\n'+result.stdout)
  const mcp=JSON.parse(await readFile(join(config,'mcp.json'))), settings=JSON.parse(await readFile(join(config,'settings.json')))
  assert.equal(mcp.mcpServers.other.command,'keep-me'); assert.equal(settings.custom,true)
  assert.equal(settings.hooks.Stop.length,2)
  assert.match(await readFile(join(config,'skills/opengui/SKILL.md'),'utf8'),/opengui/)
  const state=JSON.parse(await readFile(join(config,'opengui/local-install.json')))
  assert.equal(state.version,'0.2.0'); assert(state.backups.every(b=>b.backup===null || b.backup.includes('before-opengui')))
  assert((await readFile(join(state.packageDir,'scripts/install-local.mjs'),'utf8')).includes('mergeHostHooks'))
 }
 console.log('PASS: real prebuilt npm install, native dependency import, packaged config installer, upgrade, retained foreign MCP/Hooks, paths with spaces and running-host rejection.')
} finally { await rm(temporary,{recursive:true,force:true}) }

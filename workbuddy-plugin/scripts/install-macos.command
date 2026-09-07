#!/bin/bash
# Install a prebuilt release without a source checkout or system Node.
set -euo pipefail
umask 077
HOST=workbuddy
VERSION=0.2.0
ARCHIVE_NAME=opengui-mcp-$VERSION.tgz
usage() {
  echo "OpenGUI for $HOST $VERSION (macOS arm64/x64)"
  echo "Usage: bash $0 [--archive /absolute/path/$ARCHIVE_NAME]"
  echo 'Downloads a verified prebuilt package and private Node. No sudo or source build.'
  echo 'Finish existing OpenGUI tasks before upgrading. Keep old packages for rollback.'
}
archive=
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --archive) [ "$#" = 2 ] || { usage; exit 1; }; archive=$2 ;;
  '') [ "$#" = 0 ] || { usage; exit 1; } ;;
  *) usage; exit 1 ;;
esac
[ "$(uname -s)" = Darwin ] || { echo 'Only macOS is supported.' >&2; exit 1; }
case "$(uname -m)" in
  arm64) arch=arm64; node_sha=61130f394c1630d211dd50aecc4353d379480f36d3ac913cd85dbba1aed585c6 ;;
  x86_64) arch=x64; node_sha=58e99022c2ff89395576cc7fd4d98cea24bb68081475d5f88b801ee8729fb026 ;;
  *) echo 'Unsupported architecture.' >&2; exit 1 ;;
esac
if pgrep -x WorkBuddy >/dev/null; then echo 'Quit WorkBuddy after finishing OpenGUI tasks and closing its mirrors, then rerun this installer.' >&2; exit 1; fi
# Refuse redirected parent directories before creating installation state.
private_dir() {
  local path=$1 cursor=$1
  while [ "$cursor" != / ]; do
    [ ! -L "$cursor" ] || { echo "Refusing symlink: $cursor" >&2; exit 1; }
    cursor=$(dirname "$cursor")
  done
  mkdir -p "$path"
  [ "$(stat -f '%u' "$path")" = "$(id -u)" ] || { echo "Not owned by current user: $path" >&2; exit 1; }
}
root="$HOME/.workbuddy/opengui"
case "$root" in /*) ;; *) echo 'Installation home must be absolute.' >&2; exit 1 ;; esac
private_dir "$root"
lock="$root/installer.lock"
mkdir "$lock" 2>/dev/null || { echo "Installation busy or interrupted: inspect $lock before retrying." >&2; exit 1; }
temporary=
runtime_lock_owned=false
cleanup() {
  [ -z "$temporary" ] || rm -rf "$temporary"
  if [ "$runtime_lock_owned" = true ]; then rmdir "$root/runtime/install.lock"; fi
  rmdir "$lock"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
temporary=$(mktemp -d "$root/.install.XXXXXXXX")
fetch() {
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --location \
    --connect-timeout 15 --max-time 240 --retry 2 "$1" -o "$2"
}
if [ -z "$archive" ]; then
  base="https://github.com/Core-Mate/OpenGUI/releases/download/opengui-$HOST-v$VERSION"
  archive="$temporary/$ARCHIVE_NAME"
  if ! fetch "$base/$ARCHIVE_NAME" "$archive" || ! fetch "$base/$ARCHIVE_NAME.sha256" "$archive.sha256"; then
    echo "No downloadable $HOST $VERSION package, or network unavailable. Check the release page; installation stopped without changing host configuration." >&2
    exit 1
  fi
fi
[ -f "$archive" ] && [ -f "$archive.sha256" ] || { echo 'Archive and adjacent .sha256 file are required.' >&2; exit 1; }
# Parse the digest only. Never trust a sidecar filename as a local path.
expected=$(awk 'NR == 1 { print $1 }' "$archive.sha256")
[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo 'Invalid SHA-256 sidecar.' >&2; exit 1; }
[ "$(shasum -a 256 "$archive" | awk '{print $1}')" = "$expected" ] || { echo 'Archive checksum mismatch; nothing installed.' >&2; exit 1; }
cp "$archive" "$temporary/verified.tar.gz"
# Recheck our private copy to avoid using a source archive changed during copy.
[ "$(shasum -a 256 "$temporary/verified.tar.gz" | awk '{print $1}')" = "$expected" ] || exit 1
private_dir "$root/runtime"
node_name="node-v22.23.2-darwin-$arch"
node_dir="$root/runtime/$node_name"
node="$node_dir/bin/node"
valid_node() {
  [ ! -L "$node_dir" ] && [ ! -L "$node_dir/bin" ] && [ ! -L "$node" ] && [ -x "$node" ] && [ -f "$node_dir/.verified" ] || return 1
  [ "$(sed -n '1p' "$node_dir/.verified")" = "$node_sha" ] &&
    [ "$(sed -n '2p' "$node_dir/.verified")" = "$(shasum -a 256 "$node" | awk '{print $1}')" ]
}
if ! valid_node; then
  mkdir "$root/runtime/install.lock" 2>/dev/null || { echo "Runtime setup is busy; retry when the current setup finishes." >&2; exit 1; }
  runtime_lock_owned=true
  [ ! -e "$node_dir" ] && [ ! -L "$node_dir" ] || { echo "Invalid existing Node runtime: $node_dir. No running runtime was overwritten." >&2; exit 1; }
  echo 'Preparing private Node.js 22.23.2 (~50 MB); no system installation.'
  fetch "https://nodejs.org/dist/v22.23.2/$node_name.tar.gz" "$temporary/node.tar.gz"
  [ "$(shasum -a 256 "$temporary/node.tar.gz" | awk '{print $1}')" = "$node_sha" ] || { echo 'Node checksum mismatch.' >&2; exit 1; }
  tar -xzf "$temporary/node.tar.gz" -C "$temporary"
  printf '%s\n%s\n' "$node_sha" "$(shasum -a 256 "$temporary/$node_name/bin/node" | awk '{print $1}')" > "$temporary/$node_name/.verified"
  mv "$temporary/$node_name" "$node_dir"
fi
"$node" - "$root" "$temporary/verified.tar.gz" "$VERSION" <<'INSTALL_JS'
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const [root, archive, version] = process.argv.slice(2);
const packages = path.join(root, 'packages');
fs.mkdirSync(packages, { recursive: true });
if (fs.lstatSync(packages).isSymbolicLink()) throw Error('Redirected packages directory');
const install = fs.mkdtempSync(path.join(packages, version + '-'));
const npm = path.resolve(process.execPath, '../../lib/node_modules/npm/bin/npm-cli.js');
execFileSync(process.execPath, [npm, 'install', '--prefix', install, '--ignore-scripts', '--no-audit', '--no-fund', archive], { stdio: 'inherit' });
const pkg = path.join(install, 'node_modules/opengui-mcp');
const meta = JSON.parse(fs.readFileSync(path.join(pkg, 'package.json')));
if (meta.name !== 'opengui-mcp' || meta.version !== version) throw Error('Archive package/version mismatch');
// Verify native dependencies before switching the host configuration.
execFileSync(process.execPath, ['--input-type=module', '-e', 'await import("sharp"); await import("@modelcontextprotocol/sdk/client/index.js")'], { cwd: pkg, stdio: 'inherit' });
execFileSync(process.execPath, [path.join(pkg, 'scripts/install-local.mjs'), '--package-dir', pkg, '--node', process.execPath], { stdio: 'inherit' });
console.log('Installed MCP, Skill and lifecycle Hooks. Reopen WorkBuddy, trust OpenGUI MCP, choose /opengui and ask to list phones without operating them.');
console.log('Rollback backups: ' + path.join(root, 'local-install.json') + '. Old packages are retained.');

INSTALL_JS

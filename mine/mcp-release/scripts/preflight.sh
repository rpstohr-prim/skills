#!/usr/bin/env bash
# MCP release pre-flight: everything about an npm + MCP Registry release that
# needs no credentials. Run it in a clean checkout of the commit you will
# publish (a fresh worktree of origin/main). Exits non-zero on any FAIL.
#
#   preflight.sh [mcp_dir]            # default: ./mcp-server if present, else .
#
# Env overrides:
#   MCP_KEY_FILE       registry signing key (32-byte ed25519 seed, hex)  default ~/mcp_priv_hex.txt
#   MCP_VERSION_GLOB   source files to scan for a hard-coded version     default src/**/*.ts
#   SKIP_BUILD=1       skip npm ci / build / test / pack
set -uo pipefail

DIR="${1:-}"
if [[ -z "$DIR" ]]; then
  if [[ -f mcp-server/server.json ]]; then DIR=mcp-server; else DIR=.; fi
fi
cd "$DIR" || { echo "FAIL  cannot cd into $DIR"; exit 1; }

KEY_FILE="${MCP_KEY_FILE:-$HOME/mcp_priv_hex.txt}"
FAILS=0
WARNS=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
warn() { printf '  WARN  %s\n' "$1"; WARNS=$((WARNS + 1)); }
section() { printf '\n== %s\n' "$1"; }
json() { node -e "const d=require('./$1');const v=($2);process.stdout.write(v==null?'':String(v))" 2>/dev/null; }

for f in package.json server.json; do
  [[ -f "$f" ]] || { echo "FAIL  $f not found in $(pwd)"; exit 1; }
done
command -v node >/dev/null || { echo "FAIL  node is required"; exit 1; }

PKG_NAME=$(json package.json 'd.name')
PKG_VER=$(json package.json 'd.version')
MCP_NAME=$(json package.json 'd.mcpName')
SRV_NAME=$(json server.json 'd.name')
SRV_VER=$(json server.json 'd.version')
SRV_PKG_VER=$(json server.json "(d.packages||[]).find(p=>p.identifier==='$PKG_NAME')?.version")
SRV_SCHEMA=$(json server.json 'd["$schema"]')

echo "Release candidate: $PKG_NAME@$PKG_VER  /  registry $SRV_NAME@$SRV_VER"
echo "Folder: $(pwd)   Commit: $(git rev-parse --short HEAD 2>/dev/null || echo n/a)"

# ── 1. Versions agree everywhere ────────────────────────────────────────────
section "Versions"
[[ -n "$PKG_VER" && "$PKG_VER" == "$SRV_VER" ]] && pass "package.json and server.json both $PKG_VER" \
  || fail "package.json ($PKG_VER) != server.json version ($SRV_VER)"
if [[ -n "$SRV_PKG_VER" ]]; then
  [[ "$SRV_PKG_VER" == "$PKG_VER" ]] && pass "server.json packages[$PKG_NAME].version is $SRV_PKG_VER" \
    || fail "server.json packages[$PKG_NAME].version is $SRV_PKG_VER, expected $PKG_VER"
else
  warn "server.json has no npm package entry for $PKG_NAME (remote-only listing?)"
fi
[[ "$MCP_NAME" == "$SRV_NAME" ]] && pass "package.json mcpName matches server.json name ($SRV_NAME)" \
  || fail "package.json mcpName ($MCP_NAME) != server.json name ($SRV_NAME) — the registry uses this to prove npm ownership"
# Hard-coded version constants in source (e.g. SERVER_VERSION = "1.0.0").
STALE=$(grep -rnE '(VERSION|version)[A-Za-z_]*\s*[=:]\s*"[0-9]+\.[0-9]+\.[0-9]+"' src 2>/dev/null | grep -v "\"$PKG_VER\"" | grep -viE 'protocol|schema|node' || true)
if [[ -n "$STALE" ]]; then
  fail "source has a version constant that isn't $PKG_VER:"; echo "$STALE" | sed 's/^/          /'
else
  pass "no stale version constants in src/"
fi

# ── 2. Registry schema ──────────────────────────────────────────────────────
section "server.json"
DESC_LEN=$(json server.json '(d.description||"").length')
(( DESC_LEN <= 100 )) && pass "description is $DESC_LEN chars (registry max 100)" || fail "description is $DESC_LEN chars (registry max 100)"
if command -v mcp-publisher >/dev/null; then
  OUT=$(mcp-publisher validate 2>&1)
  if grep -q "is valid" <<<"$OUT"; then
    pass "mcp-publisher validate: valid ($SRV_SCHEMA)"
  else
    fail "mcp-publisher validate rejected server.json:"; echo "$OUT" | grep -vE '^\s*$' | tail -8 | sed 's/^/          /'
    grep -q "Expected current schema" <<<"$OUT" && echo "          → bump \$schema to the version it names; field names usually carry over unchanged"
  fi
else
  warn "mcp-publisher not installed — cannot validate server.json"
fi

# ── 3. Wording vs. capabilities ─────────────────────────────────────────────
section "Wording"
if grep -rqE 'readOnlyHint:\s*false' src 2>/dev/null; then
  HITS=$(grep -niE 'read-only\.|read only\.|all tools are read-only' package.json README.md server.json 2>/dev/null || true)
  [[ -z "$HITS" ]] && pass "server has write tools and nothing claims it is read-only" \
    || { fail "server has write tools but the listing text says read-only:"; echo "$HITS" | sed 's/^/          /'; }
else
  pass "all tools read-only (no readOnlyHint:false in src/)"
fi

# ── 4. Build, test, package ─────────────────────────────────────────────────
section "Build"
if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  warn "SKIP_BUILD=1 — build/test/pack not checked"
else
  npm ci --no-audit --no-fund >/dev/null 2>&1 && pass "npm ci" || fail "npm ci failed"
  npm run build >/dev/null 2>&1 && pass "npm run build" || fail "npm run build failed"
  if node -e 'process.exit(require("./package.json").scripts?.test?0:1)'; then
    npm test >/dev/null 2>&1 && pass "npm test" || fail "npm test failed (run it to see why)"
  fi
  PACK=$(npm pack --dry-run 2>&1)
  FILES=$(grep -oE 'total files: *[0-9]+' <<<"$PACK" | grep -oE '[0-9]+$')
  SIZE=$(grep -oE 'package size: *[0-9.]+ *[kMG]?B' <<<"$PACK" | sed 's/package size: *//')
  pass "npm pack: $FILES files, $SIZE"
  grep -E 'notice [0-9.]+[kMG]?B ' <<<"$PACK" | sed 's/npm notice/         /'
  grep -q "errors corrected" <<<"$PACK" && warn "npm will auto-correct package.json on publish (run 'npm pkg fix' to see)"
fi

# ── 5. Not already published ────────────────────────────────────────────────
section "Published versions"
NPM_VER=$(npm view "$PKG_NAME" version --prefer-online 2>/dev/null || echo "")
newer() { node -e 'const p=s=>s.split(".").map(Number);const [a,b]=[p(process.argv[1]),p(process.argv[2])];for(let i=0;i<3;i++){if(a[i]!==b[i])process.exit(a[i]>b[i]?0:1)}process.exit(1)' "$1" "$2"; }
if [[ -z "$NPM_VER" ]]; then
  warn "npm has no $PKG_NAME yet (first publish)"
elif [[ "$NPM_VER" == "$PKG_VER" ]]; then
  warn "npm already has $PKG_VER — skip the npm step, do the registry step only"
elif newer "$PKG_VER" "$NPM_VER"; then
  pass "npm is at $NPM_VER; $PKG_VER is newer"
else
  fail "npm is at $NPM_VER, which is not older than $PKG_VER"
fi
REG_VERS=$(curl -fsS "https://registry.modelcontextprotocol.io/v0/servers/$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$SRV_NAME")/versions" 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{try{const d=JSON.parse(s);console.log((d.servers||[]).map(x=>(x.server||x).version).join(" "))}catch{}})' || true)
if [[ -z "$REG_VERS" ]]; then
  warn "registry has no versions of $SRV_NAME (first publish, or lookup failed)"
elif grep -qw "$SRV_VER" <<<"$REG_VERS"; then
  warn "registry already has $SRV_VER (versions: $REG_VERS)"
else
  pass "registry has: $REG_VERS"
fi

# ── 6. Registry signing key (DNS auth) ──────────────────────────────────────
section "Registry key"
# com.example/server  →  example.com
DOMAIN=$(node -e 'const ns=process.argv[1].split("/")[0];process.stdout.write(ns.split(".").reverse().join("."))' "$SRV_NAME")
if [[ "$SRV_NAME" != *.*/* ]]; then
  warn "$SRV_NAME is not a domain namespace — DNS auth not used"
elif [[ ! -f "$KEY_FILE" ]]; then
  fail "no key file at $KEY_FILE (see references/troubleshooting.md → lost key)"
else
  PERM=$(stat -f '%Lp' "$KEY_FILE" 2>/dev/null || stat -c '%a' "$KEY_FILE")
  [[ "$PERM" == "600" ]] && pass "key file is owner-only (600)" || warn "key file permissions are $PERM — run: chmod 600 $KEY_FILE"
  DNS_PUB=$(dig +short TXT "$DOMAIN" 2>/dev/null | tr -d '"' | grep -o 'v=MCPv1;[^"]*' | grep -oE 'p=[A-Za-z0-9+/=]+' | head -1 | cut -c3-)
  if [[ -z "$DNS_PUB" ]]; then
    fail "no 'v=MCPv1; k=ed25519; p=…' TXT record on $DOMAIN (must be on the apex, not _mcp.)"
  else
    MATCH=$(node -e '
      const fs=require("fs"),c=require("crypto");
      const hex=fs.readFileSync(process.argv[1],"utf8").trim();
      if(!/^[0-9a-fA-F]{64}$/.test(hex)){process.stdout.write("badformat");process.exit()}
      const der=Buffer.concat([Buffer.from("302e020100300506032b657004220420","hex"),Buffer.from(hex,"hex")]);
      const pub=c.createPublicKey(c.createPrivateKey({key:der,format:"der",type:"pkcs8"})).export({format:"der",type:"spki"}).subarray(-32).toString("base64");
      process.stdout.write(pub===process.argv[2]?"yes":"no");' "$KEY_FILE" "$DNS_PUB")
    case "$MATCH" in
      yes) pass "key file matches the public key in $DOMAIN's DNS" ;;
      badformat) fail "key file is not a 64-character hex ed25519 seed" ;;
      *) fail "key file does NOT match the public key in $DOMAIN's DNS (see references/troubleshooting.md → lost key)" ;;
    esac
  fi
fi

# ── Summary ─────────────────────────────────────────────────────────────────
printf '\n'
if (( FAILS > 0 )); then
  echo "PRE-FLIGHT FAILED: $FAILS failure(s), $WARNS warning(s). Fix these before publishing."
  exit 1
fi
echo "PRE-FLIGHT PASSED ($WARNS warning(s)). Publish from: $(pwd)"
echo
echo "  1) npm:       npm publish '--//registry.npmjs.org/:_authToken=YOUR_TOKEN'    (or: npm login && npm publish)"
echo "     verify:    npm view $PKG_NAME version          → $PKG_VER"
echo "  2) registry:  mcp-publisher login dns --domain $DOMAIN --private-key \"\$(cat $KEY_FILE)\""
echo "                mcp-publisher publish                 (right after login — the token is short-lived)"

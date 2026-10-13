---
name: mcp-release
description: >-
  Release an MCP server to npm and the official MCP Registry
  (registry.modelcontextprotocol.io) safely. Use when the user says "publish the
  MCP server", "release to npm", "publish to the MCP registry", "bump the MCP
  version", "mcp-publisher", "server.json", or is shipping a new version of an
  npm-packaged MCP server with a domain-namespaced registry entry (e.g.
  com.example/server). Also use when an npm publish fails with 404 / E404 on a
  scoped package, when mcp-publisher says the JWT token is expired, when
  server.json fails validation or uses a deprecated schema, or when the registry
  DNS signing key is lost.
metadata:
  version: 1.0.0
---

# MCP release (npm + MCP Registry)

A release touches three places that must agree: the npm package, the registry's
`server.json`, and (if there is one) the hosted server. Most failures are not
code bugs; they come from stale metadata, publish order, or credentials. So the
release runs as a **pre-flight that needs no credentials**, then **two
credentialed commands the user runs themselves**.

**Never run the credentialed commands yourself, and never print, paste or ask for
the npm token or the registry key.** Hand the user the exact commands. Keys are
read from files with `"$(cat …)"`, so they never pass through the conversation.

## 0. Before the release

- The version bump is merged to main in **all** places: `package.json` (+ lock
  via `npm version X --no-git-tag-version`), `server.json` `version` **and**
  `packages[].version`, and any hard-coded version constant in source.
- If there is a hosted (remote) server, it is deployed from that main **before**
  the registry listing points people at new behavior. If the hosted server calls
  a backend API, deploy the backend first.
- Listing text matches capabilities. Once any tool has `readOnlyHint: false`,
  remove "read-only" from the npm description, README and directory listings.

## 1. Release folder

Publish from a clean checkout of exactly what is on main. Never use a working
checkout, which may be stale or carry local edits:

```bash
git fetch origin
git worktree add ../<Repo>-mcp-release -b release/mcp-<version>-local origin/main
```

The local branch is throwaway and is never pushed.

## 2. Pre-flight

```bash
bash ~/.claude/skills/mcp-release/scripts/preflight.sh ../<Repo>-mcp-release/<mcp-dir>
```

It checks that versions agree everywhere, that `mcpName` equals the registry name,
`mcp-publisher validate` (current schema, description ≤ 100 chars), and that nothing
says read-only when write tools exist. It also builds, tests and previews the npm
package, confirms the version isn't already on npm or the registry, and verifies
`~/mcp_priv_hex.txt` matches the `v=MCPv1` TXT record on the apex domain. It exits
non-zero on any FAIL and prints the publish commands on success.

A FAIL in versions, schema or wording means fixing it through a normal PR, merging,
and recreating the release folder from the new main. Don't hand-edit the release
folder; what's published should be what's on main.

## 3. Publish — the user runs these, in this order

1. **npm first.** The registry verifies the npm package exists at that version.
   ```bash
   npm publish '--//registry.npmjs.org/:_authToken=YOUR_TOKEN'    # or: npm login && npm publish
   npm view <pkg> version --prefer-online                         # must print the new version
   ```
2. **Registry, login and publish back to back.** The login token is short-lived.
   ```bash
   mcp-publisher login dns --domain <domain> --private-key "$(cat ~/mcp_priv_hex.txt)"
   mcp-publisher publish
   ```
   Success prints "✓ Successfully published".

## 4. Verify, then clean up

```bash
curl -s "https://registry.modelcontextprotocol.io/v0/servers/<url-encoded name>/versions"
```

The new version should be listed with `isLatest: true`. Registry search can lag,
so check the `/versions` endpoint, not search. Then remove the release worktree
and its local branch.

If anything fails, read `references/troubleshooting.md` before guessing. It
covers npm 404 on publish (an auth problem, not a missing package), expired
registry tokens, deprecated schemas, version conflicts, and recovering or
rotating a lost DNS signing key without breaking the shared apex TXT record.

## Project notes: FTS Studio MCP (FTS-Web repo)

- Package `@fts-studio/studio-mcp` in `mcp-server/`; registry name
  `com.fintechstudios/studio`; DNS key on `fintechstudios.com` (Cloud DNS zone
  `fintechstudios-com`, project `elasticsearch-496414`; the apex TXT is shared
  with SPF and verification records).
- Version lives in `mcp-server/package.json`, `mcp-server/server.json` (×2) and
  `SERVER_VERSION` in `mcp-server/src/server.ts`.
- Hosted server: Cloud Run `fts-studio-mcp` (us-central1), deployed with
  `gcloud run deploy fts-studio-mcp --source ./mcp-server …` from a clean origin/main
  worktree. Merging does not deploy. Studio (Replit) needs its own Publish when
  the MCP tools call new Studio endpoints.
- Release while a directory review (OpenAI / Anthropic) is pending only if the
  user agrees, because a version bump changes what reviewers see.

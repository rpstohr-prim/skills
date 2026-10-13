# MCP release troubleshooting

Every entry here happened on a real release (FTS Studio MCP, Sept–Oct 2026).

## npm

| Symptom | Cause | Fix |
|---|---|---|
| `npm error 404 Not Found - PUT https://registry.npmjs.org/@scope%2fpkg` and "is not in this registry" | **Authorization**, not a missing package. For scoped packages npm answers an unauthorized publish with 404 so it doesn't reveal the package exists. Token expired, read-only, wrong scope, or the `YOUR_TOKEN` placeholder was left in. | `npm whoami '--//registry.npmjs.org/:_authToken=TOKEN'` — 401 means the token is bad. Either `npm login` then `npm publish` (one-time code), or create a Granular token: Packages and scopes → Read and write on the scope, optional "bypass 2FA". |
| `npm warn publish npm auto-corrected some errors in your package.json` (bin script name, repository.url) | Cosmetic normalization. | Harmless. `npm pkg fix` rewrites package.json to the normalized form if you want the warning gone. |
| `npm view pkg version` still shows the old version right after publishing | npm CDN cache. | `npm view pkg version --prefer-online`, or `curl -s https://registry.npmjs.org/@scope%2fpkg` and read `dist-tags.latest`. |
| `E403 You cannot publish over the previously published versions` | That version is already on npm. npm never allows re-publishing a version, even after unpublish. | Bump the version (patch) everywhere and release that. |

## MCP Registry

| Symptom | Cause | Fix |
|---|---|---|
| `401 … Invalid or expired Registry JWT token … token is expired` | `mcp-publisher publish` used a token saved by an earlier `login`; registry tokens are short-lived. | Run `mcp-publisher login dns …` and `mcp-publisher publish` back to back. |
| `mcp-publisher validate`: "deprecated schema detected … Expected current schema: …/2025-12-11/…" plus `additionalProperties … not allowed` | `$schema` in server.json pins an old schema version. The "not allowed" errors are the old schema rejecting newer field names. | Change `$schema` to the version it names and re-validate. In Oct 2026 (2025-07-09 → 2025-12-11) nothing else needed to change. |
| publish rejects the package / "package not found" | npm doesn't have the version server.json points to yet. | Always publish npm first; confirm `npm view` shows it; then registry. |
| publish rejects with a version conflict | Registry already has that version (often because publish was run from a stale checkout whose server.json still had the old version). | Publish only from the release worktree; check `server.json` version before publishing. |
| description rejected | Registry caps `description` at 100 characters. | Shorten it. |

## DNS auth key

The registry proves you own `com.example/...` by checking an ed25519 signature
against a TXT record on the **apex** domain (`example.com`, not `_mcp.example.com`):

```
v=MCPv1; k=ed25519; p=<base64 32-byte public key>
```

`mcp-publisher login dns --domain example.com --private-key <hex>` wants the
**32-byte seed as 64 hex characters** (Go's `ed25519.NewKeyFromSeed`), not a PEM
and not the 44-character base64 public key.

Keep the seed in `~/mcp_priv_hex.txt` (chmod 600) so commands read it with
`"$(cat ~/mcp_priv_hex.txt)"` and it never has to be pasted.

### Check the key matches DNS (without printing it)

`scripts/preflight.sh` does this. By hand:

```bash
node -e '
const fs=require("fs"),c=require("crypto");
const seed=Buffer.from(fs.readFileSync(process.env.HOME+"/mcp_priv_hex.txt","utf8").trim(),"hex");
const der=Buffer.concat([Buffer.from("302e020100300506032b657004220420","hex"),seed]);
console.log(c.createPublicKey(c.createPrivateKey({key:der,format:"der",type:"pkcs8"})).export({format:"der",type:"spki"}).subarray(-32).toString("base64"));'
dig +short TXT example.com | grep MCPv1
```

### Lost key — in order of preference

1. **Look where it was last typed.** If the original `mcp-publisher login … --private-key <hex>`
   was run interactively, it is in `~/.zsh_history`. Extract the 64-hex value from that
   line, test it against DNS with the check above, and if it matches write it to
   `~/mcp_priv_hex.txt` (chmod 600). Never echo it. Then consider deleting that history line.
2. **Password manager / notes.**
3. **Rotate.** Generate a new pair and replace only the `v=MCPv1` value in the apex TXT:

   ```bash
   node -e '
   const c=require("crypto"),fs=require("fs");
   const {publicKey,privateKey}=c.generateKeyPairSync("ed25519");
   const seed=privateKey.export({format:"der",type:"pkcs8"}).subarray(-32).toString("hex");
   fs.writeFileSync(process.env.HOME+"/mcp_priv_hex.txt",seed,{mode:0o600});
   console.log("v=MCPv1; k=ed25519; p="+publicKey.export({format:"der",type:"spki"}).subarray(-32).toString("base64"));'
   ```

   **The apex TXT record is usually shared** (SPF, Google/Microsoft site verification,
   Zendesk, mail vendors). In Cloud DNS it is one record set with many values —
   replacing the whole set breaks email and verifications. Read the current values
   first, change only the `v=MCPv1…` string, write the full set back, and diff
   before/after:

   ```bash
   gcloud dns record-sets describe example.com. --type=TXT --zone=<zone> --project=<project>
   gcloud dns record-sets update example.com. --type=TXT --zone=<zone> --project=<project> \
     --ttl=<same ttl> --rrdatas='"v=spf1 …"','"google-site-verification=…"',…,'"v=MCPv1; k=ed25519; p=NEW"'
   ```

   Wait for `dig +short TXT example.com` to show the new value, then log in.
   The old key stops working; nothing else uses it.

# Studio on GCP — troubleshooting

Start with `scripts/studio-status.sh prod`. Every command below assumes
`K="kubectl --context gke_elasticsearch-496414_us-central1-b_fts-prod-gcp"`.

## Symptoms

| Symptom | Likely cause | Check / fix |
|---|---|---|
| Site down, `/api/health` not 200 | Pod not ready, or LB lost its backend | `$K -n studio-prod get pods`; `describe pod` events. If the pod is fine, check `$K -n studio-prod get ingress studio` and the managed certificates |
| Pod `Init:0/1` for minutes | Secrets can't mount, or the Cloud SQL proxy can't start | `$K -n studio-prod describe pod -l app=studio` — `FailedMount … PermissionDenied` → grant the secret to `studio-app-db@` (re-run `sync-secrets.sh`); `SecretProviderClass not found` → run `sync-secrets.sh`; proxy errors → `$K … logs deploy/studio -c cloud-sql-proxy` |
| Pod `CrashLoopBackOff` | App threw at startup | `$K … logs deploy/studio -c studio --previous`. `SESSION_SECRET must be at least 32 characters` → secret missing from `secrets.txt`/mount |
| Every request 401/blank after a deploy | DB unreachable or wrong `DATABASE_URL` | proxy logs; `DATABASE_URL` must be the 127.0.0.1 IAM form from the ConfigMap |
| Everyone gets 429 "Too many login attempts" | `TRUST_PROXY_HOPS` not `2` → all visitors share the LB's IP | fix the ConfigMap; a restart also clears the in-memory limiter |
| Login loops / Auth0 "callback URL mismatch" | Host not allowed in Auth0, or `AUTH0_BASE_URL` wrong | allow `https://<host>/api/auth/auth0/callback`; ConfigMap `AUTH0_BASE_URL` must equal the host |
| Browser POSTs fail with CORS errors | Host missing from the hard-coded list | add it to `ALLOWED_ORIGINS` |
| "Error seeding credential … relation does not exist" | Empty database | restore data before starting the app |
| Briefs/newsletters not sending | Jobs off, or schedulers didn't start | log should NOT contain `DISABLE_BACKGROUND_JOBS=true — schedulers not started` in prod |
| Duplicate emails | More than one pod ran schedulers | `replicas` must be 1; a rollout overlaps for seconds only |
| Deploy workflow fails at "auth" | Branch not allowed for that deployer | prod deploys only from `main`; use the dev workflow for branches |
| Deploy fails in Cloud Build | Build error or missing permission | Cloud Build history → the failing step's log; `storage.objects.get` denied → the build SA needs read on `gs://elasticsearch-496414_cloudbuild` |
| `kubectl` times out on `10.x.x.x` | Current-context points at another cluster | pass `--context` explicitly (don't switch it) |

## Log lines that are normal

Seen on a healthy production pod — not incidents:

- `openrouter: No key found for user` — the HubSpot sync checks OpenRouter usage for every user; most never got a key.
- `CreditDeniedError: Insufficient credits (balance: 0 …)` from `fts` / `brave-search` / `newsapi`, and `Recipe failed … Insufficient credits` — that user's Studio credits are used up.
- `error-handler: System admin check failed` / `Failed to check Brief session ownership` with `ACCESS_DENIED` — a non-admin or other user's id hit a protected route (the client probes `/api/system-admin/verify` on every page).
- `heygen: User custom avatar sync failed … not configured` — user hasn't connected HeyGen.
- `hubspot-scheduler: Failed to sync user … 409 Contact already exists` — known HubSpot de-dup gap, not new.

## Log lines that need someone

- `v1-api: Unhandled error … OpenRouter error: 402 … exceed your available credits` — the OpenRouter **account** is low; top it up.
- `… 403 Key limit exceeded (monthly limit)` — one API customer's OpenRouter key hit its monthly cap.
- `support-github-sync: … 401 Bad credentials` — `GITHUB_TOKEN` in Studio Credentials expired; replace it in System Admin.
- Anything at level 60 (fatal), or `uncaught_exception` — the process will restart; read the stack.

## Summarise errors quickly

```bash
$K -n studio-prod logs deploy/studio -c studio --since=3h > /tmp/studio.log
grep -E '"level":(50|60)' /tmp/studio.log | python3 -c '
import sys,json,collections
c=collections.Counter(); ex={}
for l in sys.stdin:
    try: d=json.loads(l)
    except Exception: continue
    k=(d.get("module"),d.get("msg")); c[k]+=1
    ex.setdefault(k,str((d.get("err") or {}).get("message") or d.get("error") or "")[:160])
for k,n in c.most_common(20): print(n,k,"->",ex[k])'
```

## Rollback ladder

1. `$K -n studio-prod rollout undo deployment/studio` — previous image, ~1 min.
2. `set image … studio:<build-id>` — a specific older build (ids in Cloud Build history).
3. `git revert` on `main` via PR — permanent; redeploys automatically.
4. Data: Cloud SQL backups / point-in-time recovery on `studio-prod-db` (7 days). Restores are disruptive — get sign-off.

# Studio on GCP — operations detail

Read this when changing config, secrets or infrastructure. Source of truth for the
manifests is the FTS-Web repo's `deploy/gke/` (README there lists every resource).

## Always pass the context

Several sessions on one machine share `~/.kube/config`, and other projects switch
its current-context (e.g. the Waypoint cluster). Never rely on it and never
switch it — pass the context on every command:

```bash
K="kubectl --context gke_elasticsearch-496414_us-central1-b_fts-prod-gcp"
$K -n studio-prod get pods
```

## How a deploy is wired

| Step | Prod | Dev |
|---|---|---|
| Trigger | push to `main` | push to `dev`, or `workflow_dispatch` on any branch |
| Workflow | `.github/workflows/deploy-gke.yml` | `.github/workflows/deploy-gke-dev.yml` |
| Signs in as (WIF `github-pool`/`fts-web`) | `studio-deployer@` — `refs/heads/main` only | `studio-dev-deployer@` — any branch |
| Build config / runs as | `deploy/gke/cloudbuild.yaml` / `studio-build@` | `cloudbuild-dev.yaml` / `studio-dev-build@` |
| Image tags | `fts-app/studio:<build-id>`, `:latest` | `:<build-id>`, `:dev-latest` |
| Can deploy into | `studio-prod` only | `studio-dev` only |

So a feature branch cannot reach production, and dev builds never move `:latest`.
`kubectl apply -f deploy/gke/studio.yaml` resets the image to `:latest` (the last
`main` build) — fine for prod, but don't apply `studio.yaml` while a rollback to an
older build is meant to stick.

Build steps: read `VITE_*` secrets into `.env.production` → `docker build`
(`npm ci`, `npm run build`, prune) → push → `kubectl set image` → `rollout status`.
Logs: Cloud Build history in the console (builds run as their own service
accounts, so `gcloud builds submit` prints only a summary).

## Config (non-secret)

The ConfigMap `studio-config` in `studio.yaml` / `studio-dev.yaml`:

| Key | Prod | Dev | Notes |
|---|---|---|---|
| `DATABASE_URL` | proxy on 127.0.0.1, user `studio-app-db@…iam` | user `studio-dev-db@…iam` | no password — IAM login via the sidecar |
| `DISABLE_BACKGROUND_JOBS` | `false` | `true` | `true` = no schedulers at all |
| `PUBLIC_BASE_URL`, `AUTH0_BASE_URL` | `https://studio.fintechstudios.com` | `https://studio-dev.fintechstudios.com` | must match the host users hit |
| `ALLOWED_ORIGINS` | studio + studio-gcp | studio-dev | CORS allowlist add-ons |
| `TRUST_PROXY_HOPS` | `2` | `2` | Google LB appends its own IP; `1` = everyone shares one rate-limit key |
| `AUTH_PRIMARY_PROVIDER` / `AUTH_ENABLED_PROVIDERS` | `auth0` | `auth0` | Replit OIDC is disabled |

Change it in the repo (PR), then apply + restart. A ConfigMap change does not
restart the pod by itself.

## Secrets

- Secret Manager secrets named exactly like the env var, listed in
  `deploy/gke/secrets.txt`. Shared with the older `fts-web` deployment.
- `deploy/gke/sync-secrets.sh [dev]` grants read access and regenerates the
  `SecretProviderClass` `studio-secrets`; it reads names only. It refuses to run
  if a listed secret doesn't exist yet.
- The pod reads secrets **as the GSA it impersonates** (`studio-app-db@` /
  `studio-dev-db@`). A grant to the Kubernetes service account principal is not
  enough — symptom: pod stuck `Init:0/1`, events say `PermissionDenied … secretmanager.versions.access`.
- Mounted at `/var/run/secrets/studio/<NAME>`; `deploy/gke/entrypoint.sh` exports
  each one unless the ConfigMap already set it (ConfigMap wins).
- **`SESSION_SECRET`** signs sessions **and** (because `INTEGRATION_ENCRYPTION_KEY`
  is not set) encrypts the `system_credentials` table and users' OpenRouter keys.
  Rotating it logs everyone out and makes those unreadable — plan a re-encryption
  before touching it.
- Many service keys (Stripe webhook secret, SendGrid, Brave, NewsAPI, ElevenLabs,
  GitHub, TVEyes, OpenRouter system key) are read from the **database** first
  (System Admin → Studio Credentials), env second. Fix those in the admin panel —
  no restart needed (5-minute cache).

## Hosts, certificates, DNS

- DNS: Cloud DNS zone `fintechstudios-com` in project `elasticsearch-496414`.
  `studio` → 35.244.128.249 (`studio-ip`), `studio-gcp` → same, `studio-dev` →
  136.68.50.96 (`studio-dev-ip`).
- Google-managed certificates: `studio-cert` (studio-gcp), `studio-cert-prod`
  (studio), dev `studio-cert`. A new hostname needs its own ManagedCertificate and
  DNS pointing at the IP before it can go Active (10–60 min).
- The load balancer timeout is 3600 s (BackendConfig) so SSE streams survive.
- Auth0 callback path is `/api/auth/auth0/callback`; each host needs it allowed in
  the Auth0 Studio application.

## Capacity

One pod per environment (`replicas: 1` — in-process schedulers). Prod requests
500m CPU / 1 Gi, limit 3 Gi; Cloud SQL `studio-prod-db` 2 vCPU / 8 GB. Scale up by
raising `resources` in `studio.yaml` or the Cloud SQL tier — never replicas.

## The old world

- Replit's Studio deployment is paused, not deleted. Rolling back to it now would
  lose everything written since 2026-10-15.
- `fts-web` in namespace `fts-prod` (app.fintechstudios.com, AlloyDB) is an older,
  unrelated Studio build due for removal. Don't confuse it with `studio-prod`.

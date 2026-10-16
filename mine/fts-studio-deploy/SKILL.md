---
name: fts-studio-deploy
description: >-
  Ship and operate FinTech Studios Studio (the FTS-Web repo) on Google Cloud —
  production at studio.fintechstudios.com and dev at studio-dev.fintechstudios.com,
  both on GKE cluster fts-prod-gcp with Cloud SQL. Use when the user wants to
  deploy, publish or release Studio, push or test a branch on dev, check whether a
  deploy finished, look at Studio logs or pod status, roll back a bad release,
  restart Studio, change a Studio environment variable or ConfigMap, add or rotate
  a Studio secret, or when Studio is down, slow, returning 5xx/429, or logins
  fail. Also use for questions like "how do I publish to production now that we
  are off Replit".
metadata:
  version: 1.0.0
---

# Ship and operate Studio on GCP

Studio left Replit on 2026-10-15. There is no Publish button: **merging to `main`
deploys production**, and the `dev` branch deploys dev. Most work is therefore
"get the right code onto the right branch, then watch it land".

| | Production | Dev |
|---|---|---|
| URL | https://studio.fintechstudios.com | https://studio-dev.fintechstudios.com |
| Namespace | `studio-prod` | `studio-dev` |
| Database | Cloud SQL `studio-prod-db`, db `studio` | Cloud SQL `studio-dev-db`, db `studio` |
| Deploys | every push to `main` | every push to `dev`; any branch via Run workflow |
| Background jobs | on | off (`DISABLE_BACKGROUND_JOBS=true`) |

Project `elasticsearch-496414`, cluster `fts-prod-gcp` (zone `us-central1-b`),
GitHub repo `Fintech-Studios-Apps/FTS-Web`. Infra reference:
`deploy/gke/README.md` in that repo.

## Ground rules

- **Look before you touch.** Run `scripts/studio-status.sh [prod|dev]` (read-only)
  before any change and after it.
- **Confirm before anything that changes production**: merging to `main`,
  `rollout undo/restart`, `kubectl apply`, `set image`, scaling, secret changes.
  Say what will happen and wait for a yes. Dev changes need no confirmation
  unless the user asked to be asked.
- **Never print, paste or ask for secret values.** Read names only. The user
  enters values in the Secret Manager console.
- **Never scale above 1 replica.** Schedulers run in-process; two pods send every
  brief and newsletter twice. Need more capacity? Raise `resources` instead.

## Setup (once per machine)

```bash
gcloud auth login && gcloud config set project elasticsearch-496414
gcloud components install kubectl gke-gcloud-auth-plugin
gcloud container clusters get-credentials fts-prod-gcp --location us-central1-b
```

## Deploy

**Production** — merge the PR into `main`. GitHub Actions "Deploy Studio to GKE"
→ Cloud Build (`deploy/gke/cloudbuild.yaml`) builds, pushes
`fts-app/studio:<build-id>` + `:latest`, sets the image, waits for the rollout
(~8–10 min). Before merging, check: schema changes for this code are already
applied to prod (use the `fts-studio-db-change` skill); it was tried on dev.

**Dev** — push/merge to `dev`, or try any branch without merging:

```bash
gh workflow run deploy-gke-dev.yml --repo Fintech-Studios-Apps/FTS-Web --ref <branch>
```

**Watch it land**:

```bash
gh run list --repo Fintech-Studios-Apps/FTS-Web --workflow deploy-gke.yml --limit 3   # deploy-gke-dev.yml for dev
gh run watch <run-id> --repo Fintech-Studios-Apps/FTS-Web
scripts/studio-status.sh prod     # image tag should be the new build id; pod 2/2 Running
```

A deploy is done when the run is green, the pod shows the new build id and is
2/2 Ready, `/api/health` returns 200, and the startup log has
`all routes registered, app fully ready`.

## Roll back

Fastest — previous image, no rebuild (confirm first):

```bash
kubectl -n studio-prod rollout undo deployment/studio
kubectl -n studio-prod rollout status deployment/studio
```

Then fix forward or `git revert` on `main` via a PR — the next merge deploys over
the rollback. Database changes are not rolled back by this; see
`fts-studio-db-change`.

## Config and secrets

The pipeline only changes the image. Everything else is in the repo's
`deploy/gke/`:

- **Non-secret setting** → edit the ConfigMap in `studio.yaml` (or
  `studio-dev.yaml`), PR it, then `kubectl apply -f deploy/gke/studio.yaml` and
  `kubectl -n studio-prod rollout restart deployment/studio`.
- **New secret** → user creates it in Secret Manager under the env var's exact
  name; add the name to `deploy/gke/secrets.txt`; run
  `deploy/gke/sync-secrets.sh` and `deploy/gke/sync-secrets.sh dev`; restart.
- **Rotated secret value** → user adds a new version in Secret Manager; restart.
- **`VITE_*`** values are baked into the client at build time → redeploy instead
  of restarting.

Details and pitfalls: `references/operations.md`.

## When something is wrong

Run `scripts/studio-status.sh prod` first, then match the symptom in
`references/troubleshooting.md` (site down, 5xx, 429 for everyone, login loop,
pod not starting, secrets not mounting, deploy run failing).

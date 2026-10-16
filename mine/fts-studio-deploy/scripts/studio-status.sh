#!/usr/bin/env bash
# Read-only health snapshot of Studio on GKE. Changes nothing.
#   studio-status.sh [prod|dev]
set -uo pipefail

ENV="${1:-prod}"
case "$ENV" in
  prod) NS=studio-prod; HOST=studio.fintechstudios.com; DB=studio-prod-db ;;
  dev)  NS=studio-dev;  HOST=studio-dev.fintechstudios.com; DB=studio-dev-db ;;
  *) echo "usage: $0 [prod|dev]"; exit 2 ;;
esac
CTX=gke_elasticsearch-496414_us-central1-b_fts-prod-gcp
# Always pass --context: other sessions may switch the shared current-context.
K="kubectl --context $CTX -n $NS --request-timeout=30s"

say() { printf '\n== %s\n' "$*"; }

if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx "$CTX"; then
  echo "No kubectl context for fts-prod-gcp. Run once:"
  echo "  gcloud container clusters get-credentials fts-prod-gcp --location us-central1-b"
  exit 1
fi

say "Pods ($NS) — expect exactly one, 2/2 Running"
$K get pods -o wide

say "Running image"
$K get deploy studio -o jsonpath='{.spec.template.spec.containers[?(@.name=="studio")].image}{"\n"}'
$K get pods -l app=studio -o jsonpath='{range .items[*]}started {.status.startTime}{"\n"}{end}'

say "Public health"
curl -s -m 10 -o /dev/null -w "https://$HOST/api/health -> %{http_code} in %{time_total}s\n" "https://$HOST/api/health"

say "Settings (ConfigMap, non-secret)"
$K get configmap studio-config -o go-template='{{range $k,$v := .data}}{{if ne $k "DATABASE_URL"}}{{$k}}={{$v}}{{"\n"}}{{end}}{{end}}'

say "Certificates"
$K get managedcertificate -o custom-columns='NAME:.metadata.name,STATUS:.status.certificateStatus,DOMAINS:.spec.domains'

say "Startup + errors (last 30 min, deduplicated; see references/troubleshooting.md for which are normal)"
$K logs deploy/studio -c studio --since=30m 2>/dev/null \
  | grep -E 'fully ready|schedulers not started|Fatal|"level":(50|60)' \
  | sed -E 's/.*"time":([0-9]+).*"msg":"([^"]*)".*/\1 \2/' | sort | uniq -c -f1 | tail -15

say "Cloud SQL proxy"
$K logs deploy/studio -c cloud-sql-proxy --tail=3 2>/dev/null | sed -E 's/.*"message":"([^"]*)".*/\1/'

say "Database instance"
gcloud sql instances describe "$DB" --format='value(state,settings.tier)' 2>/dev/null

say "Recent deploys"
WF=deploy-gke.yml; [ "$ENV" = dev ] && WF=deploy-gke-dev.yml
gh run list --repo Fintech-Studios-Apps/FTS-Web --workflow "$WF" --limit 3 2>/dev/null \
  || echo "(gh not available — see GitHub → Actions)"

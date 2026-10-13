#!/usr/bin/env bash
set -euo pipefail
image=${1:?Usage: scripts/scan.sh IMAGE [REPORT.json]}
report=${2:-results/trivy.json}
mkdir -p "$(dirname "$report")"
trivy image --scanners vuln --format json --output "$report" "$image"
python3 scripts/summarize-scans.py "$report"
trivy image --scanners vuln --severity CRITICAL,HIGH --exit-code 1 "$image"

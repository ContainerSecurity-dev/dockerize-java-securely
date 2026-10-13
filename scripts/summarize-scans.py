#!/usr/bin/env python3
"""Summarize Trivy records, not unique global CVEs, by target and severity."""
import collections
import json
import sys

if len(sys.argv) < 2:
    raise SystemExit("Usage: scripts/summarize-scans.py REPORT.json [REPORT.json ...]")
for filename in sys.argv[1:]:
    with open(filename, encoding="utf-8") as stream:
        report = json.load(stream)
    print(f"\n{filename}: {report['ArtifactName']} ({report['CreatedAt']})")
    for target in report.get("Results", []):
        counts = collections.Counter(item["Severity"] for item in target.get("Vulnerabilities", []))
        print(target["Target"], " | ".join(f"{severity}: {counts[severity]}" for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]))

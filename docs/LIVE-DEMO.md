# Live demo runbook

Run commands from the repository root. Rehearse on the same machine and network before the session. Warm the Maven/image caches and Trivy databases; keep the results report as a fallback. These commands target `linux/amd64`, matching the recorded run. On another platform, repeat the measurements.

## 1. Preflight

```bash
docker info
docker buildx version
docker scout version
trivy --version
cosign version
./mvnw -B verify
./mvnw -B dependency:tree
```

Use a JDK 21, not only a Java runtime. Without a local JDK, run the wrapper in the builder image:

```bash
docker run --rm -v "$PWD:/app" -w /app \
  maven:3.9-eclipse-temurin-21 ./mvnw -B verify dependency:tree
```

Authenticate to Docker Hub for Scout CVE queries and to DHI for hardened builds. Do this before going on stage. Do not show credentials in your terminal history or slides.

```bash
docker login
docker login dhi.io
```

## 2. Start a local demo registry

Use a dedicated loopback-only registry. The data is temporary and disappears when you remove the container. Do not use this unauthenticated HTTP registry for production.

```bash
docker run -d --name dockerize-java-demo-registry \
  -p 127.0.0.1:15000:5000 registry:3
export IMAGE_REPO=127.0.0.1:15000/dockerize-java-securely
mkdir -p results
```

The explicit IPv4 address avoids the localhost/IPv6 failure encountered in rehearsal. You may instead use an authenticated registry namespace you own; retain its HTTPS security defaults.

## 3. Build the baseline with attestations

```bash
docker buildx build --platform linux/amd64 \
  -f Dockerfile.baseline \
  --sbom=true --provenance=mode=max \
  --metadata-file results/baseline-build-metadata.json \
  --push -t "$IMAGE_REPO:baseline" .

scripts/smoke-test.sh "$IMAGE_REPO:baseline"
export IMAGE="$IMAGE_REPO:baseline"
```

The smoke test expects `Hello, Docker Security!` and prints runtime user `10001:10001`.

## 4. Inspect the image

```bash
docker scout sbom "$IMAGE" --format list
docker scout sbom "$IMAGE" --format spdx --output results/sbom.spdx.json
docker scout cves "$IMAGE"
docker scout cves --only-severity critical,high "$IMAGE"

trivy image --scanners vuln "$IMAGE"
# This is expected to exit 1 when findings remain:
scripts/scan.sh "$IMAGE" results/baseline-trivy.json
```

Scout package/SBOM operations and authenticated CVE queries succeeded in the recorded run.

## 5. Harden and compare

```bash
docker buildx build --platform linux/amd64 \
  --sbom=true --provenance=mode=max \
  --metadata-file results/hardened-build-metadata.json \
  --push -t "$IMAGE_REPO:hardened" .
scripts/smoke-test.sh "$IMAGE_REPO:hardened"
# May exit 1; don't conceal the gate failure:
scripts/scan.sh "$IMAGE_REPO:hardened" results/hardened-trivy.json
python3 scripts/summarize-scans.py results/baseline-trivy.json results/hardened-trivy.json
```

Compare the final app images built from the **same** source and dependencies, not a Maven builder against a Java runtime. Separate OS findings from Java-library findings. If DHI authentication fails, explain that limitation rather than presenting a fictional scan.

## 6. Inspect attached attestations

```bash
docker buildx imagetools inspect "$IMAGE" --format '{{json .SBOM}}' > results/attached-sbom.json
docker buildx imagetools inspect "$IMAGE" --format '{{json .Provenance}}' > results/provenance.json
```

`ARG BUILDKIT_SBOM_SCAN_STAGE=true` adds the build-stage SBOM. The recorded output contains the runtime SPDX document plus `sbom-build`. `mode=max` exposes build details; use secret mounts, never credential build arguments.

## 7. Sign and verify the immutable digest

Use the baseline metadata for the baseline image, or change both the tag and metadata file when signing the hardened image.

```bash
export DIGEST_IMAGE="$IMAGE_REPO@$(python3 -c 'import json; print(json.load(open("results/baseline-build-metadata.json"))["containerimage.digest"])')"
mkdir -p .demo-keys
cosign generate-key-pair --output-key-prefix .demo-keys/cosign
cosign sign --key .demo-keys/cosign.key "$DIGEST_IMAGE"
cosign verify --key .demo-keys/cosign.pub "$DIGEST_IMAGE"
# Scan the same immutable artifact:
trivy image --scanners vuln --severity CRITICAL,HIGH --exit-code 1 "$DIGEST_IMAGE"
```

Use a new demo-only key and enter its password interactively. The test used a disposable key. Default Cosign signing publishes a transparency-log entry containing the public key and artifact signature metadata. Verification must use a trusted public key, not one supplied by an untrusted image publisher.

Cosign 3.1.3's `--tlog-upload=false` no longer works with the default signing configuration. The successful test used normal signing and verification, including transparency-log verification; no verification bypass flags were used.

A valid signature proves integrity under your trust policy, not an absence of vulnerabilities.

## 8. Cleanup

```bash
docker compose down
docker rm -f dockerize-java-demo-registry
```

This removes only the named demo registry, including its temporary images/signatures. Preserve scan reports before cleaning up. Never use a broad `docker system prune` during a live session.

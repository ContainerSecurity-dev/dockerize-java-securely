# Recorded results — 13 October 2026

Platform: `linux/amd64`. Default application: Spring Boot 4.0.8, Java 21.

Tools: Docker Engine 29.4.0, Buildx 0.33.0-desktop.1, Scout 1.20.3, Trivy 0.75.0, Cosign 3.1.3. Maven Wrapper 3.3.4 downloads Maven 3.9.9 for the audience quickstart; Docker builds use Maven from their respective builder images.

## What passed

- Both Dockerfiles built and ran the real HTTP integration test with `mvn verify`.
- Maven Wrapper `verify dependency:tree` passed in a Java 21 builder container.
- Baseline and hardened smoke tests returned `Hello, Docker Security!`, running as `10001:10001` with a read-only root, temporary `/tmp`, dropped capabilities, and no privilege escalation.
- The hardened Compose quickstart served the same response; its demo service was then removed.
- Scout package listing and SPDX export succeeded. CVE queries succeeded after Docker login.
- Buildx pushed both images to a loopback-only registry with SBOM and maximum provenance.
- Both attached SBOMs contained runtime SPDX plus an additional `sbom-build` inventory. Both images exposed SLSA provenance.
- Cosign signed and verified the hardened image by digest, including claims and transparency-log checks. No verification bypass flags were used.
- The critical/high Trivy gate returned **1** for both images and for the signed hardened digest. This is the intended policy failure: signing and hardening do not remove all application vulnerabilities.

## Immutable image identities

The registry was local to the test machine, so these are evidence identifiers, not public pull URLs. Rebuilding may produce different digests because tags and build metadata change.

- baseline: `127.0.0.1:15000/dockerize-java-securely@sha256:7ae2c98d4d32457e70f9633cb3b1814290b4053944d002366b075a8cdd3c5f99`
- hardened: `127.0.0.1:15000/dockerize-java-securely@sha256:dad8709f758213bca68fcd3336c13fb1471f744e9d90900d797348f9206a4e93`

## Trivy findings

Counts below are vulnerability records by target, not globally unique CVE IDs. The full extracted findings, versions, fixed-version hints, source-report hashes, and SBOM counts are in [results/2026-10-13.json](results/2026-10-13.json).

| Image and target | Critical | High | Medium | Low | Unknown |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original Boot 4.0.5: Java dependencies | 9 | 18 | 20 | 6 | 0 |
| Updated baseline: Ubuntu packages | 0 | 0 | 40 | 4 | 0 |
| Updated baseline: Java dependencies | 3 | 5 | 2 | 0 | 0 |
| Updated baseline: `pebble` binary | 0 | 3 | 5 | 1 | 4 |
| Hardened: Alpine packages | 0 | 0 | 0 | 0 | 0 |
| Hardened: Java dependencies | 3 | 5 | 2 | 0 | 0 |

The remaining Java findings are in Tomcat 11.0.24 and Jackson 3.1.5. Updating the Spring Boot BOM helped, but application dependency remediation remains necessary. The scanner's fixed-version hints are evidence, not a substitute for compatibility testing.

## Scout findings

Scout reported baseline totals of **5 critical, 13 high, 2 medium, 3 unspecified** and hardened totals of **3 critical, 5 high, 2 medium**. See the saved [baseline report](results/baseline-scout-all.txt) and [hardened report](results/hardened-scout.txt). Differences from Trivy demonstrate why cross-scanner totals must not be treated as equivalent.

## SBOM inventories

| Image | Runtime SPDX packages | Additional build-stage packages |
| --- | ---: | ---: |
| Baseline | 192 | 396 |
| Hardened | 47 | 377 |

Build-stage inventories include tools that are not copied into the runtime image. Scout's combined attached-SBOM inventory and BuildKit's per-stage package counts have different scopes.

## Rehearsal pitfalls

- The host's Java runtime was not a usable JDK compiler. The documented JDK container made wrapper verification reproducible.
- Docker Desktop did not share `/tmp`; the mounted-wrapper test passed from a shared development directory.
- Docker Hub login was required for Scout CVE queries, and DHI login for hardened pulls.
- A `localhost` registry push encountered IPv6 connection failures; the tested commands use `127.0.0.1` explicitly.
- HTTP probing immediately after Compose startup encountered an empty reply. Wait for the application's startup message or use the polling smoke-test script.
- Cosign 3.1.3 rejected `--tlog-upload=false` with the default signing configuration. The successful test used standard signing and verified the transparency log.

Both base-image tags and vulnerability databases are mutable. Repeat the run on the same platform and capture new digests and dates before making deployment decisions. Private keys and full working logs are excluded from Git. The public verification evidence contains only sample-image signature metadata.

# Dockerize Java Securely

A small Spring Boot application for a live container-security demo and an audience reference. The endpoint returns `Hello, Docker Security!`.

Adapted from [Dockerizing a Java 26 Project with Docker Init](https://containersecurity.dev/blog/dockerize-java-26-with-docker-init). This sample uses Java 21 to match the hardened-image examples, a valid Java package name, Spring Boot 4.0.8, and a fixed `target/app.jar` output. It uses a simple executable JAR rather than copying the older layer-extraction recipe.

## Start here

- [Presenter runbook](docs/LIVE-DEMO.md): ordered commands and rehearsal advice.
- [Observed results](docs/RESULTS.md): dated measurements, digests, and limitations.
- [Article](https://containersecurity.dev/blog/how-to-secure-java-docker-images): explanations and the Commandos story.

Requirements: Docker Engine/Desktop with Buildx, Bash, curl, Python 3, Docker Scout, Trivy, and Cosign. A local JDK 21 is needed for `./mvnw`; the Docker builds include their own JDK. The tested scanner versions are in the results report.

```bash
git clone https://github.com/ContainerSecurity-dev/dockerize-java-securely.git
cd dockerize-java-securely
./mvnw -B verify
./mvnw -B dependency:tree
```

The test starts the real HTTP server on a random port and checks its status and response body. Both Dockerfiles also run the tests during `mvn verify`.

## Run the application

The default Dockerfile uses Docker Hardened Images and requires `docker login dhi.io`.

```bash
docker login dhi.io
docker compose up --build
# In another terminal:
# Wait for the Spring Boot startup message first.
# Wait for the Spring Boot startup message first.
curl --fail http://localhost:8080/
docker compose down
```

Without DHI access, use the baseline:

```bash
DEMO_DOCKERFILE=Dockerfile.baseline docker compose up --build
```

Both runtime images use UID/GID 10001. Compose binds only to loopback, drops capabilities, uses a read-only root filesystem, and provides writable `/tmp`.

## Compare images, attest, scan, and sign

See [the runbook](docs/LIVE-DEMO.md). Do not assume a hardened base makes application dependencies safe. The measured baseline still fails the critical/high vulnerability gate after updating Spring Boot.

| File | Purpose |
| --- | --- |
| `Dockerfile.baseline` | Official Maven builder and Eclipse Temurin runtime |
| `Dockerfile` | DHI Maven builder and DHI Temurin runtime |
| `pom.xml` | Updated default application dependencies |
| `docs/original-pom.xml` | Original 4.0.5 dependency baseline, deliberately retained for reproduction, not deployment |
| `scripts/smoke-test.sh` | Test an image over HTTP under runtime restrictions; removes only its own container |
| `scripts/scan.sh` | Save Trivy JSON and report a critical/high gate failure |
| `scripts/summarize-scans.py` | Count findings by target and severity from saved Trivy JSON |

Build context is allowlisted in `.dockerignore`: only the POM and sources are copied. Private keys, results, Git history, and local environment files are excluded. Keys and generated results are also ignored by Git.

To reproduce the original dependency scan, copy `docs/original-pom.xml` over `pom.xml` in a **separate disposable checkout**, then build the baseline. Do not deploy that older example.

Tags and vulnerability databases move. Record image digests, tool versions, platform, and scan dates for every rehearsal. The repo does not promise zero CVEs or silently suppress findings.

## License

Sample code: MIT. Apache Maven Wrapper scripts retain their Apache-2.0 license; see `.mvn/wrapper/LICENSE`.

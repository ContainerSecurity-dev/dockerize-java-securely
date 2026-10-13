# syntax=docker/dockerfile:1
FROM dhi.io/maven:3-jdk21-dev AS build
ARG BUILDKIT_SBOM_SCAN_STAGE=true
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -B verify

FROM dhi.io/eclipse-temurin:21-alpine3.23
WORKDIR /app
COPY --from=build /app/target/app.jar /app/app.jar
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

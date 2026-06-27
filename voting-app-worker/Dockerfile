# because of dotnet, we always build on amd64, and target platforms in cli
# dotnet doesn't support QEMU for building or running.
# (errors common in arm/v7 32bit) https://github.com/dotnet/dotnet-docker/issues/1537
# https://hub.docker.com/_/microsoft-dotnet
# hadolint ignore=DL3029
# to build for a different platform than your host, use --platform=<platform>
# for example, if you were on Intel (amd64) and wanted to build for ARM, you would use:
# docker buildx build --platform "linux/arm64/v8" .
#
# ═══════════════════════════════════════════════════════════════
#  CVE fix: base images pinned by digest for deterministic builds.
#  apt-get upgrade removed — CVE coverage via base image updates.
# ═══════════════════════════════════════════════════════════════

# build compiles the program for the builder's local platform
FROM --platform=${BUILDPLATFORM} mcr.microsoft.com/dotnet/sdk:8.0@sha256:63ebabdcde24cc8134304a6f50719cf1e22bb4e9f7148ac4ef967c7680187356 AS build
ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

WORKDIR /source
COPY *.csproj .
RUN dotnet restore -a $TARGETARCH

COPY . .
RUN dotnet publish -c release -o /app -a $TARGETARCH --self-contained false --no-restore

# app image — pinned digest
FROM mcr.microsoft.com/dotnet/runtime:8.0@sha256:4cbc2530d5855154199432020f232205aecd8be34be87bea866f3b235f853bcb

WORKDIR /app
COPY --from=build /app .

# Run as non-root user for security
RUN useradd -u 1001 -r -s /bin/false appuser
USER appuser

ENTRYPOINT ["dotnet", "Worker.dll"]

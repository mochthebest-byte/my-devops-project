# syntax=docker/dockerfile:1
FROM alpine:3.21
ARG TARGETARCH

# Встановлюємо curl, kubectl, bash, grep
RUN apk add --no-cache \
    curl \
    bash \
    grep

# Встановлюємо kubectl для правильної архітектури
ARG KUBECTL_VERSION=1.30.3
RUN ARCH="${TARGETARCH:-amd64}" && \
    [ "$ARCH" = "arm64" ] && ARCH="arm64" || ARCH="amd64" && \
    curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

ADD tests.sh /app/tests.sh
RUN chmod +x /app/tests.sh

WORKDIR /app
CMD ["/app/tests.sh"]

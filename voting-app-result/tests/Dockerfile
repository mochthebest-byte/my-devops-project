FROM alpine:3.20

# Встановлюємо curl, kubectl, bash, grep
RUN apk add --no-cache \
    curl \
    bash \
    grep

# Встановлюємо kubectl (остання стабільна версія)
ARG KUBECTL_VERSION=1.30.3
RUN curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

ADD tests.sh /app/tests.sh
RUN chmod +x /app/tests.sh

WORKDIR /app
CMD ["/app/tests.sh"]

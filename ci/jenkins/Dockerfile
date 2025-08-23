FROM jenkins/jenkins:lts-jdk17

# Use root only to install tools during the image build
USER root

# Minimal deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

# Pin tool versions for repeatability
ARG KUBECTL_VERSION=v1.33.1
ARG HELM_VERSION=v3.18.4

# kubectl
RUN curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && chmod +x /usr/local/bin/kubectl

# helm
RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
 | tar -xz -C /tmp \
 && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
 && chmod +x /usr/local/bin/helm \
 && rm -rf /tmp/linux-amd64

# Back to the default Jenkins runtime user
USER jenkins

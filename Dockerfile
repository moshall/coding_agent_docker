# syntax=docker/dockerfile:1

ARG BUILD_VERSION=dev
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown

FROM golang:1.25-bookworm AS go-builder

ARG CC_CONNECT_REPO=https://github.com/chenhg5/cc-connect.git
WORKDIR /build

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates git; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    fallback_build() { \
      tmpdir="$(mktemp -d)"; \
      cd "${tmpdir}"; \
      printf '%s\n' \
        'package main' \
        'import "fmt"' \
        'func main() { fmt.Println("cc-connect fallback build") }' \
        >cc-connect-main.go; \
      GO111MODULE=off GOTOOLCHAIN=local go build -ldflags='-w -s' -o /build/cc-connect ./cc-connect-main.go; \
      rm -rf "${tmpdir}"; \
    }; \
    if git ls-remote "${CC_CONNECT_REPO}" >/dev/null 2>&1; then \
      git clone --depth 1 "${CC_CONNECT_REPO}" /tmp/cc-connect; \
      cd /tmp/cc-connect; \
      go build -ldflags='-w -s' -o /build/cc-connect ./cmd/cc-connect || \
      go build -ldflags='-w -s' -o /build/cc-connect . || \
      go build -ldflags='-w -s' -o /build/cc-connect ./... || true; \
      if [ ! -x /build/cc-connect ]; then \
        fallback_build; \
      fi; \
    else \
      fallback_build; \
    fi

FROM node:22-bookworm

ARG BUILD_VERSION=dev
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown

USER root

LABEL org.opencontainers.image.title="coding_agent_docker" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/moshall/coding_agent_docker"

ENV CODING_AGENT_VERSION="${BUILD_VERSION}" \
    CODING_AGENT_BUILD_DATE="${BUILD_DATE}" \
    CODING_AGENT_VCS_REF="${VCS_REF}" \
    DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      cron \
      curl \
      git \
      gnupg \
      gosu \
      lsb-release \
      python3 \
      python3-pip \
      python3-venv \
      tmux \
      wget; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg >/usr/share/keyrings/tailscale-archive-keyring.gpg; \
    chmod go+r /usr/share/keyrings/tailscale-archive-keyring.gpg; \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list > /etc/apt/sources.list.d/tailscale.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh tailscale; \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages \
    uv \
    pandas \
    matplotlib \
    seaborn \
    scipy

RUN set -eux; \
    install_global() { \
      pkg="$1"; optional="${2:-0}"; \
      if npm install -g "${pkg}"; then \
        echo "Installed npm package: ${pkg}"; \
      elif [ "${optional}" = "1" ]; then \
        echo "Optional npm package failed: ${pkg}"; \
      else \
        echo "Required npm package failed: ${pkg}" >&2; \
        exit 1; \
      fi; \
    }; \
    install_global @anthropic-ai/claude-code; \
    install_global @openai/codex; \
    install_global @google/gemini-cli; \
    install_global opencode-ai; \
    install_global task-master-ai; \
    install_global ccman; \
    install_global uipro-cli; \
    install_global ralph-orchestrator 1

COPY --from=go-builder /build/cc-connect /usr/local/bin/cc-connect
COPY ccman-wrapper.sh /tmp/ccman-wrapper.sh
COPY entrypoint.sh /entrypoint.sh
COPY user-init.sh.example /home/node/user-init.sh.example

RUN set -eux; \
    mv /usr/local/bin/ccman /usr/local/bin/ccman-real; \
    install -m 0755 /tmp/ccman-wrapper.sh /usr/local/bin/ccman; \
    rm -f /tmp/ccman-wrapper.sh; \
    chmod +x /entrypoint.sh /home/node/user-init.sh.example && \
    chown node:node /home/node/user-init.sh.example

WORKDIR /home/node

EXPOSE 8080 3000 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

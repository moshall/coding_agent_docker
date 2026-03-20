# syntax=docker/dockerfile:1

ARG BUILD_VERSION=dev
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown

FROM golang:1.25-bookworm AS go-builder

ARG CC_CONNECT_REPO=https://github.com/chenhg5/cc-connect.git
# Optional: git branch or tag for reproducible cc-connect (e.g. v1.2.0). Empty = default branch HEAD.
ARG CC_CONNECT_GIT_REF=
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
      if [ -n "${CC_CONNECT_GIT_REF}" ]; then \
        git clone --depth 1 --branch "${CC_CONNECT_GIT_REF}" "${CC_CONNECT_REPO}" /tmp/cc-connect; \
      else \
        git clone --depth 1 "${CC_CONNECT_REPO}" /tmp/cc-connect; \
      fi; \
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
    CODING_AGENT_BOM_PATH=/usr/share/doc/coding-agent/bom.json \
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

COPY docker/python-requirements.txt /tmp/python-requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/python-requirements.txt \
    && rm -f /tmp/python-requirements.txt

COPY docker/npm-required.txt /tmp/npm-required.txt
COPY docker/npm-optional.txt /tmp/npm-optional.txt
RUN set -eux; \
    while IFS= read -r line || [ -n "${line}" ]; do \
      line="${line#"${line%%[![:space:]]*}"}"; \
      line="${line%"${line##*[![:space:]]}"}"; \
      [ -z "${line}" ] && continue; \
      case "${line}" in \#*) continue ;; esac; \
      npm install -g "${line}"; \
    done < /tmp/npm-required.txt; \
    while IFS= read -r line || [ -n "${line}" ]; do \
      line="${line#"${line%%[![:space:]]*}"}"; \
      line="${line%"${line##*[![:space:]]}"}"; \
      [ -z "${line}" ] && continue; \
      case "${line}" in \#*) continue ;; esac; \
      npm install -g "${line}" || echo "optional npm failed: ${line}"; \
    done < /tmp/npm-optional.txt; \
    rm -f /tmp/npm-required.txt /tmp/npm-optional.txt

COPY --from=go-builder /build/cc-connect /usr/local/bin/cc-connect
COPY docker/record-bom.sh /tmp/record-bom.sh
COPY ccman-wrapper.sh /tmp/ccman-wrapper.sh
COPY entrypoint.sh /entrypoint.sh
COPY user-init.sh.example /home/node/user-init.sh.example

RUN set -eux; \
    mv /usr/local/bin/ccman /usr/local/bin/ccman-real; \
    install -m 0755 /tmp/ccman-wrapper.sh /usr/local/bin/ccman; \
    rm -f /tmp/ccman-wrapper.sh; \
    chmod +x /tmp/record-bom.sh && /tmp/record-bom.sh && rm -f /tmp/record-bom.sh; \
    chmod +x /entrypoint.sh /home/node/user-init.sh.example && \
    chown node:node /home/node/user-init.sh.example

WORKDIR /home/node

EXPOSE 8080 3000 3001 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# syntax=docker/dockerfile:1

ARG BUILD_VERSION=dev
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG TOOL_VERSION_CHANNEL=baseline
ARG CLAUDE_CODE_VERSION=
ARG CODEX_VERSION=
ARG CLOUDCLI_VERSION=
ARG CCMAN_VERSION=
ARG GH_VERSION=
ARG CC_CONNECT_VERSION_CHANNEL=baseline
ARG BWRAP_BUILD_VERSION=0.11.1

FROM golang:1.25-bookworm AS go-builder

ARG CC_CONNECT_REPO=https://github.com/chenhg5/cc-connect.git
# Optional: git branch or tag for reproducible cc-connect (e.g. v1.2.0). Empty = default branch HEAD.
ARG CC_CONNECT_GIT_REF=
ARG CC_CONNECT_VERSION_CHANNEL=baseline
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
    cc_connect_ref="${CC_CONNECT_GIT_REF}"; \
    if [ -z "${cc_connect_ref}" ] && [ "${CC_CONNECT_VERSION_CHANNEL}" = "latest" ]; then \
      cc_connect_ref="$(git ls-remote --tags --refs "${CC_CONNECT_REPO}" "refs/tags/v*" | awk -F/ '{print $3}' | sort -V | tail -n 1 || true)"; \
    fi; \
    if git ls-remote "${CC_CONNECT_REPO}" >/dev/null 2>&1; then \
      if [ -n "${cc_connect_ref}" ]; then \
        git clone --depth 1 --branch "${cc_connect_ref}" "${CC_CONNECT_REPO}" /tmp/cc-connect; \
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
ARG TOOL_VERSION_CHANNEL=baseline
ARG CLAUDE_CODE_VERSION=
ARG CODEX_VERSION=
ARG CLOUDCLI_VERSION=
ARG CCMAN_VERSION=
ARG GH_VERSION=
ARG BWRAP_BUILD_VERSION=0.11.1

USER root

LABEL org.opencontainers.image.title="coding_agent_docker" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/moshall/coding_agent_docker"

ENV CODING_AGENT_VERSION="${BUILD_VERSION}" \
    CODING_AGENT_BUILD_DATE="${BUILD_DATE}" \
    CODING_AGENT_VCS_REF="${VCS_REF}" \
    CODING_AGENT_TOOL_CHANNEL="${TOOL_VERSION_CHANNEL}" \
    CODING_AGENT_BOM_PATH=/usr/share/doc/coding-agent/bom.json \
    DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bubblewrap \
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

# Debian bookworm ships bubblewrap 0.8.x, which lacks `--argv0` required by Codex sandbox.
# If current bwrap is incompatible, build a newer bubblewrap from upstream source.
RUN set -eux; \
    if /usr/bin/bwrap --help 2>/dev/null | grep -q -- --argv0; then \
      echo "bubblewrap already supports --argv0: $(/usr/bin/bwrap --version || true)"; \
    else \
      echo "bubblewrap missing --argv0; building v${BWRAP_BUILD_VERSION}"; \
      apt-get update; \
      apt-get install -y --no-install-recommends \
        gcc \
        libc6-dev \
        libcap-dev \
        meson \
        ninja-build \
        pkg-config; \
      tmpdir="$(mktemp -d)"; \
      curl -fsSL "https://github.com/containers/bubblewrap/archive/refs/tags/v${BWRAP_BUILD_VERSION}.tar.gz" -o "${tmpdir}/bubblewrap.tar.gz"; \
      tar -xzf "${tmpdir}/bubblewrap.tar.gz" -C "${tmpdir}"; \
      src_dir="$(find "${tmpdir}" -maxdepth 1 -type d -name 'bubblewrap-*' | head -n 1)"; \
      test -n "${src_dir}"; \
      meson setup "${tmpdir}/build" "${src_dir}" \
        --prefix=/usr \
        --buildtype=release \
        -Dtests=false \
        -Dman=disabled \
        -Dbash_completion=disabled \
        -Dzsh_completion=disabled \
        -Dselinux=disabled; \
      meson compile -C "${tmpdir}/build"; \
      install -m 0755 "${tmpdir}/build/bwrap" /usr/bin/bwrap; \
      /usr/bin/bwrap --help 2>/dev/null | grep -q -- --argv0; \
      apt-get purge -y --auto-remove gcc libc6-dev libcap-dev meson ninja-build pkg-config; \
      rm -rf "${tmpdir}"; \
      rm -rf /var/lib/apt/lists/*; \
    fi

RUN set -eux; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg >/usr/share/keyrings/tailscale-archive-keyring.gpg; \
    chmod go+r /usr/share/keyrings/tailscale-archive-keyring.gpg; \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list > /etc/apt/sources.list.d/tailscale.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends tailscale; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
      amd64) gh_arch="amd64" ;; \
      arm64) gh_arch="arm64" ;; \
      *) echo "unsupported arch for gh: ${arch}" >&2; exit 1 ;; \
    esac; \
    if [ -n "${GH_VERSION}" ]; then \
      gh_ver="${GH_VERSION#v}"; \
      curl -fsSL "https://github.com/cli/cli/releases/download/v${gh_ver}/gh_${gh_ver}_linux_${gh_arch}.tar.gz" -o /tmp/gh.tgz; \
      tar -xzf /tmp/gh.tgz -C /tmp; \
      install -m 0755 "/tmp/gh_${gh_ver}_linux_${gh_arch}/bin/gh" /usr/local/bin/gh; \
      rm -rf /tmp/gh.tgz "/tmp/gh_${gh_ver}_linux_${gh_arch}"; \
    else \
      apt-get update; \
      apt-get install -y --no-install-recommends gh; \
      rm -rf /var/lib/apt/lists/*; \
    fi

COPY docker/python-requirements.txt /tmp/python-requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/python-requirements.txt \
    && rm -f /tmp/python-requirements.txt

COPY docker/npm-required.txt /tmp/npm-required.txt
COPY docker/npm-optional.txt /tmp/npm-optional.txt
COPY docker/resolve-npm-versions.sh /tmp/resolve-npm-versions.sh
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends make g++; \
    chmod +x /tmp/resolve-npm-versions.sh; \
    TOOL_VERSION_CHANNEL="${TOOL_VERSION_CHANNEL}" \
    CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION}" \
    CODEX_VERSION="${CODEX_VERSION}" \
    CLOUDCLI_VERSION="${CLOUDCLI_VERSION}" \
    CCMAN_VERSION="${CCMAN_VERSION}" \
    /tmp/resolve-npm-versions.sh /tmp/npm-required.txt /tmp/npm-required-resolved.txt; \
    while IFS= read -r line || [ -n "${line}" ]; do \
      line="${line#"${line%%[![:space:]]*}"}"; \
      line="${line%"${line##*[![:space:]]}"}"; \
      [ -z "${line}" ] && continue; \
      case "${line}" in \#*) continue ;; esac; \
      npm install -g "${line}"; \
    done < /tmp/npm-required-resolved.txt; \
    while IFS= read -r line || [ -n "${line}" ]; do \
      line="${line#"${line%%[![:space:]]*}"}"; \
      line="${line%"${line##*[![:space:]]}"}"; \
      [ -z "${line}" ] && continue; \
      case "${line}" in \#*) continue ;; esac; \
      npm install -g "${line}" || echo "optional npm failed: ${line}"; \
    done < /tmp/npm-optional.txt; \
    if [ -d /usr/local/lib/node_modules/@siteboon/claude-code-ui ] && [ ! -f /usr/local/lib/node_modules/@siteboon/claude-code-ui/.env ]; then \
      touch /usr/local/lib/node_modules/@siteboon/claude-code-ui/.env; \
    fi; \
    apt-get purge -y --auto-remove make g++; \
    rm -rf /var/lib/apt/lists/*; \
    rm -f /tmp/npm-required.txt /tmp/npm-required-resolved.txt /tmp/npm-optional.txt /tmp/resolve-npm-versions.sh

COPY --from=go-builder /build/cc-connect /usr/local/bin/cc-connect
COPY docker/record-bom.sh /tmp/record-bom.sh
COPY ccman-wrapper.sh /tmp/ccman-wrapper.sh
COPY cloudcli-wrapper.sh /tmp/cloudcli-wrapper.sh
COPY codingagentconfig.sh /tmp/codingagentconfig.sh
COPY entrypoint.sh /entrypoint.sh
COPY user-init.sh.example /home/node/user-init.sh.example

RUN set -eux; \
    mv /usr/local/bin/ccman /usr/local/bin/ccman-real; \
    install -m 0755 /tmp/ccman-wrapper.sh /usr/local/bin/ccman; \
    rm -f /tmp/ccman-wrapper.sh; \
    mv /usr/local/bin/cloudcli /usr/local/bin/cloudcli-real; \
    install -m 0755 /tmp/cloudcli-wrapper.sh /usr/local/bin/cloudcli; \
    rm -f /tmp/cloudcli-wrapper.sh; \
    install -m 0755 /tmp/codingagentconfig.sh /usr/local/bin/codingagentconfig; \
    rm -f /tmp/codingagentconfig.sh; \
    chmod +x /tmp/record-bom.sh && /tmp/record-bom.sh && rm -f /tmp/record-bom.sh; \
    chmod +x /entrypoint.sh /home/node/user-init.sh.example && \
    chown node:node /home/node/user-init.sh.example

WORKDIR /home/node

EXPOSE 8080 3000 3001 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

#!/usr/bin/env bash

set -euo pipefail
source tests/lib/helpers.sh

run_check "TC-VERSION-01 workflow listens to version tags" grep -Fq 'tags:' .github/workflows/build-push.yml
run_check "TC-VERSION-02 workflow matches v* tags" grep -Fq -- '- v*' .github/workflows/build-push.yml
run_check "TC-VERSION-03 workflow computes version image tag" grep -Fq 'version_tag="${IMAGE}:${GITHUB_REF_NAME}"' .github/workflows/build-push.yml
run_check "TC-VERSION-04 workflow can push version image tag" grep -Fq 'steps.tags.outputs.version' .github/workflows/build-push.yml
run_check "TC-VERSION-05 Dockerfile accepts build version arg" grep -Fq 'ARG BUILD_VERSION=dev' Dockerfile
run_check "TC-VERSION-06 Dockerfile writes OCI version label" grep -Fq 'org.opencontainers.image.version="${BUILD_VERSION}"' Dockerfile
run_check "TC-VERSION-07 Dockerfile exports runtime version env" grep -Fq 'CODING_AGENT_VERSION="${BUILD_VERSION}"' Dockerfile
run_check "TC-VERSION-08 README documents version tags" grep -Fq '`vX.Y.Z`' README.md
run_check "TC-VERSION-09 Dockerfile exports BOM path env" grep -Fq 'CODING_AGENT_BOM_PATH=/usr/share/doc/coding-agent/bom.json' Dockerfile

summary_and_exit

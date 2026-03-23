#!/usr/bin/env bash
set -euo pipefail
mkdir -p /usr/share/doc/coding-agent
export BOM_PATH=/usr/share/doc/coding-agent/bom.json
node <<'NODE'
const { execSync } = require('child_process');
const fs = require('fs');

function sh(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch {
    return null;
  }
}

const build = {
  coding_agent_version: process.env.CODING_AGENT_VERSION || '',
  coding_agent_build_date: process.env.CODING_AGENT_BUILD_DATE || '',
  coding_agent_vcs_ref: process.env.CODING_AGENT_VCS_REF || '',
};

let npmTree = null;
try {
  npmTree = JSON.parse(execSync('npm ls -g --depth=0 --json', { encoding: 'utf8' }));
} catch {
  npmTree = { error: 'npm ls failed' };
}

const bom = {
  build,
  node: sh('node --version'),
  npm: sh('npm --version'),
  npm_global_tree: npmTree,
  gh: sh('gh --version')?.split('\n')[0] || null,
  tailscale: sh('tailscale version')?.split('\n')[0] || null,
  cloudcli: sh('cloudcli version') || null,
  claude: sh('claude --version') || null,
  codex: sh('codex --version') || null,
  task_master: sh('task-master --version') || null,
  ccman: sh('ccman --version 2>&1') || null,
  cc_connect: sh('cc-connect --help 2>&1 | head -n 1') || null,
  bwrap: sh('bwrap --version') || null,
  python: sh('python3 --version'),
  python_libs: sh(
    'python3 -c "import pandas, matplotlib, seaborn, scipy; print(f\\"pandas={pandas.__version__} matplotlib={matplotlib.__version__} seaborn={seaborn.__version__} scipy={scipy.__version__}\\")"'
  ),
};

fs.writeFileSync(process.env.BOM_PATH, JSON.stringify(bom, null, 2) + '\n');
NODE
chmod 644 "${BOM_PATH}"

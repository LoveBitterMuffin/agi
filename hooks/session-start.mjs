#!/usr/bin/env node

/**
 * AGI - SessionStart Hook
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { syncWorkspace } from '../scripts/sync-workspace-core.mjs';
import { resetChainState } from './tool-chain-state.mjs';

function isProjectRoot(targetDir) {
  const indicators = ['.agents', 'package.json', '.git', 'AGENTS.md', 'pyproject.toml', 'Cargo.toml'];
  return indicators.some(ind => fs.existsSync(path.join(targetDir, ind)));
}

function resetToolChainCounter() {
  resetChainState();
}

function resolveWorkspace() {
  return process.env.ANTIGRAVITY_WORKSPACE || process.env.WORKSPACE_ROOT || process.cwd();
}

function main() {
  resetToolChainCounter();
  const workspace = resolveWorkspace();

  if (isProjectRoot(workspace)) {
    try {
      syncWorkspace(workspace);
    } catch (err) {
      console.error(`SessionStart sync warning: ${err.message}`);
    }
  }

  process.stdout.write(JSON.stringify({
    additionalContext: "AGI active: Carpati L0/L1/L2 memory, Dynamic Gate 1.X, 24 SDLC agents, 51 skills loaded."
  }));
  return 0;
}

process.exitCode = main();

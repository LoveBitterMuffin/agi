#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { syncWorkspace } from '../scripts/sync-workspace-core.mjs';
import { isMainModule, isProjectRoot, readStdinText, resolveWorkspaceRoot, tryParseJson } from './fs-atomic.mjs';
import { buildL0Brief, ensureCarpatiMemory } from './memory-bootstrap.mjs';
import { resetChainState } from './tool-chain-state.mjs';

const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function samePath(a, b) {
  const pa = path.resolve(a);
  const pb = path.resolve(b);
  return process.platform === 'win32' ? pa.toLowerCase() === pb.toLowerCase() : pa === pb;
}

function isSafeWorkspace(workspace, hasExplicitWorkspace) {
  if (!workspace || !fs.existsSync(workspace)) return false;
  if (samePath(workspace, PLUGIN_ROOT) && process.env.ANTIGRAVITY_ALLOW_PLUGIN_SYNC !== '1') return false;
  if (samePath(workspace, path.parse(workspace).root) || samePath(workspace, os.homedir())) return false;
  return hasExplicitWorkspace || isProjectRoot(workspace);
}

function readPluginStats() {
  const pkgPath = path.join(PLUGIN_ROOT, 'plugin.json');
  const pkg = fs.existsSync(pkgPath) ? tryParseJson(fs.readFileSync(pkgPath, 'utf8'), {}) : {};
  const agentsDir = path.join(PLUGIN_ROOT, 'agents');
  const skillsDir = path.join(PLUGIN_ROOT, 'skills');
  const agentCount = fs.existsSync(agentsDir) ? fs.readdirSync(agentsDir).filter((f) => f.endsWith('.md')).length : 0;
  let skillCount = 0;
  if (fs.existsSync(skillsDir)) {
    for (const d of fs.readdirSync(skillsDir, { withFileTypes: true })) {
      if (d.isDirectory() && fs.existsSync(path.join(skillsDir, d.name, 'SKILL.md'))) skillCount++;
    }
  }
  return { version: pkg?.version || '1.0.1', agentCount, skillCount };
}

async function main() {
  const raw = await readStdinText().catch((err) => { console.error(`SessionStart stdin warning: ${err.message}`); return ''; });
  const payload = raw.trim() ? tryParseJson(raw, {}) : {};
  const explicitWs = Boolean(payload?.workspaceRoot || payload?.workspace || payload?.cwd || process.env.ANTIGRAVITY_WORKSPACE || process.env.WORKSPACE_ROOT);
  const workspace = resolveWorkspaceRoot(payload);
  let memRes = { initialized: false };

  if (isSafeWorkspace(workspace, explicitWs)) {
    if (isProjectRoot(workspace) || explicitWs) {
      try { syncWorkspace(workspace); } catch (err) { console.error(`SessionStart sync warning: ${err.message}`); }
    }
    try { memRes = ensureCarpatiMemory(workspace); } catch (err) { console.error(`SessionStart memory init warning: ${err.message}`); }
  }

  const brief = buildL0Brief(workspace);
  const convId = typeof payload?.conversationId === 'string' && payload.conversationId.trim() ? payload.conversationId.trim() : 'default';
  resetChainState({
    conversationId: convId,
    resetTurn: true,
    resetSession: true,
    sessionPatch: { memoryInitialized: memRes.initialized || fs.existsSync(path.join(workspace, 'memory')), memoryBriefInjected: Boolean(brief) }
  });

  const { version, agentCount, skillCount } = readPluginStats();
  const banner = `AGI v${version} active: Carpati L0/L1/L2 memory, Dual-Loop Gates 0-3, Ponytail 7-Rung Restraint, Harness² CI/CD, ${agentCount} SDLC agents, ${skillCount} skills loaded. Mandatory: print '### 🔄 Quad-Loop Execution Telemetry' before invoke_subagent and on stage completion.`;
  const fullMessage = brief ? `${banner}\n\n${brief}` : banner;
  process.stdout.write(JSON.stringify({ injectSteps: [{ systemMessage: { systemMessage: fullMessage } }] }));
  return 0;
}

if (isMainModule(import.meta.url)) process.exitCode = await main();

#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PLUGIN_ROOT = path.resolve(__dirname, '..');
const REQUIRED_SCRIPTS = ['run-shielded.ps1', 'manage-worktree.ps1', 'audit-restraint.ps1'];

export function copyWithoutBOM(srcPath, destPath) {
  let buf = fs.readFileSync(srcPath);
  while (buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) {
    buf = buf.subarray(3);
  }
  const destDir = path.dirname(destPath);
  if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });
  fs.writeFileSync(destPath, buf);
}

function copyDirectoryFiles(srcDir, destDir) {
  if (!fs.existsSync(srcDir)) return 0;
  const entries = fs.readdirSync(srcDir, { withFileTypes: true });
  let count = 0;
  for (const entry of entries) {
    if (entry.isFile()) {
      copyWithoutBOM(path.join(srcDir, entry.name), path.join(destDir, entry.name));
      count++;
    }
  }
  return count;
}

export function parseTarget() {
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if ((args[i] === '--target' || args[i] === '-t') && args[i + 1]) {
      return path.resolve(args[i + 1]);
    }
    if (args[i].startsWith('--target=')) {
      return path.resolve(args[i].slice(9));
    }
  }
  return process.env.ANTIGRAVITY_WORKSPACE || process.env.WORKSPACE_ROOT || process.cwd();
}

function validateDestination(destScriptsDir) {
  const missing = [];
  for (const name of REQUIRED_SCRIPTS) {
    if (!fs.existsSync(path.join(destScriptsDir, name))) missing.push(name);
  }
  if (missing.length > 0) {
    throw new Error(`Sync validation failed: missing scripts [${missing.join(', ')}]`);
  }
}

export function syncWorkspace(targetDir) {
  const resolved = path.resolve(targetDir);
  const destScripts = path.join(resolved, '.agents', 'scripts');
  const destAgents = path.join(resolved, '.agents', 'agents');
  const destSubagents = path.join(resolved, '.agents', 'subagents');

  const scriptsCount = copyDirectoryFiles(path.join(PLUGIN_ROOT, 'scripts'), destScripts);
  const agentsCount = copyDirectoryFiles(path.join(PLUGIN_ROOT, 'agents'), destAgents);
  copyDirectoryFiles(path.join(PLUGIN_ROOT, 'agents'), destSubagents);

  const agentsMdSrc = path.join(PLUGIN_ROOT, 'rules', 'AGENTS.md');
  if (fs.existsSync(agentsMdSrc)) {
    copyWithoutBOM(agentsMdSrc, path.join(resolved, 'AGENTS.md'));
  }

  validateDestination(destScripts);
  return { target: resolved, scriptsCount, agentsCount };
}

function printHelp() {
  console.log(`Usage: sync-workspace-core.mjs [--target <path>]
Synchronizes AGI scripts, agents, and AGENTS.md to workspace.`);
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) {
    printHelp();
    return 0;
  }
  try {
    const target = parseTarget();
    const res = syncWorkspace(target);
    console.log(`Synced core to ${res.target}: ${res.scriptsCount} scripts, ${res.agentsCount} agents.`);
    return 0;
  } catch (err) {
    console.error(`Sync error: ${err.message}`);
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(main());
}

#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REQUIRED_SCRIPTS = ['run-shielded.ps1', 'manage-worktree.ps1', 'audit-restraint.ps1'];
const sha256 = (buf) => crypto.createHash('sha256').update(buf).digest('hex');

function isMain(metaUrl) {
  if (!process.argv[1] || !metaUrl) return false;
  const a = path.resolve(process.argv[1]), b = path.resolve(fileURLToPath(metaUrl));
  return process.platform === 'win32' ? a.toLowerCase() === b.toLowerCase() : a === b;
}

export function prepareFileBuffer(srcPath) {
  let buf = fs.readFileSync(srcPath);
  const hasNonAscii = srcPath.toLowerCase().endsWith('.ps1') && buf.some((b) => b >= 0x80);
  if (hasNonAscii) {
    while (buf.length >= 6 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf && buf[3] === 0xef && buf[4] === 0xbb && buf[5] === 0xbf) buf = buf.subarray(3);
    return buf;
  }
  while (buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) buf = buf.subarray(3);
  return buf;
}

export function copyWithoutBOM(srcPath, destPath) {
  const buf = prepareFileBuffer(srcPath);
  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  fs.writeFileSync(destPath, buf);
}

function readManifest(manifestPath) {
  if (!fs.existsSync(manifestPath)) return { files: {} };
  try {
    const parsed = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    return parsed && typeof parsed.files === 'object' ? parsed : { files: {} };
  } catch (err) {
    console.error(`Manifest read warning: ${err.message}`);
    return { files: {} };
  }
}

function syncFile(srcPath, destPath, relKey, ctx) {
  const buf = prepareFileBuffer(srcPath), srcHash = sha256(buf);
  if (!fs.existsSync(destPath)) {
    fs.mkdirSync(path.dirname(destPath), { recursive: true });
    fs.writeFileSync(destPath, buf);
    ctx.nextFiles[relKey] = srcHash;
    ctx.updated.push(relKey);
    return 'created';
  }
  const destHash = sha256(fs.readFileSync(destPath)), recorded = ctx.prevFiles[relKey];
  if (destHash === srcHash) { ctx.nextFiles[relKey] = srcHash; return 'unchanged'; }
  if (ctx.force || (recorded && destHash === recorded)) {
    fs.writeFileSync(destPath, buf);
    ctx.nextFiles[relKey] = srcHash;
    ctx.updated.push(relKey);
    return 'updated';
  }
  if (recorded) ctx.nextFiles[relKey] = recorded;
  ctx.skipped.push(relKey);
  return 'skipped';
}

function syncDir(srcDir, destDir, relPrefix, ctx) {
  if (!fs.existsSync(srcDir)) return 0;
  let count = 0;
  for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
    if (entry.isFile() && syncFile(path.join(srcDir, entry.name), path.join(destDir, entry.name), `${relPrefix}/${entry.name}`, ctx) !== 'skipped') count++;
  }
  return count;
}

export function parseCliArgs(args = process.argv.slice(2)) {
  let target = process.env.ANTIGRAVITY_WORKSPACE || process.env.WORKSPACE_ROOT || process.cwd(), force = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--force' || args[i] === '-f') force = true;
    else if ((args[i] === '--target' || args[i] === '-t') && args[i + 1]) target = path.resolve(args[++i]);
    else if (args[i].startsWith('--target=')) target = path.resolve(args[i].slice(9));
  }
  return { target: path.resolve(target), force };
}

export const parseTarget = () => parseCliArgs().target;

function validateDestination(destScriptsDir) {
  const missing = REQUIRED_SCRIPTS.filter((name) => !fs.existsSync(path.join(destScriptsDir, name)));
  if (missing.length > 0) throw new Error(`Sync validation failed: missing scripts [${missing.join(', ')}]`);
}

export function syncWorkspace(targetDir, options = {}) {
  const resolved = path.resolve(targetDir), agentsRoot = path.join(resolved, '.agents'), manifestPath = path.join(agentsRoot, '.core-manifest.json');
  const prev = readManifest(manifestPath);
  const ctx = { force: Boolean(options.force), prevFiles: prev.files || {}, nextFiles: { ...prev.files }, updated: [], skipped: [] };
  const scriptsCount = syncDir(path.join(PLUGIN_ROOT, 'scripts'), path.join(agentsRoot, 'scripts'), '.agents/scripts', ctx);
  const agentsCount = syncDir(path.join(PLUGIN_ROOT, 'agents'), path.join(agentsRoot, 'agents'), '.agents/agents', ctx);
  const templatesCount = syncDir(path.join(PLUGIN_ROOT, 'templates'), path.join(agentsRoot, 'templates'), '.agents/templates', ctx);
  const harnessCount = syncDir(path.join(PLUGIN_ROOT, 'harness'), path.join(agentsRoot, 'harness'), '.agents/harness', ctx);
  const agentsMdSrc = path.join(PLUGIN_ROOT, 'rules', 'AGENTS.md');
  if (fs.existsSync(agentsMdSrc)) syncFile(agentsMdSrc, path.join(resolved, 'AGENTS.md'), 'AGENTS.md', ctx);
  fs.mkdirSync(agentsRoot, { recursive: true });
  fs.writeFileSync(manifestPath, JSON.stringify({ updatedAt: new Date().toISOString(), files: ctx.nextFiles }, null, 2), 'utf8');
  validateDestination(path.join(agentsRoot, 'scripts'));
  return { target: resolved, scriptsCount, agentsCount, templatesCount, harnessCount, updated: ctx.updated, skipped: ctx.skipped };
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) { console.log('Usage: sync-workspace-core.mjs [--target <path>] [--force]'); return 0; }
  try {
    const { target, force } = parseCliArgs(args);
    const res = syncWorkspace(target, { force });
    console.log(`Synced core to ${res.target}: scripts=${res.scriptsCount}, agents=${res.agentsCount}, templates=${res.templatesCount}, harness=${res.harnessCount}, skipped=${res.skipped.length}.`);
    return 0;
  } catch (err) {
    console.error(`Sync error: ${err.message}`);
    return 1;
  }
}

if (isMain(import.meta.url)) process.exit(main());
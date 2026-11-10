#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { isMainModule, resolveWorkspaceRoot } from './fs-atomic.mjs';

const MAX_FILE_LINES = 150;
const MAX_FN_LINES = 30;
const MAX_NESTING = 3;
const SKIP_DIRS = new Set(['node_modules', 'dist', 'scratch', 'data', 'output', 'templates']);
const SLOP_PATTERNS = [
  /APCA\s+(?:AAA|AA)\s+PASS/i,
  /STATUS\s*\/\/\s*NODE-PULSE/i,
  /v\d+\.\d+\.\d+\s*\/\/\s*SPEC/i,
  /HEX-AERO-DS\s*\/\/\s*v/i,
  /CARD\s*\/\/\s*CHAMFER/i
];
const JS_FN_RE = /^\s*(?:export\s+)?(?:async\s+)?function\s+([A-Za-z0-9_$]+)|^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z0-9_$]+)\s*=\s*(?:async\s*)?(?:\([^)]*\)|[A-Za-z0-9_$]+)\s*=>\s*\{/;
const PY_FN_RE = /^(\s*)(?:async\s+)?def\s+([A-Za-z0-9_]+)\s*\(/;

function checkPyFnLengths(lines) {
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(PY_FN_RE);
    if (!m) continue;
    const baseIndent = m[1].length;
    let end = i;
    for (let j = i + 1; j < lines.length; j++) {
      const t = lines[j].trim();
      if (!t || t.startsWith('#')) continue;
      if (lines[j].match(/^\s*/)[0].length <= baseIndent) break;
      end = j;
    }
    const len = end - i + 1;
    if (len > MAX_FN_LINES) out.push(`Line ${i + 1}: Function "${m[2]}" exceeds ${MAX_FN_LINES} lines (${len}L)`);
  }
  return out;
}

function checkJsFnLengths(lines) {
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(JS_FN_RE);
    if (!m) continue;
    const name = m[1] || m[2] || 'anonymous';
    let depth = 0;
    let opened = false;
    let end = i;
    for (let j = i; j < lines.length; j++) {
      const stripped = lines[j].replace(/(['"`])(?:\\.|(?!\1).)*\1/g, '');
      const opens = (stripped.match(/\{/g) || []).length;
      const closes = (stripped.match(/\}/g) || []).length;
      if (opens > 0) opened = true;
      depth += opens - closes;
      end = j;
      if (opened && depth <= 0) break;
    }
    const len = end - i + 1;
    if (len > MAX_FN_LINES) out.push(`Line ${i + 1}: Function "${name}" exceeds ${MAX_FN_LINES} lines (${len}L)`);
  }
  return out;
}

function detectIndentUnit(lines, isPy) {
  if (isPy) return 4;
  for (const l of lines) {
    const m = l.match(/^( +)[^ ]/);
    if (m && (m[1].length === 2 || m[1].length === 6)) return 2;
  }
  return 4;
}

function checkNesting(lines, filePath) {
  const isPy = filePath.endsWith('.py');
  const unit = detectIndentUnit(lines, isPy);
  const out = [];
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const trimmed = raw.trim();
    if (!trimmed || trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*') || trimmed.startsWith('#')) continue;
    const m = raw.match(/^([ \t]+)/);
    if (!m) continue;
    const tabs = (m[1].match(/\t/g) || []).length;
    const spaces = m[1].replace(/\t/g, '').length;
    const level = tabs + Math.floor(spaces / unit);
    if (level > MAX_NESTING) out.push(`Line ${i + 1}: Cognitive nesting exceeds ${MAX_NESTING} levels (actual: ${level})`);
  }
  return out;
}

export function auditFile(filePath) {
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  const violations = [];
  if (lines.length > MAX_FILE_LINES && !filePath.endsWith('.json') && !filePath.endsWith('AGENTS.md')) {
    violations.push(`File exceeds ${MAX_FILE_LINES} lines (actual: ${lines.length} lines)`);
  }
  for (let i = 0; i < lines.length; i++) {
    for (const pat of SLOP_PATTERNS) {
      if (pat.test(lines[i])) violations.push(`Line ${i + 1}: Prohibited AI Slop pattern detected (${pat})`);
    }
  }
  const fnViolations = filePath.endsWith('.py') ? checkPyFnLengths(lines) : checkJsFnLengths(lines);
  const nestingViolations = checkNesting(lines, filePath);
  return violations.concat(fnViolations, nestingViolations);
}

export function scanDir(dir) {
  if (!dir || !fs.existsSync(dir)) return [];
  if (fs.statSync(dir).isFile()) {
    const v = auditFile(dir);
    return v.length > 0 ? [{ file: dir, violations: v }] : [];
  }
  let all = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') || SKIP_DIRS.has(entry.name)) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      all = all.concat(scanDir(fullPath));
    } else if (/\.(ts|js|mjs|py|vue|tsx|jsx)$/.test(entry.name)) {
      const v = auditFile(fullPath);
      if (v.length > 0) all.push({ file: fullPath, violations: v });
    }
  }
  return all;
}

function main() {
  const target = process.argv[2] ? path.resolve(process.argv[2]) : resolveWorkspaceRoot({});
  if (!fs.existsSync(target)) {
    console.error(`Audit skipped: target directory does not exist (${target}).`);
    return 1;
  }
  console.log(`Auditing Ponytail & Micro-Modularity in: ${target}`);
  const violations = scanDir(target);
  if (violations.length === 0) {
    console.log('Ponytail & Micro-Modularity Hard Gate: PASSED (0 violations).');
    return 0;
  }
  console.error(`Ponytail & Micro-Modularity Hard Gate: FAILED (${violations.length} files violated).`);
  for (const item of violations) {
    console.error(`\nFile: ${item.file}`);
    for (const msg of item.violations) console.error(`  - ${msg}`);
  }
  return 1;
}

if (isMainModule(import.meta.url)) process.exit(main());

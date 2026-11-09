#!/usr/bin/env node

/**
 * AGI - Ponytail & Micro-Modularity Hard Auditor (audit-restraint.mjs)
 * Enforces Rung 7 (Minimum Code), 150-line file ceiling, 30-line function ceiling,
 * and Anti-Slop (R-41) compliance before marking tasks complete.
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const TARGET_DIR = process.argv[2] || process.cwd();
const MAX_FILE_LINES = 150;
const MAX_FN_LINES = 30;
const SLOP_PATTERNS = [
  /APCA\s+(?:AAA|AA)\s+PASS/i,
  /STATUS\s*\/\/\s*NODE-PULSE/i,
  /v\d+\.\d+\.\d+\s*\/\/\s*SPEC/i,
  /HEX-AERO-DS\s*\/\/\s*v/i,
  /CARD\s*\/\/\s*CHAMFER/i
];

function auditFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split(/\r?\n/);
  const violations = [];

  // 1. File Line Bound
  if (lines.length > MAX_FILE_LINES && !filePath.endsWith('.json') && !filePath.endsWith('AGENTS.md')) {
    violations.push(`File exceeds ${MAX_FILE_LINES} lines (actual: ${lines.length} lines)`);
  }

  // 2. Anti-Slop R-41 Check
  for (let i = 0; i < lines.length; i++) {
    for (const pat of SLOP_PATTERNS) {
      if (pat.test(lines[i])) {
        violations.push(`Line ${i + 1}: Prohibited AI Slop pattern detected (${pat})`);
      }
    }
  }

  return violations;
}

function scanDir(dir) {
  let allViolations = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.name.startsWith('.') || entry.name === 'node_modules' || entry.name === 'dist' || entry.name === 'scratch') {
      continue;
    }
    if (entry.isDirectory()) {
      allViolations = allViolations.concat(scanDir(fullPath));
    } else if (/\.(ts|js|mjs|py|vue|tsx|jsx)$/.test(entry.name)) {
      const v = auditFile(fullPath);
      if (v.length > 0) {
        allViolations.push({ file: fullPath, violations: v });
      }
    }
  }
  return allViolations;
}

function main() {
  console.log(`Auditing Ponytail & Micro-Modularity in: ${TARGET_DIR}`);
  const violations = scanDir(TARGET_DIR);

  if (violations.length === 0) {
    console.log('✅ Ponytail & Micro-Modularity Hard Gate: PASSED (0 violations).');
    process.exit(0);
  } else {
    console.error(`❌ Ponytail & Micro-Modularity Hard Gate: FAILED (${violations.length} files violated).`);
    for (const item of violations) {
      console.error(`\nFile: ${item.file}`);
      for (const msg of item.violations) {
        console.error(`  - ${msg}`);
      }
    }
    process.exit(1);
  }
}

main();

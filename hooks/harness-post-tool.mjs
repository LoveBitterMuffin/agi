#!/usr/bin/env node

/**
 * AGI - Harness² PostToolUse Hook (harness-post-tool.mjs)
 * Automatically intercepts failed tool commands, captures stack traces,
 * and forces the Propose-Probe-Compose self-learning loop.
 */

import process from 'node:process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const INCIDENT_LOG = path.resolve(__dirname, '..', 'memory', 'harness_incidents.json');

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', chunk => { data += chunk; });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', () => resolve(''));
  });
}

async function main() {
  const raw = await readStdin();
  if (!raw || !raw.trim()) {
    process.stdout.write('{}');
    return 0;
  }

  let payload = {};
  try {
    payload = JSON.parse(raw);
  } catch {
    process.stdout.write('{}');
    return 0;
  }

  const exitCode = payload?.result?.exit_code ?? payload?.result?.exitCode ?? payload?.exitCode;
  const error = payload?.error ?? payload?.result?.error;
  const command = payload?.tool_args?.CommandLine ?? payload?.tool_args?.commandLine ?? payload?.commandLine;

  const isFailure = (typeof exitCode === 'number' && exitCode !== 0) || Boolean(error);

  if (isFailure) {
    const incident = {
      timestamp: new Date().toISOString(),
      command: command || 'unknown',
      exitCode: exitCode ?? 'error',
      errorSlice: String(error || payload?.result?.output || '').slice(0, 500)
    };

    try {
      const memoryDir = path.dirname(INCIDENT_LOG);
      if (!fs.existsSync(memoryDir)) fs.mkdirSync(memoryDir, { recursive: true });
      let list = [];
      if (fs.existsSync(INCIDENT_LOG)) {
        list = JSON.parse(fs.readFileSync(INCIDENT_LOG, 'utf8') || '[]');
      }
      list.push(incident);
      if (list.length > 50) list = list.slice(-50);
      fs.writeFileSync(INCIDENT_LOG, JSON.stringify(list, null, 2), 'utf8');
    } catch {
      // Non-blocking file append
    }

    const alertMsg = `[Harness² Active Loop 4] Execution failure detected in command: "${command || 'task'}". Propose-Probe-Compose self-learning loop engaged. Review error slice and record resolution into 099_learnings.md.`;
    process.stdout.write(JSON.stringify({ additionalContext: alertMsg }));
    return 0;
  }

  process.stdout.write('{}');
  return 0;
}

process.exitCode = await main();

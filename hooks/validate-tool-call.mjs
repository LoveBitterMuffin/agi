#!/usr/bin/env node

import process from 'node:process';
import { pathToFileURL } from 'node:url';
import { recordToolCall } from './tool-chain-state.mjs';
import { evaluatePreSubagent } from './quad-loop-guard.mjs';

const BLOCK_RULES = [
  { id: 'unix-root-delete', pattern: /(?:^|[;&|]\s*)(?:sudo\s+)?rm\s+(?:-[A-Za-z]*r[A-Za-z]*f[A-Za-z]*|-[A-Za-z]*f[A-Za-z]*r[A-Za-z]*)\s+(?:--\s+)?\/(?:\*|\s|$)/i, message: 'recursive deletion of the filesystem root' },
  { id: 'filesystem-format', pattern: /(?:^|[;&|]\s*)(?:sudo\s+)?mkfs(?:\.[A-Za-z0-9_-]+)?\b/i, message: 'filesystem formatting command' },
  { id: 'raw-disk-overwrite', pattern: /\bdd\b[^\n]*\bof=\/dev\/(?:sd|nvme|vd|xvd)[A-Za-z0-9_-]*/i, message: 'raw disk overwrite' },
  { id: 'windows-drive-format', pattern: /(?:^|[;&|]\s*)format(?:\.com)?\s+[A-Za-z]:/i, message: 'Windows drive format' },
  { id: 'windows-root-delete', pattern: /remove-item\b[^\n]*-(?:recurse|r)\b[^\n]*-(?:force|fo)\b[^\n]*(?:[A-Za-z]:\\(?:\s|$)|[A-Za-z]:\\\*)/i, message: 'recursive deletion of a Windows drive root' },
  { id: 'windows-cmd-root-delete', pattern: /(?:^|[;&|]\s*)(?:rd|rmdir)\s+\/s\s+\/q\s+[A-Za-z]:\\(?:\*|\s|$)/i, message: 'recursive deletion of a Windows drive root via cmd' }
];

function readStdin() {
  return new Promise((resolve, reject) => {
    let input = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      input += chunk;
      if (input.length > 1024 * 1024) reject(new Error('hook payload exceeds 1 MiB'));
    });
    process.stdin.on('end', () => resolve(input));
    process.stdin.on('error', reject);
  });
}

function firstString(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return '';
}

export function extractCommand(payload) {
  const args = payload?.toolCall?.args ?? payload?.tool_args ?? payload?.toolArgs ?? payload?.arguments ?? {};
  return firstString(args.CommandLine, args.commandLine, args.command, args.cmd, payload?.command, payload?.cmd);
}

export function extractToolName(payload) {
  const name = payload?.toolCall?.name ?? payload?.tool_name ?? payload?.toolName ?? payload?.name ?? payload?.tool;
  if (typeof name === 'string' && name.trim()) return name.trim();
  if (extractCommand(payload)) return 'run_command';
  return '';
}

export function handleToolChainBound(toolName, payload = {}) {
  return recordToolCall({ toolName, payload });
}

export function evaluateCommand(command) {
  for (const rule of BLOCK_RULES) {
    if (rule.pattern.test(command)) {
      return { allowed: false, rule: rule.id, reason: rule.message };
    }
  }
  return { allowed: true, rule: null, reason: 'no destructive command pattern matched' };
}

function gateSubagent(toolName, payload) {
  if (toolName !== 'invoke_subagent') return 0;
  const gate = evaluatePreSubagent(payload);
  if (!gate.allowed) {
    process.stdout.write(JSON.stringify({ decision: 'deny', reason: gate.reason }));
    console.error(gate.reason);
    return 2;
  }
  if (payload?.transcriptPath) {
    process.stdout.write(JSON.stringify({ decision: 'allow' }));
  }
  return 0;
}

async function readPayload() {
  const raw = await readStdin();
  if (!raw || !raw.trim()) return {};
  return JSON.parse(raw);
}

async function main() {
  let payload = {};
  try {
    payload = await readPayload();
  } catch (error) {
    const label = error instanceof SyntaxError ? 'Antigravity sent invalid JSON; allowing call.' : error.message;
    console.error(`AGI hook warning: ${label}`);
    return 0;
  }

  const command = extractCommand(payload);
  if (command) {
    const evalResult = evaluateCommand(command);
    if (!evalResult.allowed) {
      console.error(`BLOCKED by AGI (${evalResult.rule}): ${evalResult.reason}.`);
      return 1;
    }
  }

  const toolName = extractToolName(payload);
  const chainResult = handleToolChainBound(toolName, payload);
  if (!chainResult.allowed) {
    console.error(chainResult.message);
    return chainResult.exitCode;
  }

  return gateSubagent(toolName, payload);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const code = await main();
  if (code !== 0) process.exit(code);
}

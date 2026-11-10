#!/usr/bin/env node

import process from 'node:process';
import { isMainModule, readStdinText, resolveWorkspaceRoot } from './fs-atomic.mjs';
import { evaluateCommand } from './command-guard.mjs';
import { evaluateMemoryAndLifecycleGate } from './gate-lifecycle.mjs';
import { evaluatePreSubagent, inspectTurnTranscript } from './quad-loop-guard.mjs';
import { getTurnTelemetryState, isKnownSubagent, readChainState, recordToolCall } from './tool-chain-state.mjs';

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
  return extractCommand(payload) ? 'run_command' : '';
}

export function handleToolChainBound(toolName, payload = {}) {
  return recordToolCall({ toolName, payload });
}

export { evaluateCommand };

function deny(reason) {
  process.stdout.write(JSON.stringify({ decision: 'deny', reason }));
  console.error(reason);
  return 2;
}

function evaluatePayload(payload) {
  const command = extractCommand(payload);
  if (command) {
    const cmdEval = evaluateCommand(command);
    if (!cmdEval.allowed) return deny(`BLOCKED by AGI (${cmdEval.rule}): ${cmdEval.reason}.`);
  }
  const toolName = extractToolName(payload);
  const bareTool = toolName.replace(/^default_api:/i, '').toLowerCase();
  const convId = typeof payload?.conversationId === 'string' && payload.conversationId ? payload.conversationId : 'default';
  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  const state = readChainState();
  const isSubagent = isKnownSubagent(payload, state);
  if (!isSubagent) {
    const chainResult = handleToolChainBound(toolName, payload);
    if (!chainResult.allowed) return deny(chainResult.message);
  }
  const transcript = payload?.transcriptPath ? inspectTurnTranscript(payload.transcriptPath, userInput) : { available: false, turnAnchor: '' };
  const convEntry = getTurnTelemetryState({ conversationId: convId, lastUserInput: userInput, turnAnchor: transcript.turnAnchor });
  const lifecycle = evaluateMemoryAndLifecycleGate(toolName, payload, { convId, userInput, state, convEntry, transcript, workspace: resolveWorkspaceRoot(payload), isSubagent });
  if (!lifecycle.allowed) return deny(lifecycle.reason);
  if (bareTool !== 'invoke_subagent') return 0;
  const subGate = evaluatePreSubagent(payload);
  if (!subGate.allowed) return deny(subGate.reason);
  if (payload?.transcriptPath) process.stdout.write(JSON.stringify({ decision: 'allow' }));
  return 0;
}

async function main() {
  let payload = {};
  try {
    const raw = await readStdinText();
    if (raw && raw.trim()) payload = JSON.parse(raw);
  } catch (error) {
    console.error(`AGI hook warning: ${error instanceof SyntaxError ? 'Antigravity sent invalid JSON; allowing call.' : error.message}`);
    return 0;
  }
  return evaluatePayload(payload);
}

if (isMainModule(import.meta.url)) {
  const code = await main();
  if (code !== 0) process.exit(code);
}

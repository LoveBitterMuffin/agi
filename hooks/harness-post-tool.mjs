#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { isMainModule, readStdinText, resolveWorkspaceRoot, tryParseJson, withStateLock, writeJsonAtomic } from './fs-atomic.mjs';
import { extractFileTarget, getToolArgs, isCodeMutationPath, isSpecArtifactPath } from './gate-lifecycle.mjs';
import { isMemoryPath, isMemoryScriptCmd } from './memory-bootstrap.mjs';
import { isKnownSubagent, registerSubagent, updateConversationState } from './tool-chain-state.mjs';

function extractConvId(payload) {
  return typeof payload?.conversationId === 'string' && payload.conversationId ? payload.conversationId : 'default';
}

function extractSpawnedConvId(result) {
  if (result && typeof result === 'object') {
    const direct = result.conversationId ?? result.conversation_id ?? result.subagentConversationId ?? result.id;
    if (typeof direct === 'string' && direct.trim()) return direct.trim();
  }
  const text = typeof result === 'string' ? result : JSON.stringify(result || '');
  const match = text.match(/conversationId["':=\s]+([a-zA-Z0-9_-]{8,})/i);
  return match ? match[1] : '';
}

function resolveIncidentLogPath(workspace) {
  if (process.env.ANTIGRAVITY_INCIDENTS_PATH) return process.env.ANTIGRAVITY_INCIDENTS_PATH;
  const memDir = path.join(workspace, 'memory');
  return fs.existsSync(memDir)
    ? path.join(memDir, 'logs', 'harness_incidents.json')
    : path.join(workspace, 'scratch', 'logs', 'harness_incidents.json');
}

function appendIncident(workspace, command, exitCode, errorSlice) {
  const logPath = resolveIncidentLogPath(workspace);
  withStateLock(logPath, () => {
    const existing = fs.existsSync(logPath) ? tryParseJson(fs.readFileSync(logPath, 'utf8'), []) : [];
    const list = Array.isArray(existing) ? existing : [];
    list.push({ timestamp: new Date().toISOString(), command: command || 'unknown', exitCode: exitCode ?? 'error', errorSlice });
    writeJsonAtomic(logPath, list.slice(-50));
  });
}

function handleCommandResult(convId, workspace, payload, isFailure) {
  const args = getToolArgs(payload);
  const cmd = args.CommandLine ?? args.commandLine ?? args.command ?? payload?.commandLine ?? '';
  if (isFailure) {
    const exitCode = payload?.result?.exit_code ?? payload?.result?.exitCode ?? payload?.exitCode;
    const errText = String(payload?.error ?? payload?.result?.error ?? payload?.result?.output ?? '').slice(0, 500);
    appendIncident(workspace, cmd, exitCode, errText);
    const msg = `[Harness² Active Loop 4] Execution failure detected in command: "${cmd || 'task'}". Propose-Probe-Compose self-learning loop engaged. Review error slice and record resolution into 099_learnings.md.`;
    return { injectSteps: [{ systemMessage: { systemMessage: msg } }] };
  }
  if (isMemoryScriptCmd(cmd)) {
    const patch = {};
    if (/get-memory-brief/i.test(cmd)) patch.memoryRead = true;
    if (/audit-memory/i.test(cmd)) patch.memoryAudited = true;
    if (Object.keys(patch).length > 0) updateConversationState(convId, patch);
  }
  return {};
}

function trackPostToolState(tool, convId, workspace, payload, isFailure) {
  if (tool === 'run_command') return handleCommandResult(convId, workspace, payload, isFailure);
  if (isFailure) return {};
  if (tool === 'ask_question') {
    updateConversationState(convId, { gate0Passed: true });
  } else if (tool === 'read_file' && isMemoryPath(extractFileTarget(payload))) {
    updateConversationState(convId, { memoryRead: true });
  } else if (tool === 'write_file' || tool === 'edit_file') {
    const target = extractFileTarget(payload);
    if (tool === 'write_file' && isSpecArtifactPath(target)) updateConversationState(convId, { specDrafted: true });
    else if (isMemoryPath(target)) updateConversationState(convId, { memoryRead: true });
    else if (!isKnownSubagent(payload) && isCodeMutationPath(target)) updateConversationState(convId, { hasCodeMutation: true, memoryAudited: false });
  } else if (tool === 'invoke_subagent') {
    const spawned = extractSpawnedConvId(payload?.result ?? payload?.toolResult);
    const args = getToolArgs(payload);
    if (spawned) registerSubagent(spawned, { role: args.Role || args.role || '', type: args.TypeName || args.typeName || '', parent: convId });
  }
  return {};
}

async function main() {
  const raw = await readStdinText();
  const payload = raw.trim() ? tryParseJson(raw, null, (e) => console.error(`PostTool JSON warning: ${e.message}`)) : null;
  if (!payload) { process.stdout.write('{}'); return 0; }
  const rawTool = payload?.toolCall?.name ?? payload?.tool_name ?? payload?.toolName ?? payload?.name ?? 'run_command';
  const tool = String(rawTool).replace(/^default_api:/i, '').toLowerCase();
  const exitCode = payload?.result?.exit_code ?? payload?.result?.exitCode ?? payload?.exitCode;
  const isFailure = (typeof exitCode === 'number' && exitCode !== 0) || Boolean(payload?.error ?? payload?.result?.error);
  const out = trackPostToolState(tool, extractConvId(payload), resolveWorkspaceRoot(payload), payload, isFailure);
  process.stdout.write(JSON.stringify(out));
  return 0;
}

if (isMainModule(import.meta.url)) process.exitCode = await main();

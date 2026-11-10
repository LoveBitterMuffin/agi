#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { isMainModule, readStdinText, resolveWorkspaceRoot, tryParseJson } from './fs-atomic.mjs';
import { scanTranscriptLifecycle } from './memory-bootstrap.mjs';
import { getTurnTelemetryState, incrementTurnTelemetryCounter, isKnownSubagent, markFallbackRendered, readChainState, resetChainState, updateConversationState } from './tool-chain-state.mjs';

const WORK_TOOLS = new Set(['invoke_subagent', 'write_file', 'edit_file', 'run_command']);
const CARD_MARKERS = ['Quad-Loop Execution Telemetry', '[Loop 1', '[Loop 2', '[Loop 3', '[Loop 4'];
const SUBAGENT_DENY_REASON = "Quad-Loop Telemetry Gate: Output '### 🔄 Quad-Loop Execution Telemetry' (Loops 1-4) in chat BEFORE calling invoke_subagent.";
const STOP_CONTINUE_REASON = "Quad-Loop Telemetry Gate: Output '### 🔄 Quad-Loop Execution Telemetry' summarizing Loops 1-4 before concluding this stage.";
const GATE3_CONTINUE_REASON = 'Gate 3 Required: Run audit-memory.ps1 and output the Acceptance Criteria Evidence Table (AC-xx ... PASSED/FAILED) before concluding.';

const bareName = (n) => String(n || '').replace(/^default_api:/i, '').trim().toLowerCase();
const isStepType = (s, t) => { const u = String(s?.type || '').toUpperCase(); return u === t || u === `CORTEX_STEP_TYPE_${t}`; };
const stepText = (s) => typeof s?.content === 'string' ? s.content : (Array.isArray(s?.content) ? s.content.map((p) => p?.text || '').join('\n') : String(s?.text ?? s?.userInput ?? ''));
const stepCalls = (s) => Array.isArray(s?.tool_calls) ? s.tool_calls : (Array.isArray(s?.toolCalls) ? s.toolCalls : []);
const callName = (tc) => bareName(typeof tc === 'string' ? tc : (tc?.name ?? tc?.tool_name ?? tc?.toolName ?? tc?.function?.name ?? ''));
const callArgs = (tc) => (tc && typeof tc === 'object' ? (tc.args ?? tc.arguments ?? tc.tool_args ?? {}) : {});
const hasWorkTool = (s) => stepCalls(s).some((tc) => WORK_TOOLS.has(callName(tc)));
const HELPERS = { isStepType, stepText, stepCalls, callName, callArgs };

function parseBufLines(buf, baseOffset) {
  const out = [];
  for (let pos = 0; pos < buf.length; ) {
    const nl = buf.indexOf(0x0a, pos), raw = buf.subarray(pos, nl === -1 ? buf.length : nl).toString('utf8').trim();
    const step = raw ? tryParseJson(raw, null) : null;
    if (step && typeof step === 'object') out.push({ step, offset: baseOffset + pos });
    pos = nl === -1 ? buf.length : nl + 1;
  }
  return out;
}

function readTailSteps(transcriptPath, needle = '') {
  if (!transcriptPath || typeof transcriptPath !== 'string' || !fs.existsSync(transcriptPath)) return null;
  let fd;
  try {
    const size = fs.statSync(transcriptPath).size;
    if (size <= 0) return null;
    fd = fs.openSync(transcriptPath, 'r');
    for (let win = 262144; ; win *= 2) {
      const start = Math.max(0, size - win), buf = Buffer.alloc(size - start);
      fs.readSync(fd, buf, 0, buf.length, start);
      const rows = parseBufLines(buf, start);
      const hasUi = rows.some((r) => isStepType(r.step, 'USER_INPUT'));
      const hasMatch = !needle || rows.some((r) => isStepType(r.step, 'USER_INPUT') && stepText(r.step).trim() === needle);
      if ((hasUi && (hasMatch || win >= 2097152)) || start === 0) return rows.length > 0 ? rows : null;
    }
  } catch (err) { console.error(`Quad-loop transcript read warning: ${err.message}`); return null; }
  finally { if (fd !== undefined) fs.closeSync(fd); }
}

export function inspectTurnTranscript(transcriptPath, lastUserInput = '') {
  const needle = typeof lastUserInput === 'string' ? lastUserInput.trim() : '', rows = readTailSteps(transcriptPath, needle);
  if (!rows) return { available: false, hasCard: false, hasWork: false, hasGate3Table: false, hasMemoryRead: false, hasAskQuestion: false, hasSpecApproval: false, plannerCount: 0, lastPlannerOffset: null, turnAnchor: '' };
  let lastIdx = -1, matchIdx = -1;
  for (let i = rows.length - 1; i >= 0; i--) {
    if (!isStepType(rows[i].step, 'USER_INPUT')) continue;
    if (lastIdx === -1) lastIdx = i;
    if (needle && stepText(rows[i].step).trim() === needle) { matchIdx = i; break; }
  }
  const startIdx = matchIdx >= 0 ? matchIdx : lastIdx, turnRows = startIdx >= 0 ? rows.slice(startIdx + 1) : [];
  const plannerRows = turnRows.filter((r) => isStepType(r.step, 'PLANNER_RESPONSE'));
  const combined = plannerRows.map((r) => stepText(r.step)).join('\n'), anchor = startIdx >= 0 ? rows[startIdx] : null;
  return {
    available: true, hasCard: CARD_MARKERS.every((m) => combined.includes(m)), hasWork: turnRows.some((r) => hasWorkTool(r.step)),
    hasGate3Table: /\bAC-\d+/i.test(combined) && /\b(?:PASSED|FAILED|PASS|FAIL)\b/i.test(combined), ...scanTranscriptLifecycle(rows, HELPERS),
    plannerCount: plannerRows.length, lastPlannerOffset: plannerRows.length > 0 ? plannerRows[plannerRows.length - 1].offset : null,
    turnAnchor: anchor ? String(anchor.step.step_index ?? anchor.step.created_at ?? anchor.offset) : ''
  };
}

function readIncidentCount(payload = {}) {
  const ws = resolveWorkspaceRoot(payload);
  for (const filePath of [process.env.ANTIGRAVITY_INCIDENTS_PATH, path.join(ws, 'memory', 'logs', 'harness_incidents.json'), path.join(ws, 'scratch', 'logs', 'harness_incidents.json')].filter(Boolean)) {
    if (!fs.existsSync(filePath)) continue;
    const parsed = tryParseJson(fs.readFileSync(filePath, 'utf8'), null, (e) => console.error(`Incident read warning: ${e.message}`));
    if (Array.isArray(parsed)) return parsed.length;
  }
  return 0;
}

function parseContext(payload = {}) {
  const convId = typeof payload?.conversationId === 'string' && payload.conversationId ? payload.conversationId : 'default', userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  const transcript = inspectTurnTranscript(payload?.transcriptPath, userInput);
  return { convId, userInput, transcript, telem: getTurnTelemetryState({ conversationId: convId, lastUserInput: userInput, turnAnchor: transcript.turnAnchor }) };
}

export const buildTelemetryReminder = ({ chainCalls = 0, incidentsCount = 0, stopRetries = 0, subagentDenies = 0 } = {}) =>
  `Mandatory: Print '### 🔄 Quad-Loop Execution Telemetry' ([Loop 1 Human Gate], [Loop 2 Selection & Restraint], [Loop 3 Swarm Execution], [Loop 4 Learning & Memory]) before invoke_subagent or concluding. Live: chainCalls=${chainCalls}, incidents=${incidentsCount}, stopRetries=${stopRetries}, subagentDenies=${subagentDenies}.`;

export const buildFallbackMarkdownCard = ({ chainCalls = 0, incidentsCount = 0, stopRetries = 0, subagentDenies = 0 } = {}) =>
  `### 🔄 Quad-Loop Execution Telemetry\n- **[Loop 1 Human Gate]:** Stage completed (hook fallback rendered after Stop retry)\n- **[Loop 2 Selection & Restraint]:** Ponytail 7-Rung active | chain calls: ${chainCalls}\n- **[Loop 3 Swarm Execution]:** Subagent gate denies: ${subagentDenies} | Stop retries: ${stopRetries}\n- **[Loop 4 Learning & Memory]:** Harness² incidents: ${incidentsCount}`;

export function evaluatePreInvocation(payload = {}) {
  const { convId, userInput, transcript, telem } = parseContext(payload);
  if (transcript.hasCard) return {};
  const chainCalls = readChainState().conversations?.[convId]?.consecutiveCalls ?? 0, ctx = { chainCalls, incidentsCount: readIncidentCount(payload), stopRetries: telem.stopTelemetryRetries, subagentDenies: telem.subagentCardGateDenies }, reminder = buildTelemetryReminder(ctx);
  if (telem.stopTelemetryRetries >= 1 && !telem.fallbackRendered) {
    markFallbackRendered({ conversationId: convId, lastUserInput: userInput, turnAnchor: transcript.turnAnchor });
    return { injectSteps: [{ ephemeralMessage: reminder }, { systemMessage: { systemMessage: '', metadata: { user_markdown: buildFallbackMarkdownCard(ctx) } } }] };
  }
  return { injectSteps: [{ ephemeralMessage: reminder }] };
}

export function evaluatePreSubagent(payload = {}) {
  const { convId, userInput, transcript, telem } = parseContext(payload);
  if (!transcript.available || transcript.hasCard) return { allowed: true, decision: 'allow' };
  const sameBatch = transcript.plannerCount > 0 && transcript.lastPlannerOffset !== null && telem.lastDeniedPlannerOffset === transcript.lastPlannerOffset;
  if (sameBatch) return { allowed: false, decision: 'deny', reason: SUBAGENT_DENY_REASON };
  if (telem.subagentCardGateDenies < 2) {
    incrementTurnTelemetryCounter({ conversationId: convId, lastUserInput: userInput, turnAnchor: transcript.turnAnchor, field: 'subagentCardGateDenies' });
    updateConversationState(convId, { lastDeniedPlannerOffset: transcript.lastPlannerOffset });
    return { allowed: false, decision: 'deny', reason: SUBAGENT_DENY_REASON };
  }
  return { allowed: true, decision: 'allow' };
}

export function evaluateStop(payload = {}) {
  const { convId, userInput, transcript, telem } = parseContext(payload), isSub = isKnownSubagent(payload, readChainState()), isNoTool = payload?.terminationReason === 'NO_TOOL_CALL';
  if (isNoTool && transcript.available && transcript.hasWork && !transcript.hasCard && telem.stopTelemetryRetries < 1) {
    incrementTurnTelemetryCounter({ conversationId: convId, lastUserInput: userInput, turnAnchor: transcript.turnAnchor, field: 'stopTelemetryRetries' });
    return { decision: 'continue', reason: STOP_CONTINUE_REASON };
  }
  if (isNoTool && !isSub && telem.hasCodeMutation && (!transcript.hasGate3Table || !telem.memoryAudited) && telem.stopGate3Retries < 1) {
    incrementTurnTelemetryCounter({ conversationId: convId, lastUserInput: userInput, turnAnchor: transcript.turnAnchor, field: 'stopGate3Retries' });
    return { decision: 'continue', reason: GATE3_CONTINUE_REASON };
  }
  resetChainState({ conversationId: convId, lastUserInput: userInput, turnAnchor: transcript.turnAnchor, resetTurn: true, sessionPatch: { hasCodeMutation: false } });
  return {};
}

export const evaluatePostInvocation = (payload = {}) => ({ injectSteps: [], terminationBehavior: '' });

async function main() {
  const idx = process.argv.indexOf('--event'), event = idx >= 0 ? process.argv[idx + 1] : '', payload = tryParseJson((await readStdinText()).trim() || '{}', {});
  if (event === 'pre-invocation') { process.stdout.write(JSON.stringify(evaluatePreInvocation(payload))); return 0; }
  if (event === 'post-invocation') { process.stdout.write(JSON.stringify(evaluatePostInvocation(payload))); return 0; }
  if (event === 'stop') { process.stdout.write(JSON.stringify(evaluateStop(payload))); return 0; }
  if (event === 'pre-subagent') {
    const res = evaluatePreSubagent(payload);
    process.stdout.write(JSON.stringify({ decision: res.decision, ...(res.reason ? { reason: res.reason } : {}) }));
    if (!res.allowed) { console.error(res.reason); return 2; }
  } else process.stdout.write('{}');
  return 0;
}

if (isMainModule(import.meta.url)) process.exitCode = await main();
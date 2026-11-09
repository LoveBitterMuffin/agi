#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { getTurnTelemetryState, incrementTurnTelemetryCounter, markFallbackRendered, readChainState, resetChainState } from './tool-chain-state.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_INCIDENTS = path.resolve(__dirname, '..', 'memory', 'harness_incidents.json');
const WORK_TOOLS = new Set(['invoke_subagent', 'write_file', 'edit_file', 'run_command']);
const CARD_MARKERS = ['Quad-Loop Execution Telemetry', '[Loop 1', '[Loop 2', '[Loop 3', '[Loop 4'];
const SUBAGENT_DENY_REASON = "Quad-Loop Telemetry Gate: Output '### 🔄 Quad-Loop Execution Telemetry' (Loops 1-4) in chat BEFORE calling invoke_subagent.";
const STOP_CONTINUE_REASON = "Quad-Loop Telemetry Gate: Output '### 🔄 Quad-Loop Execution Telemetry' summarizing Loops 1-4 before concluding this stage.";

const tryParseJson = (raw) => { try { return JSON.parse(raw); } catch { return null; } };
const isStepType = (step, target) => {
  const t = String(step?.type || '').toUpperCase();
  return t === target || t === `CORTEX_STEP_TYPE_${target}`;
};

function readTailSteps(transcriptPath) {
  if (!transcriptPath || typeof transcriptPath !== 'string' || !fs.existsSync(transcriptPath)) return null;
  let fd;
  try {
    const size = fs.statSync(transcriptPath).size;
    if (size <= 0) return null;
    const start = Math.max(0, size - 262144);
    const buf = Buffer.alloc(size - start);
    fd = fs.openSync(transcriptPath, 'r');
    fs.readSync(fd, buf, 0, buf.length, start);
    const steps = buf.toString('utf8').split(/\r?\n/).map((l) => tryParseJson(l.trim())).filter((s) => s && typeof s === 'object');
    return steps.length > 0 ? steps : null;
  } catch (err) {
    console.error(`Quad-loop transcript read warning: ${err.message}`);
    return null;
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
}

function stepText(step) {
  if (typeof step?.content === 'string') return step.content;
  if (Array.isArray(step?.content)) return step.content.map((p) => p?.text || '').join('\n');
  return String(step?.text ?? step?.userInput ?? '');
}

function hasWorkTool(step) {
  const calls = Array.isArray(step?.tool_calls) ? step.tool_calls : (Array.isArray(step?.toolCalls) ? step.toolCalls : []);
  return calls.some((tc) => WORK_TOOLS.has(String(typeof tc === 'string' ? tc : (tc?.name ?? tc?.tool_name ?? tc?.toolName ?? tc?.function?.name ?? '')).trim().toLowerCase()));
}

export function inspectTurnTranscript(transcriptPath, lastUserInput = '') {
  const steps = readTailSteps(transcriptPath);
  if (!steps) return { available: false, hasCard: false, hasWork: false, plannerCount: 0 };
  const needle = typeof lastUserInput === 'string' ? lastUserInput.trim() : '';
  let lastIdx = -1;
  let matchIdx = -1;
  for (let i = steps.length - 1; i >= 0; i--) {
    if (!isStepType(steps[i], 'USER_INPUT')) continue;
    if (lastIdx === -1) lastIdx = i;
    if (needle && stepText(steps[i]).trim() === needle) { matchIdx = i; break; }
  }
  const startIdx = matchIdx >= 0 ? matchIdx : lastIdx;
  const planners = (startIdx >= 0 ? steps.slice(startIdx + 1) : steps).filter((s) => isStepType(s, 'PLANNER_RESPONSE'));
  const combined = planners.map(stepText).join('\n');
  const hasCard = CARD_MARKERS.every((m) => combined.includes(m));
  return { available: true, hasCard, hasWork: planners.length >= 2 || planners.some(hasWorkTool), plannerCount: planners.length };
}

function readIncidentCount() {
  const filePath = process.env.ANTIGRAVITY_INCIDENTS_PATH || DEFAULT_INCIDENTS;
  try {
    if (!fs.existsSync(filePath)) return 0;
    const parsed = tryParseJson(fs.readFileSync(filePath, 'utf8'));
    return Array.isArray(parsed) ? parsed.length : 0;
  } catch (err) {
    console.error(`Quad-loop incident read warning: ${err.message}`);
    return 0;
  }
}

function parseContext(payload = {}) {
  const convId = typeof payload?.conversationId === 'string' && payload.conversationId ? payload.conversationId : 'default';
  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  return { convId, userInput, transcript: inspectTurnTranscript(payload?.transcriptPath, userInput), telem: getTurnTelemetryState({ conversationId: convId, lastUserInput: userInput }) };
}

export function buildTelemetryReminder({ chainCalls = 0, incidentsCount = 0, stopRetries = 0, subagentDenies = 0 } = {}) {
  return `Mandatory: Print '### 🔄 Quad-Loop Execution Telemetry' ([Loop 1 Human Gate], [Loop 2 Selection & Restraint], [Loop 3 Swarm Execution], [Loop 4 Learning & Memory]) before invoke_subagent or concluding. Live: chainCalls=${chainCalls}, incidents=${incidentsCount}, stopRetries=${stopRetries}, subagentDenies=${subagentDenies}.`;
}

export function buildFallbackMarkdownCard({ chainCalls = 0, incidentsCount = 0, stopRetries = 0, subagentDenies = 0 } = {}) {
  return `### 🔄 Quad-Loop Execution Telemetry\n- **[Loop 1 Human Gate]:** Stage completed (hook fallback rendered after Stop retry)\n- **[Loop 2 Selection & Restraint]:** Ponytail 7-Rung active | chain calls: ${chainCalls}\n- **[Loop 3 Swarm Execution]:** Subagent gate denies: ${subagentDenies} | Stop retries: ${stopRetries}\n- **[Loop 4 Learning & Memory]:** Harness² incidents: ${incidentsCount}`;
}

export function evaluatePreInvocation(payload = {}) {
  const { convId, userInput, transcript, telem } = parseContext(payload);
  if (transcript.hasCard) return {};
  const chainCalls = readChainState().conversations?.[convId]?.consecutiveCalls ?? 0;
  const ctx = { chainCalls, incidentsCount: readIncidentCount(), stopRetries: telem.stopTelemetryRetries, subagentDenies: telem.subagentGateDenies };
  const reminder = buildTelemetryReminder(ctx);
  if (telem.stopTelemetryRetries >= 1 && !telem.fallbackRendered) {
    markFallbackRendered({ conversationId: convId, lastUserInput: userInput });
    return { injectSteps: [{ ephemeralMessage: reminder }, { systemMessage: { systemMessage: '', metadata: { user_markdown: buildFallbackMarkdownCard(ctx) } } }] };
  }
  return { injectSteps: [{ ephemeralMessage: reminder }] };
}

export function evaluatePreSubagent(payload = {}) {
  const { convId, userInput, transcript, telem } = parseContext(payload);
  if (transcript.available && !transcript.hasCard && telem.subagentGateDenies < 2) {
    incrementTurnTelemetryCounter({ conversationId: convId, lastUserInput: userInput, field: 'subagentGateDenies' });
    return { allowed: false, decision: 'deny', reason: SUBAGENT_DENY_REASON };
  }
  return { allowed: true, decision: 'allow' };
}

export function evaluateStop(payload = {}) {
  const { convId, userInput, transcript, telem } = parseContext(payload);
  if (payload?.terminationReason === 'NO_TOOL_CALL' && transcript.available && transcript.hasWork && !transcript.hasCard && telem.stopTelemetryRetries < 1) {
    incrementTurnTelemetryCounter({ conversationId: convId, lastUserInput: userInput, field: 'stopTelemetryRetries' });
    return { decision: 'continue', reason: STOP_CONTINUE_REASON };
  }
  resetChainState({ conversationId: convId, lastUserInput: userInput, resetTurn: true });
  return {};
}

async function main() {
  const idx = process.argv.indexOf('--event');
  const event = idx >= 0 ? process.argv[idx + 1] : '';
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  const payload = tryParseJson(Buffer.concat(chunks).toString('utf8').trim() || '{}') || {};
  if (event === 'pre-invocation') { process.stdout.write(JSON.stringify(evaluatePreInvocation(payload))); return 0; }
  if (event === 'stop') { process.stdout.write(JSON.stringify(evaluateStop(payload))); return 0; }
  if (event === 'pre-subagent') {
    const res = evaluatePreSubagent(payload);
    process.stdout.write(JSON.stringify({ decision: res.decision, ...(res.reason ? { reason: res.reason } : {}) }));
    if (!res.allowed) { console.error(res.reason); return 2; }
  } else { process.stdout.write('{}'); }
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = await main();

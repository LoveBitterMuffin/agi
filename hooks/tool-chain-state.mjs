import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

export function getChainStatePath() {
  if (process.env.ANTIGRAVITY_CHAIN_STATE_PATH) return process.env.ANTIGRAVITY_CHAIN_STATE_PATH;
  const base = process.env.USERPROFILE || process.env.HOME || '';
  return path.join(base, '.gemini', 'antigravity', 'scratch', 'lead_tool_chain.json');
}

export function resolveMaxChainCalls() {
  const raw = process.env.ANTIGRAVITY_MAX_CHAIN_CALLS;
  if (!raw || raw.trim().toLowerCase() === 'unlimited') return Infinity;
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : Infinity;
}

export function readChainState(filePath = getChainStatePath()) {
  try {
    if (!fs.existsSync(filePath)) return { consecutiveCalls: 0, unlimited: true, conversations: {} };
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const conversations = parsed && typeof parsed.conversations === 'object' && parsed.conversations !== null ? parsed.conversations : {};
    return {
      consecutiveCalls: typeof parsed?.consecutiveCalls === 'number' ? parsed.consecutiveCalls : 0,
      unlimited: true,
      conversations
    };
  } catch (err) {
    console.error(`Antigravity hook state read warning: ${err.message}`);
    return { consecutiveCalls: 0, unlimited: true, conversations: {} };
  }
}

export function writeChainState(state, filePath = getChainStatePath()) {
  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const maxCalls = resolveMaxChainCalls();
    const payload = {
      consecutiveCalls: state.consecutiveCalls ?? 0,
      limit: Number.isFinite(maxCalls) ? maxCalls : null,
      unlimited: !Number.isFinite(maxCalls),
      updatedAt: new Date().toISOString(),
      conversations: state.conversations ?? {}
    };
    fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf8');
  } catch (err) {
    console.error(`Antigravity hook state write warning: ${err.message}`);
  }
}

function resolveTelemetry(entry = {}, userInput = '', forceReset = false) {
  const prevInput = entry.telemetryUserInput || entry.lastUserInput || '';
  const changed = Boolean(userInput && prevInput && prevInput !== userInput);
  if (forceReset || changed) {
    return { telemetryUserInput: userInput || '', stopTelemetryRetries: 0, subagentGateDenies: 0, fallbackRendered: false };
  }
  return {
    telemetryUserInput: userInput || prevInput,
    stopTelemetryRetries: Number.isFinite(entry.stopTelemetryRetries) ? entry.stopTelemetryRetries : 0,
    subagentGateDenies: Number.isFinite(entry.subagentGateDenies) ? entry.subagentGateDenies : 0,
    fallbackRendered: Boolean(entry.fallbackRendered)
  };
}

function setConvEntry(state, convId, count, userInput, telem) {
  const prev = state.conversations[convId] || {};
  state.conversations[convId] = {
    consecutiveCalls: count,
    lastUserInput: userInput || prev.lastUserInput || '',
    ...telem,
    updatedAt: new Date().toISOString()
  };
}

export function resetChainState({ conversationId = '', lastUserInput = '', resetTurn = false, filePath = getChainStatePath() } = {}) {
  const state = readChainState(filePath);
  if (conversationId) {
    const prev = state.conversations[conversationId] || {};
    setConvEntry(state, conversationId, 0, lastUserInput, resolveTelemetry(prev, lastUserInput, resetTurn));
  } else {
    state.conversations = {};
  }
  state.consecutiveCalls = 0;
  writeChainState(state, filePath);
  return state;
}

export function recordToolCall({ toolName = '', payload = {}, filePath = getChainStatePath() } = {}) {
  const state = readChainState(filePath);
  const convId = typeof payload?.conversationId === 'string' && payload.conversationId ? payload.conversationId : 'default';
  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  const prev = state.conversations[convId] || { consecutiveCalls: 0, lastUserInput: userInput };
  const isNewRequest = Boolean(userInput && prev.lastUserInput && prev.lastUserInput !== userInput);
  const nextCount = (toolName === 'invoke_subagent' || isNewRequest) ? 0 : prev.consecutiveCalls + 1;
  setConvEntry(state, convId, nextCount, userInput, resolveTelemetry(prev, userInput, isNewRequest));
  state.consecutiveCalls = nextCount;
  writeChainState(state, filePath);

  const maxCalls = resolveMaxChainCalls();
  if (Number.isFinite(maxCalls) && nextCount > maxCalls && toolName !== 'invoke_subagent') {
    return { allowed: false, exitCode: 2, count: nextCount, message: `VIOLATION (Rule 04 / Rule 05): Lead tool-chaining bound reached (${maxCalls} consecutive calls).` };
  }
  return { allowed: true, count: nextCount };
}

function updateTelemetry(convId, userInput, filePath, mutateFn) {
  const state = readChainState(filePath);
  const id = convId || 'default';
  const prev = state.conversations[id] || {};
  const nextTelem = mutateFn(resolveTelemetry(prev, userInput, false));
  setConvEntry(state, id, prev.consecutiveCalls ?? 0, userInput, nextTelem);
  writeChainState(state, filePath);
  return nextTelem;
}

export function getTurnTelemetryState({ conversationId = 'default', lastUserInput = '', filePath = getChainStatePath() } = {}) {
  const state = readChainState(filePath);
  return resolveTelemetry(state.conversations[conversationId || 'default'] || {}, lastUserInput, false);
}

export function incrementTurnTelemetryCounter({ conversationId = 'default', lastUserInput = '', field, filePath = getChainStatePath() } = {}) {
  return updateTelemetry(conversationId, lastUserInput, filePath, (t) => ({ ...t, [field]: (t[field] || 0) + 1 }));
}

export function markFallbackRendered({ conversationId = 'default', lastUserInput = '', filePath = getChainStatePath() } = {}) {
  return updateTelemetry(conversationId, lastUserInput, filePath, (t) => ({ ...t, fallbackRendered: true }));
}

export function resetTurnTelemetry({ conversationId = '', lastUserInput = '', filePath = getChainStatePath() } = {}) {
  if (conversationId) return updateTelemetry(conversationId, lastUserInput, filePath, () => resolveTelemetry({}, lastUserInput, true));
  const state = readChainState(filePath);
  for (const id of Object.keys(state.conversations)) {
    state.conversations[id] = { ...state.conversations[id], ...resolveTelemetry({}, '', true), updatedAt: new Date().toISOString() };
  }
  writeChainState(state, filePath);
  return resolveTelemetry({}, '', true);
}

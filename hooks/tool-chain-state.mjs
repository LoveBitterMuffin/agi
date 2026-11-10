import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { tryParseJson, withStateLock, writeJsonAtomic } from './fs-atomic.mjs';

const SUBAGENT_PROMPT_RE = /###\s*1\.\s*Role\s*&\s*Objective[\s\S]*###\s*2\.\s*Resource\s*Boundaries/i;
const SESSION_DEFAULTS = { memoryInitialized: false, memoryBriefInjected: false, memoryRead: false, gate0Passed: false, specDrafted: false, specApproved: false, hasCodeMutation: false, memoryAudited: false };
const TURN_DEFAULTS = { telemetryUserInput: '', lastTurnAnchor: '', stopTelemetryRetries: 0, stopGate3Retries: 0, subagentGateDenies: 0, subagentCardGateDenies: 0, memoryReadGateDenies: 0, gate0Denies: 0, gate1Denies: 0, lastDeniedPlannerOffset: null, fallbackRendered: false };

export function getChainStatePath() {
  if (process.env.ANTIGRAVITY_CHAIN_STATE_PATH) return process.env.ANTIGRAVITY_CHAIN_STATE_PATH;
  return path.join(process.env.USERPROFILE || process.env.HOME || '', '.gemini', 'antigravity', 'scratch', 'lead_tool_chain.json');
}

export function resolveMaxChainCalls() {
  const raw = process.env.ANTIGRAVITY_MAX_CHAIN_CALLS;
  if (!raw || raw.trim() === '') return 5;
  if (raw.trim().toLowerCase() === 'unlimited') return Infinity;
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 5;
}

export function readChainState(filePath = getChainStatePath()) {
  const maxCalls = resolveMaxChainCalls();
  const isUnlimited = !Number.isFinite(maxCalls);
  const empty = { unlimited: isUnlimited, conversations: {}, subagentConversations: {} };
  if (!fs.existsSync(filePath)) return empty;
  const parsed = tryParseJson(fs.readFileSync(filePath, 'utf8'), null, (e) => console.error(`State read warning: ${e.message}`));
  if (!parsed || typeof parsed !== 'object') return empty;
  return {
    unlimited: typeof parsed.unlimited === 'boolean' ? parsed.unlimited : isUnlimited,
    conversations: parsed.conversations && typeof parsed.conversations === 'object' ? parsed.conversations : {},
    subagentConversations: parsed.subagentConversations && typeof parsed.subagentConversations === 'object' ? parsed.subagentConversations : {}
  };
}

export function writeChainState(state, filePath = getChainStatePath()) {
  const maxCalls = resolveMaxChainCalls();
  writeJsonAtomic(filePath, {
    limit: Number.isFinite(maxCalls) ? maxCalls : null, unlimited: !Number.isFinite(maxCalls),
    updatedAt: new Date().toISOString(), subagentConversations: state.subagentConversations ?? {}, conversations: state.conversations ?? {}
  });
}

function isTurnChanged(entry, userInput, turnAnchor) {
  const prevAnchor = entry.lastTurnAnchor || '';
  if (turnAnchor && prevAnchor) return turnAnchor !== prevAnchor;
  const prevInput = entry.telemetryUserInput || entry.lastUserInput || '';
  return Boolean(userInput && prevInput && prevInput !== userInput);
}

function buildConvEntry(prev = {}, { count, userInput = '', turnAnchor = '', resetTurn = false, resetSession = false, sessionPatch = {} } = {}) {
  const changed = isTurnChanged(prev, userInput, turnAnchor);
  const baseSession = resetSession ? { ...SESSION_DEFAULTS } : { ...SESSION_DEFAULTS, ...prev };
  const turn = (resetTurn || changed)
    ? { ...TURN_DEFAULTS, telemetryUserInput: userInput, lastTurnAnchor: turnAnchor }
    : { ...TURN_DEFAULTS, ...prev, telemetryUserInput: userInput || prev.telemetryUserInput || prev.lastUserInput || '', lastTurnAnchor: turnAnchor || prev.lastTurnAnchor || '' };
  const merged = { ...baseSession, ...turn, ...sessionPatch };
  const denies = Math.max(merged.subagentGateDenies || 0, merged.subagentCardGateDenies || 0);
  return {
    ...merged, subagentGateDenies: denies, subagentCardGateDenies: denies,
    consecutiveCalls: count ?? (changed || resetTurn ? 0 : (prev.consecutiveCalls || 0)),
    lastUserInput: userInput || prev.lastUserInput || '', updatedAt: new Date().toISOString()
  };
}

export function isKnownSubagent(payload = {}, state = null) {
  if (payload?.isSubagent === true || payload?.parentConversationId || payload?.parent_conversation_id || payload?.invokedBy) return true;
  if (payload?.subagentType || payload?.subagent_type || payload?.agentType) return true;
  const convId = typeof payload?.conversationId === 'string' ? payload.conversationId : '';
  const active = state || readChainState();
  if (convId && active?.subagentConversations?.[convId]) return true;
  return typeof payload?.lastUserInput === 'string' && SUBAGENT_PROMPT_RE.test(payload.lastUserInput);
}

export function registerSubagent(convId, meta = {}, filePath = getChainStatePath()) {
  if (!convId || typeof convId !== 'string') return;
  withStateLock(filePath, () => {
    const state = readChainState(filePath);
    state.subagentConversations[convId] = { ...meta, registeredAt: new Date().toISOString() };
    writeChainState(state, filePath);
  });
}

export function updateConversationState(convId = 'default', patch = {}, filePath = getChainStatePath()) {
  const id = convId || 'default';
  return withStateLock(filePath, () => {
    const state = readChainState(filePath);
    const prev = state.conversations[id] || {};
    state.conversations[id] = buildConvEntry(prev, { sessionPatch: typeof patch === 'function' ? patch(buildConvEntry(prev, {})) : patch });
    writeChainState(state, filePath);
    return state.conversations[id];
  });
}

export function resetChainState({ conversationId = '', lastUserInput = '', turnAnchor = '', resetTurn = false, resetSession = false, sessionPatch = {}, filePath = getChainStatePath() } = {}) {
  return withStateLock(filePath, () => {
    const state = readChainState(filePath);
    const id = conversationId || 'default';
    state.conversations[id] = buildConvEntry(state.conversations[id], { count: 0, userInput: lastUserInput, turnAnchor, resetTurn, resetSession, sessionPatch });
    writeChainState(state, filePath);
    return state;
  });
}

export function recordToolCall({ toolName = '', payload = {}, turnAnchor = '', filePath = getChainStatePath() } = {}) {
  const convId = typeof payload?.conversationId === 'string' && payload.conversationId ? payload.conversationId : 'default';
  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  return withStateLock(filePath, () => {
    const state = readChainState(filePath);
    const prev = state.conversations[convId] || {};
    const changed = isTurnChanged(prev, userInput, turnAnchor);
    const bare = String(toolName).replace(/^default_api:/i, '');
    const nextCount = (bare === 'invoke_subagent' || changed) ? 0 : (prev.consecutiveCalls || 0) + 1;
    state.conversations[convId] = buildConvEntry(prev, { count: nextCount, userInput, turnAnchor });
    writeChainState(state, filePath);
    const maxCalls = resolveMaxChainCalls();
    if (Number.isFinite(maxCalls) && nextCount > maxCalls && bare !== 'invoke_subagent') {
      return { allowed: false, exitCode: 2, count: nextCount, message: `VIOLATION (Rule 04 / Rule 05): Lead tool-chaining bound reached (${maxCalls} consecutive calls).` };
    }
    return { allowed: true, count: nextCount };
  });
}

export function getTurnTelemetryState({ conversationId = 'default', lastUserInput = '', turnAnchor = '', filePath = getChainStatePath() } = {}) {
  return buildConvEntry(readChainState(filePath).conversations[conversationId || 'default'], { userInput: lastUserInput, turnAnchor });
}

export function incrementTurnTelemetryCounter({ conversationId = 'default', lastUserInput = '', turnAnchor = '', field, filePath = getChainStatePath() } = {}) {
  const id = conversationId || 'default';
  return withStateLock(filePath, () => {
    const state = readChainState(filePath);
    const entry = buildConvEntry(state.conversations[id], { userInput: lastUserInput, turnAnchor });
    const nextVal = (entry[field] || 0) + 1;
    const syncSub = field === 'subagentGateDenies' || field === 'subagentCardGateDenies';
    const patch = syncSub ? { subagentGateDenies: nextVal, subagentCardGateDenies: nextVal } : { [field]: nextVal };
    state.conversations[id] = buildConvEntry(entry, { userInput: lastUserInput, turnAnchor, sessionPatch: patch });
    writeChainState(state, filePath);
    return state.conversations[id];
  });
}

export function markFallbackRendered({ conversationId = 'default', lastUserInput = '', turnAnchor = '', filePath = getChainStatePath() } = {}) {
  return updateConversationState(conversationId, { fallbackRendered: true, telemetryUserInput: lastUserInput, lastTurnAnchor: turnAnchor }, filePath);
}

export function resetTurnTelemetry({ conversationId = '', lastUserInput = '', filePath = getChainStatePath() } = {}) {
  return resetChainState({ conversationId: conversationId || 'default', lastUserInput, resetTurn: true, filePath });
}

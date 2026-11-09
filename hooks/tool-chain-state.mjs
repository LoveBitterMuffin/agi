import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

export function getChainStatePath() {
  if (process.env.ANTIGRAVITY_CHAIN_STATE_PATH) {
    return process.env.ANTIGRAVITY_CHAIN_STATE_PATH;
  }
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
    if (!fs.existsSync(filePath)) {
      return { consecutiveCalls: 0, unlimited: true, conversations: {} };
    }
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const conversations = parsed && typeof parsed.conversations === 'object' && parsed.conversations !== null
      ? parsed.conversations
      : {};
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
    const payload = {
      consecutiveCalls: state.consecutiveCalls ?? 0,
      limit: Number.isFinite(resolveMaxChainCalls()) ? resolveMaxChainCalls() : null,
      unlimited: !Number.isFinite(resolveMaxChainCalls()),
      updatedAt: new Date().toISOString(),
      conversations: state.conversations ?? {}
    };
    fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf8');
  } catch (err) {
    console.error(`Antigravity hook state write warning: ${err.message}`);
  }
}

export function resetChainState({ conversationId = '', lastUserInput = '', filePath = getChainStatePath() } = {}) {
  const state = readChainState(filePath);
  const now = new Date().toISOString();
  if (conversationId) {
    state.conversations[conversationId] = {
      consecutiveCalls: 0,
      lastUserInput,
      updatedAt: now
    };
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

  state.conversations[convId] = {
    consecutiveCalls: nextCount,
    lastUserInput: userInput || prev.lastUserInput || '',
    updatedAt: new Date().toISOString()
  };
  state.consecutiveCalls = nextCount;
  writeChainState(state, filePath);

  const maxCalls = resolveMaxChainCalls();
  if (Number.isFinite(maxCalls) && nextCount > maxCalls && toolName !== 'invoke_subagent') {
    return {
      allowed: false,
      exitCode: 2,
      count: nextCount,
      message: `VIOLATION (Rule 04 / Rule 05): Lead tool-chaining bound reached (${maxCalls} consecutive calls).`
    };
  }
  return { allowed: true, count: nextCount };
}

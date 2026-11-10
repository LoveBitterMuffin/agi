#!/usr/bin/env node

import process from 'node:process';
import { isMainModule, readStdinText, tryParseJson } from './fs-atomic.mjs';
import { readChainState, resetChainState } from './tool-chain-state.mjs';
import { inspectTurnTranscript } from './quad-loop-guard.mjs';

function getResetDecision(payload, turnAnchor) {
  const convId = typeof payload?.conversationId === 'string' ? payload.conversationId : '';
  if ('terminationReason' in payload) return { shouldReset: Boolean(convId), resetTurn: false };
  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  const entry = convId ? readChainState().conversations?.[convId] : null;
  const prevAnchor = entry?.lastTurnAnchor || '';
  const prevInput = entry?.telemetryUserInput || entry?.lastUserInput || '';
  const anchorChanged = Boolean(turnAnchor && prevAnchor && turnAnchor !== prevAnchor);
  const textChanged = Boolean(userInput && prevInput && prevInput !== userInput);
  const inputChanged = anchorChanged || textChanged;

  if (payload?.invocationNum === 0) {
    return { shouldReset: true, resetTurn: inputChanged || (entry?.stopTelemetryRetries ?? 0) === 0 };
  }
  if (!convId || !userInput) return { shouldReset: false, resetTurn: false };
  if (!entry || inputChanged) return { shouldReset: true, resetTurn: inputChanged };
  return { shouldReset: false, resetTurn: false };
}

async function main() {
  let payload = {};
  try {
    const raw = await readStdinText();
    if (raw && raw.trim()) payload = tryParseJson(raw, {}, (e) => console.error(`Reset hook warning: ${e.message}`));
  } catch (err) {
    console.error(`Antigravity reset hook warning: ${err.message}`);
  }

  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  const transcript = payload?.transcriptPath ? inspectTurnTranscript(payload.transcriptPath, userInput) : null;
  const turnAnchor = transcript?.turnAnchor || '';
  const { shouldReset, resetTurn } = getResetDecision(payload, turnAnchor);

  if (shouldReset) {
    const convId = typeof payload?.conversationId === 'string' && payload.conversationId ? payload.conversationId : 'default';
    resetChainState({ conversationId: convId, lastUserInput: userInput, turnAnchor, resetTurn });
  }

  process.stdout.write('{}');
  return 0;
}

if (isMainModule(import.meta.url)) {
  process.exitCode = await main();
}

#!/usr/bin/env node

import process from 'node:process';
import { readChainState, resetChainState } from './tool-chain-state.mjs';

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', () => resolve(''));
  });
}

function getResetDecision(payload) {
  if ('terminationReason' in payload) return { shouldReset: true, resetTurn: false };
  const convId = typeof payload?.conversationId === 'string' ? payload.conversationId : '';
  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  const entry = convId ? readChainState().conversations?.[convId] : null;
  const prevInput = entry?.telemetryUserInput || entry?.lastUserInput || '';
  const inputChanged = Boolean(userInput && prevInput && prevInput !== userInput);
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
    const raw = await readStdin();
    if (raw && raw.trim()) payload = JSON.parse(raw);
  } catch (err) {
    console.error(`Antigravity reset hook warning: ${err.message}`);
  }

  const { shouldReset, resetTurn } = getResetDecision(payload);
  if (shouldReset) {
    const convId = typeof payload?.conversationId === 'string' ? payload.conversationId : '';
    const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
    resetChainState({ conversationId: convId, lastUserInput: userInput, resetTurn });
  }

  process.stdout.write('{}');
  return 0;
}

process.exitCode = await main();

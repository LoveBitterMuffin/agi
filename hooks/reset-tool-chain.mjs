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

function shouldReset(payload) {
  if ('terminationReason' in payload) return true;
  if (payload?.invocationNum === 0) return true;
  const convId = typeof payload?.conversationId === 'string' ? payload.conversationId : '';
  const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
  if (!convId || !userInput) return false;
  const entry = readChainState().conversations?.[convId];
  return !entry || entry.lastUserInput !== userInput;
}

async function main() {
  let payload = {};
  try {
    const raw = await readStdin();
    if (raw && raw.trim()) payload = JSON.parse(raw);
  } catch (err) {
    console.error(`Antigravity reset hook warning: ${err.message}`);
  }

  if (shouldReset(payload)) {
    const convId = typeof payload?.conversationId === 'string' ? payload.conversationId : '';
    const userInput = typeof payload?.lastUserInput === 'string' ? payload.lastUserInput : '';
    resetChainState({ conversationId: convId, lastUserInput: userInput });
  }

  process.stdout.write('{}');
  return 0;
}

process.exitCode = await main();

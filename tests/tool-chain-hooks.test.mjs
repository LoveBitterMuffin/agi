import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import {
  extractCommand,
  extractToolName,
  evaluateCommand,
  handleToolChainBound
} from '../hooks/validate-tool-call.mjs';
import {
  readChainState,
  recordToolCall,
  resetChainState
} from '../hooks/tool-chain-state.mjs';

function makeTempStatePath() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-chain-'));
  return path.join(dir, 'lead_tool_chain.json');
}

test('extractToolName and extractCommand support Antigravity camelCase toolCall payloads', () => {
  const payload = {
    conversationId: 'conv-1',
    toolCall: { name: 'run_command', args: { CommandLine: 'npm test' } }
  };
  assert.equal(extractToolName(payload), 'run_command');
  assert.equal(extractCommand(payload), 'npm test');
  assert.equal(extractToolName({ toolCall: { name: 'invoke_subagent', args: {} } }), 'invoke_subagent');
});

test('unlimited consecutive calls are allowed and isolated per conversation', () => {
  const filePath = makeTempStatePath();
  for (let i = 1; i <= 12; i++) {
    const res = recordToolCall({
      toolName: 'run_command',
      payload: { conversationId: 'conv-a', lastUserInput: 'prompt 1' },
      filePath
    });
    assert.equal(res.allowed, true);
    assert.equal(res.count, i);
  }
  const other = recordToolCall({
    toolName: 'run_command',
    payload: { conversationId: 'conv-b', lastUserInput: 'prompt 1' },
    filePath
  });
  assert.equal(other.allowed, true);
  assert.equal(other.count, 1);
  assert.equal(readChainState(filePath).conversations['conv-a'].consecutiveCalls, 12);
});

test('counter resets automatically on new lastUserInput, invoke_subagent, and resetChainState', () => {
  const filePath = makeTempStatePath();
  recordToolCall({ toolName: 'run_command', payload: { conversationId: 'c1', lastUserInput: 'req A' }, filePath });
  recordToolCall({ toolName: 'run_command', payload: { conversationId: 'c1', lastUserInput: 'req A' }, filePath });

  const afterNewPrompt = recordToolCall({
    toolName: 'run_command',
    payload: { conversationId: 'c1', lastUserInput: 'req B' },
    filePath
  });
  assert.equal(afterNewPrompt.count, 0);

  recordToolCall({ toolName: 'run_command', payload: { conversationId: 'c1', lastUserInput: 'req B' }, filePath });
  const afterSubagent = recordToolCall({
    toolName: 'invoke_subagent',
    payload: { conversationId: 'c1', lastUserInput: 'req B' },
    filePath
  });
  assert.equal(afterSubagent.count, 0);

  recordToolCall({ toolName: 'run_command', payload: { conversationId: 'c1', lastUserInput: 'req B' }, filePath });
  resetChainState({ conversationId: 'c1', lastUserInput: 'req B', filePath });
  assert.equal(readChainState(filePath).conversations['c1'].consecutiveCalls, 0);
  assert.equal(typeof handleToolChainBound, 'function');
});

test('destructive command block rules remain enforced', () => {
  assert.equal(evaluateCommand('rm -rf /').allowed, false);
  assert.equal(evaluateCommand('format C:').allowed, false);
  assert.equal(evaluateCommand('npx vitest run tests/').allowed, true);
});

test('reset-tool-chain.mjs CLI resets state on PreInvocation and Stop payloads', () => {
  const hookDir = path.resolve(import.meta.dirname, '..');
  const scriptPath = path.join(hookDir, 'hooks', 'reset-tool-chain.mjs');
  const filePath = makeTempStatePath();
  recordToolCall({ toolName: 'run_command', payload: { conversationId: 'cli-conv', lastUserInput: 'q1' }, filePath });
  const out = execFileSync(process.execPath, [scriptPath], {
    input: JSON.stringify({ conversationId: 'cli-conv', terminationReason: 'NO_TOOL_CALL' }),
    env: { ...process.env, ANTIGRAVITY_CHAIN_STATE_PATH: filePath },
    encoding: 'utf8'
  });
  assert.equal(out, '{}');
  assert.equal(readChainState(filePath).conversations['cli-conv'].consecutiveCalls, 0);
});

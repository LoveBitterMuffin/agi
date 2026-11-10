import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { evaluatePreInvocation, evaluateStop, inspectTurnTranscript } from '../hooks/quad-loop-guard.mjs';
import { getTurnTelemetryState, incrementTurnTelemetryCounter, readChainState, recordToolCall } from '../hooks/tool-chain-state.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');
const CARD = '### 🔄 Quad-Loop Execution Telemetry\n- **[Loop 1 Human Gate]:** ok\n- **[Loop 2 Selection & Restraint]:** ok\n- **[Loop 3 Swarm Execution]:** ok\n- **[Loop 4 Learning & Memory]:** ok';

function makeEnv(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'agi-quad-'));
  if (t?.after) t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const statePath = path.join(dir, 'chain.json');
  const incidentsPath = path.join(dir, 'incidents.json');
  const transcriptPath = path.join(dir, 'transcript.jsonl');
  fs.writeFileSync(incidentsPath, JSON.stringify([{ command: 'test' }, { command: 'lint' }]), 'utf8');
  return { dir, statePath, incidentsPath, transcriptPath };
}

function withEnv(env, fn) {
  const prevState = process.env.ANTIGRAVITY_CHAIN_STATE_PATH;
  const prevInc = process.env.ANTIGRAVITY_INCIDENTS_PATH;
  process.env.ANTIGRAVITY_CHAIN_STATE_PATH = env.statePath;
  process.env.ANTIGRAVITY_INCIDENTS_PATH = env.incidentsPath;
  try { return fn(); } finally {
    if (prevState === undefined) delete process.env.ANTIGRAVITY_CHAIN_STATE_PATH; else process.env.ANTIGRAVITY_CHAIN_STATE_PATH = prevState;
    if (prevInc === undefined) delete process.env.ANTIGRAVITY_INCIDENTS_PATH; else process.env.ANTIGRAVITY_INCIDENTS_PATH = prevInc;
  }
}

function writeSteps(filePath, steps) {
  fs.writeFileSync(filePath, steps.map((s) => JSON.stringify(s)).join('\n') + '\n', 'utf8');
}

function runHook(relPath, payload, env, args = []) {
  return spawnSync(process.execPath, [path.join(ROOT, relPath), ...args], {
    input: JSON.stringify(payload),
    env: { ...process.env, ANTIGRAVITY_CHAIN_STATE_PATH: env.statePath, ANTIGRAVITY_INCIDENTS_PATH: env.incidentsPath, ANTIGRAVITY_WORKSPACE: env.dir },
    encoding: 'utf8'
  });
}

test('AC-01: SessionStart emits official injectSteps contract for AGI v1.5.0', (t) => {
  const env = makeEnv(t);
  const out = execFileSync(process.execPath, [path.join(ROOT, 'hooks', 'session-start.mjs')], {
    env: { ...process.env, ANTIGRAVITY_CHAIN_STATE_PATH: env.statePath, ANTIGRAVITY_WORKSPACE: env.dir },
    encoding: 'utf8'
  });
  const parsed = JSON.parse(out);
  const msg = parsed?.injectSteps?.[0]?.systemMessage?.systemMessage || '';
  assert.match(msg, /AGI v1\.5\.0 active/);
  assert.match(msg, /Quad-Loop Execution Telemetry/);
});

test('AC-01: inspectTurnTranscript fails open and slices 256KB tail by latest USER_INPUT', (t) => {
  const env = makeEnv(t);
  assert.equal(inspectTurnTranscript(path.join(env.dir, 'missing.jsonl'), 'x').available, false);
  fs.writeFileSync(env.transcriptPath, 'not-json\n', 'utf8');
  assert.equal(inspectTurnTranscript(env.transcriptPath, 'x').available, false);

  const filler = JSON.stringify({ type: 'PLANNER_RESPONSE', content: `${CARD} ${'a'.repeat(4096)}` });
  const oldLines = [JSON.stringify({ type: 'USER_INPUT', content: 'old' }), ...Array(70).fill(filler)];
  const newLines = [JSON.stringify({ type: 'USER_INPUT', content: 'curr' }), JSON.stringify({ type: 'PLANNER_RESPONSE', content: 'working', tool_calls: [{ name: 'edit_file' }] })];
  fs.writeFileSync(env.transcriptPath, [...oldLines, ...newLines].join('\n') + '\n', 'utf8');
  const res = inspectTurnTranscript(env.transcriptPath, 'curr');
  assert.deepEqual({ available: res.available, hasCard: res.hasCard, hasWork: res.hasWork }, { available: true, hasCard: false, hasWork: true });
});

test('AC-01: evaluatePreInvocation injects live metrics and single-shot user_markdown fallback', (t) => {
  const env = makeEnv(t);
  writeSteps(env.transcriptPath, [{ type: 'USER_INPUT', content: 'go' }]);
  withEnv(env, () => {
    recordToolCall({ toolName: 'run_command', payload: { conversationId: 'c1', lastUserInput: 'go' }, filePath: env.statePath });
    const first = evaluatePreInvocation({ conversationId: 'c1', lastUserInput: 'go', transcriptPath: env.transcriptPath });
    assert.match(first.injectSteps[0].ephemeralMessage, /chainCalls=1, incidents=2/);
    assert.equal(first.injectSteps.length, 1);

    incrementTurnTelemetryCounter({ conversationId: 'c1', lastUserInput: 'go', field: 'stopTelemetryRetries', filePath: env.statePath });
    const retry = evaluatePreInvocation({ conversationId: 'c1', lastUserInput: 'go', transcriptPath: env.transcriptPath });
    assert.match(retry.injectSteps[1].systemMessage.metadata.user_markdown, /### 🔄 Quad-Loop Execution Telemetry/);
    assert.equal(retry.injectSteps[1].systemMessage.systemMessage, '');

    const third = evaluatePreInvocation({ conversationId: 'c1', lastUserInput: 'go', transcriptPath: env.transcriptPath });
    assert.equal(third.injectSteps.length, 1);

    writeSteps(env.transcriptPath, [{ type: 'USER_INPUT', content: 'go' }, { type: 'PLANNER_RESPONSE', content: CARD }]);
    assert.deepEqual(evaluatePreInvocation({ conversationId: 'c1', lastUserInput: 'go', transcriptPath: env.transcriptPath }), {});
  });
});

test('AC-02: validate-tool-call denies invoke_subagent twice without card then allows, and allows when card exists', (t) => {
  const env = makeEnv(t);
  writeSteps(env.transcriptPath, [{ type: 'USER_INPUT', content: 'task' }]);
  const base = { conversationId: 'c2', lastUserInput: 'task', transcriptPath: env.transcriptPath, toolCall: { name: 'invoke_subagent', args: {} } };
  for (let i = 0; i < 2; i++) {
    const deny = runHook('hooks/validate-tool-call.mjs', base, env);
    assert.equal(deny.status, 2);
    assert.equal(JSON.parse(deny.stdout).decision, 'deny');
  }
  const failOpen = runHook('hooks/validate-tool-call.mjs', base, env);
  assert.equal(failOpen.status, 0);
  assert.equal(JSON.parse(failOpen.stdout).decision, 'allow');

  writeSteps(env.transcriptPath, [{ type: 'USER_INPUT', content: 'task2' }, { type: 'PLANNER_RESPONSE', content: CARD }]);
  const withCard = runHook('hooks/validate-tool-call.mjs', { ...base, lastUserInput: 'task2' }, env);
  assert.equal(withCard.status, 0);
  assert.equal(JSON.parse(withCard.stdout).decision, 'allow');

  const noTranscript = runHook('hooks/validate-tool-call.mjs', { conversationId: 'c2', toolCall: { name: 'invoke_subagent', args: {} } }, env);
  assert.equal(noTranscript.status, 0);
  assert.equal(noTranscript.stdout, '');
});

test('AC-03: Stop enforces once on work without card, preserves counters across PreInvocation, and resets at terminal Stop', (t) => {
  const env = makeEnv(t);
  writeSteps(env.transcriptPath, [{ type: 'USER_INPUT', content: 'qa' }, { type: 'PLANNER_RESPONSE', content: '42' }]);
  withEnv(env, () => {
    assert.deepEqual(evaluateStop({ conversationId: 'c3', lastUserInput: 'qa', terminationReason: 'NO_TOOL_CALL', transcriptPath: env.transcriptPath }), {});
  });

  writeSteps(env.transcriptPath, [{ type: 'USER_INPUT', content: 'work' }, { type: 'PLANNER_RESPONSE', content: 'done', tool_calls: [{ name: 'write_file' }] }]);
  withEnv(env, () => {
    incrementTurnTelemetryCounter({ conversationId: 'c3', lastUserInput: 'work', field: 'subagentGateDenies', filePath: env.statePath });
    const blocked = evaluateStop({ conversationId: 'c3', lastUserInput: 'work', terminationReason: 'NO_TOOL_CALL', transcriptPath: env.transcriptPath });
    assert.equal(blocked.decision, 'continue');
  });

  const resetPre = runHook('hooks/reset-tool-chain.mjs', { conversationId: 'c3', lastUserInput: 'work', invocationNum: 0 }, env);
  assert.equal(resetPre.stdout, '{}');
  const afterPre = getTurnTelemetryState({ conversationId: 'c3', lastUserInput: 'work', filePath: env.statePath });
  assert.equal(afterPre.stopTelemetryRetries, 1);
  assert.equal(afterPre.subagentGateDenies, 1);

  const secondStop = runHook('hooks/quad-loop-guard.mjs', { conversationId: 'c3', lastUserInput: 'work', terminationReason: 'NO_TOOL_CALL', transcriptPath: env.transcriptPath }, env, ['--event', 'stop']);
  assert.equal(secondStop.stdout, '{}');
  assert.equal(getTurnTelemetryState({ conversationId: 'c3', lastUserInput: 'work', filePath: env.statePath }).stopTelemetryRetries, 0);
  assert.equal(readChainState(env.statePath).conversations['c3'].consecutiveCalls, 0);
});

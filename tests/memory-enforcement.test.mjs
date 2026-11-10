import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  ensureCarpatiMemory,
  buildL0Brief,
  isMemoryPath,
  isScratchPath,
  isMemoryScriptCmd,
  scanTranscriptLifecycle
} from '../hooks/memory-bootstrap.mjs';
import { evaluateMemoryAndLifecycleGate } from '../hooks/gate-lifecycle.mjs';

function makeTempWorkspace() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'agy-mem-test-'));
}

test('ensureCarpatiMemory bootstraps full 2-layer structure without overwriting existing files', () => {
  const ws = makeTempWorkspace();
  const initRes = ensureCarpatiMemory(ws);
  assert.equal(initRes.initialized, true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'logs', 'ActiveSprintLog.md')), true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'logs', 'CHANGELOG.md')), true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'Index.md')), true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'MOC.md')), true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'wiki', 'chapters', '000_overview.md')), true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'wiki', 'chapters', '099_learnings.md')), true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'raw', 'inbox', '.gitkeep')), true);
  assert.equal(fs.existsSync(path.join(ws, 'memory', 'raw', 'vault', '.gitkeep')), true);

  const customText = '# Custom Sprint Log';
  fs.writeFileSync(path.join(ws, 'memory', 'logs', 'ActiveSprintLog.md'), customText, 'utf8');

  const secondRes = ensureCarpatiMemory(ws);
  assert.equal(secondRes.initialized, false);
  assert.equal(fs.readFileSync(path.join(ws, 'memory', 'logs', 'ActiveSprintLog.md'), 'utf8'), customText);
});

test('buildL0Brief produces clamped context under 35 lines with key headers', () => {
  const ws = makeTempWorkspace();
  ensureCarpatiMemory(ws);
  const brief = buildL0Brief(ws);
  const lines = brief.split('\n');
  assert.ok(lines.length <= 35, `L0 brief too long: ${lines.length} lines`);
  assert.ok(brief.includes('# L0 Carpati Memory Brief'));
  assert.ok(brief.includes('## ActiveSprintLog'));
  assert.ok(brief.includes('## Chapters'));
});

test('path and script classification helpers identify memory, scratch, and commands correctly', () => {
  assert.equal(isMemoryPath('c:/repo/memory/logs/ActiveSprintLog.md'), true);
  assert.equal(isMemoryPath('memory\\Index.md'), true);
  assert.equal(isMemoryPath('src/memory-utils.js'), false);

  assert.equal(isScratchPath('scratch/output.log'), true);
  assert.equal(isScratchPath('c:/user/appData/brain/conv-1/SPEC.md'), true);
  assert.equal(isScratchPath('src/components/Card.tsx'), false);

  assert.equal(isMemoryScriptCmd('.agents/scripts/get-memory-brief.ps1 -Query "init"'), true);
  assert.equal(isMemoryScriptCmd('powershell ./audit-memory.ps1'), true);
  assert.equal(isMemoryScriptCmd('npm test'), false);
});

test('evaluateMemoryAndLifecycleGate enforces Carpati Memory Gate before code mutations', () => {
  const ws = makeTempWorkspace();
  const convId = 'conv-mem-gate';
  const baseCtx = {
    convId,
    userInput: 'build a feature',
    workspace: ws,
    convEntry: {
      memoryInitialized: false,
      memoryBriefInjected: false,
      memoryRead: false,
      gate0Passed: false,
      memoryReadGateDenies: 0
    },
    transcript: { hasMemoryRead: false, hasAskQuestion: false },
    isSubagent: false
  };

  const codePayload = { toolCall: { name: 'write_file', args: { Path: path.join(ws, 'src', 'app.js'), Content: 'console.log(1);' } } };
  const memPayload = { toolCall: { name: 'write_file', args: { Path: path.join(ws, 'memory', 'logs', 'ActiveSprintLog.md'), Content: '# Log' } } };

  // Memory path is always allowed
  const memRes = evaluateMemoryAndLifecycleGate('write_file', memPayload, baseCtx);
  assert.equal(memRes.allowed, true);

  // Code path is denied if memory has not been read
  const codeRes1 = evaluateMemoryAndLifecycleGate('write_file', codePayload, baseCtx);
  assert.equal(codeRes1.allowed, false);
  assert.equal(codeRes1.decision, 'deny');
  assert.ok(codeRes1.reason.includes('Carpati Memory Gate'));

  // Once memory is read, memory gate passes (proceeds to Gate 0)
  const ctxWithMem = { ...baseCtx, convEntry: { ...baseCtx.convEntry, memoryRead: true } };
  const codeRes2 = evaluateMemoryAndLifecycleGate('write_file', codePayload, ctxWithMem);
  assert.equal(codeRes2.allowed, false);
  assert.ok(codeRes2.reason.includes('Gate 0 Required'));
});

import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {
  validateAskQuestion,
  evaluateMemoryAndLifecycleGate,
  isSpecArtifactPath,
  isCodeMutationPath
} from '../hooks/gate-lifecycle.mjs';

test('validateAskQuestion strictly checks options count, prefix, and anti-patterns', () => {
  assert.equal(validateAskQuestion({}).allowed, false);
  assert.equal(validateAskQuestion({ toolCall: { args: { questions: [] } } }).allowed, false);

  const selectAll = validateAskQuestion({
    toolCall: { args: { questions: [{ question: 'Select all that apply for stack', options: ['(Recommended) A', 'B'] }] } }
  });
  assert.equal(selectAll.allowed, false);
  assert.ok(selectAll.reason.includes('select all that apply'));

  const missingRec = validateAskQuestion({
    toolCall: { args: { questions: [{ question: 'Stack?', options: ['Option A', 'Option B'] }] } }
  });
  assert.equal(missingRec.allowed, false);
  assert.ok(missingRec.reason.includes('(Recommended)'));

  const otherOpt = validateAskQuestion({
    toolCall: { args: { questions: [{ question: 'Stack?', options: ['(Recommended) A', 'Other'] }] } }
  });
  assert.equal(otherOpt.allowed, false);
  assert.ok(otherOpt.reason.includes('omit "Other"'));

  const numberedOpt = validateAskQuestion({
    toolCall: { args: { questions: [{ question: 'Stack?', options: ['(Recommended) 1. A', '2. B'] }] } }
  });
  assert.equal(numberedOpt.allowed, false);
  assert.ok(numberedOpt.reason.includes('manual option numbering'));

  const valid = validateAskQuestion({
    toolCall: { args: { questions: [{ question: 'Stack?', options: ['(Recommended) PostgreSQL', 'SQLite', 'MongoDB'] }] } }
  });
  assert.equal(valid.allowed, true);
});

test('evaluateMemoryAndLifecycleGate handles Gate 0, Gate 1 SPEC, and subagent isolation', () => {
  const ws = 'c:/repo';
  const baseCtx = {
    convId: 'c-gate',
    userInput: 'implement login',
    workspace: ws,
    convEntry: {
      memoryRead: true,
      gate0Passed: false,
      specApproved: false,
      gate0Denies: 0,
      gate1Denies: 0
    },
    transcript: { hasMemoryRead: true, hasAskQuestion: false },
    isSubagent: false
  };

  const codePayload = { toolCall: { name: 'write_file', args: { Path: 'c:/repo/src/auth.js', Content: 'export function login() {}' } } };

  // Gate 0 blocks code mutation
  const g0Res = evaluateMemoryAndLifecycleGate('write_file', codePayload, baseCtx);
  assert.equal(g0Res.allowed, false);
  assert.ok(g0Res.reason.includes('Gate 0 Required'));

  // Gate 0 exempts 1-line typo fix
  const typoPayload = {
    toolCall: { name: 'edit_file', args: { Path: 'c:/repo/src/auth.js', Target: 'const x = 1;', Replacement: 'const x = 2;' } }
  };
  const typoRes = evaluateMemoryAndLifecycleGate('edit_file', typoPayload, baseCtx);
  assert.equal(typoRes.allowed, true);

  // Read-only subagents allowed after Gate 0 or with research role
  const scoutPayload = { toolCall: { name: 'invoke_subagent', args: { TypeName: 'research', Role: 'Code Scout' } } };
  const scoutCtx = { ...baseCtx, convEntry: { ...baseCtx.convEntry, gate0Passed: true } };
  const scoutRes = evaluateMemoryAndLifecycleGate('invoke_subagent', scoutPayload, scoutCtx);
  assert.equal(scoutRes.allowed, true);

  // Gate 1: SPEC-*.md write must include RequestFeedback=true and AC matrix
  const badSpecPayload = {
    toolCall: { name: 'write_file', args: { Path: 'c:/repo/SPEC-2026-001.md', Content: '# Spec without matrix' } }
  };
  const badSpecRes = evaluateMemoryAndLifecycleGate('write_file', badSpecPayload, scoutCtx);
  assert.equal(badSpecRes.allowed, false);
  assert.ok(badSpecRes.reason.includes('Gate 1 SPEC Violation'));

  const goodSpecPayload = {
    toolCall: {
      name: 'write_file',
      args: {
        Path: 'c:/repo/SPEC-2026-001.md',
        ArtifactMetadata: { RequestFeedback: true, Summary: 'Spec', UserFacing: true },
        Content: '# Spec\n| AC-01 | Matrix | Test |'
      }
    }
  };
  const goodSpecRes = evaluateMemoryAndLifecycleGate('write_file', goodSpecPayload, scoutCtx);
  assert.equal(goodSpecRes.allowed, true);

  // Active subagents (isSubagent: true) are isolated from Lead gates
  const subagentCtx = { ...baseCtx, isSubagent: true };
  const subagentCodeRes = evaluateMemoryAndLifecycleGate('write_file', codePayload, subagentCtx);
  assert.equal(subagentCodeRes.allowed, true);

  // Micro-Modularity law denies >150 lines for new source code
  const approvedCtx = { ...scoutCtx, convEntry: { ...scoutCtx.convEntry, specApproved: true } };
  const bigCodePayload = {
    toolCall: { name: 'write_file', args: { Path: 'c:/repo/src/huge.js', Content: '// line\n'.repeat(160) } }
  };
  const bigRes = evaluateMemoryAndLifecycleGate('write_file', bigCodePayload, approvedCtx);
  assert.equal(bigRes.allowed, false);
  assert.ok(bigRes.reason.includes('Micro-Modularity Law Violation'));

  // Anti-slop rule denies synthetic telemetry / fake audit badges
  const slopPayload = {
    toolCall: { name: 'write_file', args: { Path: 'c:/repo/src/badge.js', Content: 'const status = "APCA AAA PASS";' } }
  };
  const slopRes = evaluateMemoryAndLifecycleGate('write_file', slopPayload, approvedCtx);
  assert.equal(slopRes.allowed, false);
  assert.ok(slopRes.reason.includes('Anti-Slop Violation'));
});

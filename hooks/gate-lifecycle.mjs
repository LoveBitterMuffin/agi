import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { isProjectRoot } from './fs-atomic.mjs';
import { isMemoryPath, isScratchPath } from './memory-bootstrap.mjs';
import { incrementTurnTelemetryCounter, updateConversationState } from './tool-chain-state.mjs';

const CODE_EXT_RE = /\.(?:mjs|js|cjs|ts|tsx|jsx|py|ps1|vue|go|rs|java|cs|cpp|c|h|css|html|json|yaml|yml)$/i;
const CODE_DIR_RE = /(?:^|\/)(?:src|scripts|tests|hooks|harness|handwriting_system|app|lib)(?:\/|$)/i;
const READONLY_ROLE_RE = /\b(?:scout|auditor|explorer|research|audit|reviewer|code-reviewer|test-runner)\b/i;
const APPROVAL_RE = /(?:(?<!\p{L})|\b)(?:proceed|approved?|confirm|yes|go ahead|ok|да|подтверждаю|утверждаю|продолжай)(?:(?!\p{L})|\b)/iu;
export const NEGATION_RE = /(?:(?<!\p{L})|\b)(?:(?<!больше\s+)не(?!\s+беспокой)|нет|отмена|стоп|отклонить|отклонено|отказываюсь|don'?t|not|wait|stop|reject)(?:(?!\p{L})|\b)/iu;

export function getToolArgs(payload = {}) {
  return payload?.toolCall?.args ?? payload?.tool_args ?? payload?.toolArgs ?? payload?.arguments ?? {};
}

export function extractFileTarget(payload = {}) {
  const args = getToolArgs(payload);
  for (const v of [args.Path, args.TargetFile, args.path, args.filePath, args.file_path, args.targetFile]) {
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return '';
}

export const isSpecArtifactPath = (fp) => Boolean(fp && typeof fp === 'string' && /(?:^|[\\/])SPEC-[A-Za-z0-9_-]+\.md$/i.test(fp.trim()));

export function isCodeMutationPath(filePath) {
  if (!filePath || typeof filePath !== 'string' || isMemoryPath(filePath) || isScratchPath(filePath) || isSpecArtifactPath(filePath)) return false;
  return CODE_DIR_RE.test(filePath.replace(/\\/g, '/')) || CODE_EXT_RE.test(filePath);
}

function isSingleLineTypoEdit(toolName, payload) {
  if (toolName !== 'edit_file') return false;
  const args = getToolArgs(payload), target = args.Target ?? args.target, rep = args.Replacement ?? args.replacement;
  if (typeof target !== 'string' || typeof rep !== 'string') return false;
  return target.length > 0 && target.length <= 120 && rep.length <= 120 && !target.includes('\n') && !rep.includes('\n');
}

export function isReadOnlySubagent(payload) {
  const args = getToolArgs(payload), typeName = String(args.TypeName ?? args.typeName ?? '').trim().toLowerCase();
  if (typeName === 'research') return true;
  if (typeName === 'self') return false;
  return READONLY_ROLE_RE.test(String(args.Role ?? args.role ?? '').trim());
}

function validateSingleQuestion(q, idx) {
  if (/select\s+all\s+that\s+apply/i.test(String(q?.question || ''))) return `ask_question[${idx}]: remove "select all that apply".`;
  const opts = q?.options;
  if (!Array.isArray(opts) || opts.length < 2 || opts.length > 4) return `ask_question[${idx}]: provide 2-4 options.`;
  if (!String(opts[0] || '').trim().startsWith('(Recommended)')) return `ask_question[${idx}]: options[0] must start with "(Recommended)".`;
  for (const raw of opts) {
    const opt = String(raw || '').trim();
    if (/^(?:\(?other\)?|другое)$/i.test(opt)) return `ask_question[${idx}]: omit "Other" option.`;
    if (/^\d+[.)]\s+/.test(opt)) return `ask_question[${idx}]: omit manual option numbering ("1. ").`;
  }
  return null;
}

export function validateAskQuestion(payload = {}) {
  const questions = getToolArgs(payload)?.questions;
  if (!Array.isArray(questions) || questions.length === 0) return { allowed: false, decision: 'deny', reason: 'ask_question requires a non-empty questions array.' };
  for (let i = 0; i < questions.length; i++) {
    const err = validateSingleQuestion(questions[i], i);
    if (err) return { allowed: false, decision: 'deny', reason: err };
  }
  return { allowed: true };
}

function shouldEnforceLifecycle(tool, payload, convEntry, workspace) {
  if (tool !== 'invoke_subagent' || process.env.ANTIGRAVITY_ENFORCE_GATES === '1') return true;
  if (fs.existsSync(path.join(workspace, 'memory')) || isProjectRoot(workspace)) return true;
  if (convEntry.memoryInitialized || convEntry.memoryBriefInjected || convEntry.memoryRead || convEntry.gate0Passed || convEntry.specDrafted) return true;
  const args = getToolArgs(payload);
  return Boolean(args.TypeName || args.typeName || args.Role || args.role || args.Prompt || args.prompt);
}

export function denyWithCap(convId, userInput, turnAnchor, convEntry, field, reason) {
  const currentCount = convEntry?.[field] || 0;
  incrementTurnTelemetryCounter({ conversationId: convId, lastUserInput: userInput, turnAnchor, field });
  const cappedReason = currentCount >= 2 ? `${reason} (Retry limit reached: bypassing gates is prohibited; human approval required).` : reason;
  return { allowed: false, decision: 'deny', reason: cappedReason };
}

export const SLOP_PATTERNS = [
  /APCA\s+(?:AAA|AA)\s+PASS/i,
  /STATUS\s*\/\/\s*NODE-PULSE/i,
  /v\d+\.\d+\.\d+\s*\/\/\s*SPEC/i,
  /HEX-AERO-DS\s*\/\/\s*v/i,
  /CARD\s*\/\/\s*CHAMFER/i
];

function checkCodeQuality(payload, target) {
  const args = getToolArgs(payload), content = String(args.Content ?? args.content ?? '');
  const lines = content.split(/\r?\n/);
  if (lines.length > 150 && !target.endsWith('.json') && !target.endsWith('AGENTS.md')) {
    return { allowed: false, decision: 'deny', reason: 'Micro-Modularity Law Violation (Rule 04): New source file exceeds 150 lines ceiling.' };
  }
  for (const pat of SLOP_PATTERNS) {
    if (pat.test(content)) return { allowed: false, decision: 'deny', reason: 'Anti-Slop Violation (Rule R-41): Synthetic telemetry or fake audit badge detected in code.' };
  }
  return { allowed: true };
}

function checkSpecWrite(payload) {
  const args = getToolArgs(payload), meta = args.ArtifactMetadata ?? args.artifactMetadata ?? {};
  const content = String(args.Content ?? args.content ?? '');
  if (!(meta.RequestFeedback === true || meta.requestFeedback === true) || !/\bAC-\d+/i.test(content)) {
    return { allowed: false, decision: 'deny', reason: 'Gate 1 SPEC Violation: SPEC-*.md must set ArtifactMetadata.RequestFeedback=true and include an AC-01 matrix.' };
  }
  return { allowed: true };
}

function evaluateLeadGates(tool, payload, target, ctx) {
  const { convId, userInput, convEntry, transcript } = ctx;
  const turnAnchor = transcript?.turnAnchor || '';
  if (!convEntry.gate0Passed && !transcript?.hasAskQuestion) {
    return denyWithCap(convId, userInput, turnAnchor, convEntry, 'gate0Denies', 'Gate 0 Required: Call ask_question with 2-4 options ((Recommended) first) to align with the user.');
  }
  if (tool === 'write_file' && isSpecArtifactPath(target)) return checkSpecWrite(payload);
  if (tool === 'write_file' && isCodeMutationPath(target)) {
    const quality = checkCodeQuality(payload, target);
    if (!quality.allowed) return quality;
  }
  const inputStr = typeof userInput === 'string' ? userInput : '';
  const hasNegation = NEGATION_RE.test(inputStr);
  const isApprovalInput = !hasNegation && APPROVAL_RE.test(inputStr);
  const userApproved = !hasNegation && Boolean(convEntry.specApproved || transcript?.hasSpecApproval || (convEntry.specDrafted && isApprovalInput));
  if (userApproved && !convEntry.specApproved) updateConversationState(convId, { specApproved: true });
  const needsApproval = (tool === 'invoke_subagent' && !isReadOnlySubagent(payload)) || (tool !== 'invoke_subagent' && isCodeMutationPath(target));
  if (needsApproval && !userApproved) {
    return denyWithCap(convId, userInput, turnAnchor, convEntry, 'gate1Denies', 'Gate 1 Required: Draft SPEC-YYYY-NNN (RequestFeedback=true) and obtain user approval before code/mutating subagents.');
  }
  return { allowed: true };
}

export function evaluateMemoryAndLifecycleGate(toolName, payload, ctx) {
  const tool = String(toolName || '').replace(/^default_api:/i, '').toLowerCase();
  if (tool === 'ask_question') return validateAskQuestion(payload);
  if (tool !== 'write_file' && tool !== 'edit_file' && tool !== 'invoke_subagent') return { allowed: true };
  if (!shouldEnforceLifecycle(tool, payload, ctx.convEntry, ctx.workspace)) return { allowed: true };
  const target = extractFileTarget(payload);
  if (tool !== 'invoke_subagent' && (isMemoryPath(target) || isScratchPath(target))) return { allowed: true };
  if (!ctx.convEntry.memoryRead && !ctx.convEntry.memoryBriefInjected && !ctx.transcript?.hasMemoryRead) {
    return denyWithCap(ctx.convId, ctx.userInput, ctx.transcript?.turnAnchor || '', ctx.convEntry, 'memoryReadGateDenies', 'Carpati Memory Gate: Read memory/logs/ActiveSprintLog.md & memory/Index.md before modifying files or invoking subagents.');
  }
  if (ctx.isSubagent || isSingleLineTypoEdit(tool, payload)) return { allowed: true };
  return evaluateLeadGates(tool, payload, target, ctx);
}

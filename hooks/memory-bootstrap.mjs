import fs from 'node:fs';
import path from 'node:path';

const APPROVAL_RE = /\b(?:proceed|approved?|confirm|yes|go ahead|ok|да|подтверждаю|утверждаю|продолжай)\b/i;

const SPRINT_TMPL = [
  '# Active Sprint Log', '', '## Current Sprint',
  '- **Status:** Active', '- **Goal:** Project Development & Architecture Alignment',
  '- **Active Tasks:**', '  - [x] Initial Scaffolding & Verification', '  - [ ] Memory-Guided Feature Development', '',
  '## Recent Decisions', '- Adopted Antigravity Two-Layer Memory & Docs-as-Code pipeline.',
  '- Established strict micro-modularity and Gate 0 user alignment.'
].join('\n');

const INDEX_TMPL = [
  '# AntiGravity Memory Index', '',
  '| ID | Chapter | Status | Version |', '| :--- | :--- | :--- | :--- |',
  '| CH-000 | [000_overview.md](wiki/chapters/000_overview.md) - High-level system overview | active | 1.0.0 |',
  '| CH-099 | [099_learnings.md](wiki/chapters/099_learnings.md) - Learnings & pitfalls | active | 1.0.0 |'
].join('\n');

const MOC_TMPL = [
  '# Memory Map of Content (MOC)', '', '- [Memory Index](Index.md)',
  '- [Active Sprint Log](logs/ActiveSprintLog.md)',
  '- [000 System Overview](wiki/chapters/000_overview.md)',
  '- [099 Learnings](wiki/chapters/099_learnings.md)'
].join('\n');

const OVERVIEW_TMPL = [
  '---', 'chapter_id: CH-000', 'version: 1.0.0', 'status: active', '---',
  '# 000: System Overview', '', '## System Identity & Core Contracts',
  'Primary workspace architecture, runtime invariants, and tech stack boundaries.'
].join('\n');

const LEARNINGS_TMPL = [
  '---', 'chapter_id: CH-099', 'version: 1.0.0', 'status: active', '---',
  '# 099: System Learnings & Known Pitfalls', '', '## Architectural Invariants',
  '1. Do not accumulate tool calls in main thread; delegate >=2 file tasks to subagents.',
  '2. Always execute Gate 0 ask_question before drafting specifications or coding.', '',
  '## 4. Template for Logging New Learnings', '```markdown',
  '### [LRN-YYYY-NNN] <Short Descriptive Title>',
  '- **Date / Trigger:** YYYY-MM-DD / <Command, Test, or Spec Context>',
  '- **Root Cause:** <Technical mechanism of the failure with file/line refs>',
  '- **Anti-Pattern:** <What failed and must be avoided>',
  '- **Deterministic Invariant:** <Concrete, verifiable rule preventing recurrence>', '```'
].join('\n');

function writeIfMissing(filePath, content, created) {
  if (fs.existsSync(filePath)) return;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
  created.push(filePath);
}

export function ensureCarpatiMemory(workspace) {
  const mem = path.join(workspace, 'memory');
  for (const d of [mem, path.join(mem, 'logs'), path.join(mem, 'wiki', 'chapters'), path.join(mem, 'raw', 'inbox'), path.join(mem, 'raw', 'vault')]) {
    if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
  }
  const changelog = `# Changelog\n\n## [0.1.0] - ${new Date().toISOString().slice(0, 10)}\n### Added\n- Initial Carpati two-layer memory scaffold.\n`;
  const created = [];
  writeIfMissing(path.join(mem, 'raw', 'inbox', '.gitkeep'), '', created);
  writeIfMissing(path.join(mem, 'raw', 'vault', '.gitkeep'), '', created);
  writeIfMissing(path.join(mem, 'logs', 'ActiveSprintLog.md'), SPRINT_TMPL, created);
  writeIfMissing(path.join(mem, 'logs', 'CHANGELOG.md'), changelog, created);
  writeIfMissing(path.join(mem, 'MOC.md'), MOC_TMPL, created);
  writeIfMissing(path.join(mem, 'Index.md'), INDEX_TMPL, created);
  writeIfMissing(path.join(mem, 'wiki', 'chapters', '000_overview.md'), OVERVIEW_TMPL, created);
  writeIfMissing(path.join(mem, 'wiki', 'chapters', '099_learnings.md'), LEARNINGS_TMPL, created);
  return { initialized: created.length > 0, created, memoryDir: mem };
}

function readLines(filePath) {
  return fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf8').split(/\r?\n/).filter((l) => l.trim().length > 0) : [];
}

export function buildL0Brief(workspace) {
  const mem = path.join(workspace, 'memory');
  if (!fs.existsSync(mem)) return '';
  const sprint = readLines(path.join(mem, 'logs', 'ActiveSprintLog.md')).slice(0, 12);
  const index = readLines(path.join(mem, 'Index.md')).filter((l) => l.includes('wiki/chapters/')).slice(0, 8);
  const learn = readLines(path.join(mem, 'wiki', 'chapters', '099_learnings.md')).filter((l) => /^(\d+\.\s+|###\s+\[?LRN-|-\s+\*\*Deterministic Invariant)/.test(l.trim())).slice(0, 8);
  const out = ['# L0 Carpati Memory Brief'];
  if (sprint.length) out.push('## ActiveSprintLog', ...sprint);
  if (index.length) out.push('## Chapters', ...index);
  if (learn.length) out.push('## Key Invariants & Learnings', ...learn);
  return out.slice(0, 34).join('\n');
}

export const isMemoryPath = (p) => Boolean(p && typeof p === 'string' && /(?:^|\/)memory(?:\/|$)/.test(p.replace(/\\/g, '/').toLowerCase()));
export const isScratchPath = (p) => Boolean(p && typeof p === 'string' && /(?:^|\/)(?:scratch|brain)(?:\/|$)/.test(p.replace(/\\/g, '/').toLowerCase()));
export const isMemoryScriptCmd = (c) => Boolean(c && typeof c === 'string' && /(?:get-memory-brief|audit-memory|record-learning|sync-spec|wiki-brief)/i.test(c));

export function scanTranscriptLifecycle(rows, helpers) {
  let hasMemoryRead = false, hasAskQuestion = false, sawSpec = false, hasSpecApproval = false;
  for (const { step } of rows) {
    for (const tc of helpers.stepCalls(step)) {
      const name = helpers.callName(tc), args = helpers.callArgs(tc);
      const target = String(args.Path ?? args.TargetFile ?? args.path ?? args.filePath ?? '').replace(/\\/g, '/').toLowerCase();
      const cmd = String(args.CommandLine ?? args.commandLine ?? args.command ?? '');
      if ((name === 'read_file' && isMemoryPath(target)) || (name === 'run_command' && /get-memory-brief/i.test(cmd))) hasMemoryRead = true;
      if (name === 'ask_question') hasAskQuestion = true;
      if (name === 'write_file' && /(?:^|\/)spec-[^/]+\.md$/i.test(target)) sawSpec = true;
    }
    if (sawSpec && helpers.isStepType(step, 'USER_INPUT') && APPROVAL_RE.test(helpers.stepText(step))) hasSpecApproval = true;
  }
  return { hasMemoryRead, hasAskQuestion, hasSpecApproval };
}

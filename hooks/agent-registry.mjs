#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { isMainModule, resolveWorkspaceRoot } from './fs-atomic.mjs';

const PLUGIN_AGENTS_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'agents');
const RU_SYNONYMS = {
  бэкенд: ['backend', 'api', 'server'], сервер: ['backend', 'server', 'devops'], апи: ['api', 'backend'],
  фронтенд: ['frontend', 'ui', 'react'], верст: ['frontend', 'css', 'ui'], интерфейс: ['ui', 'ux', 'frontend'], дизайн: ['design', 'ui', 'ux'],
  тест: ['test', 'testing', 'qa'], автотест: ['qa', 'playwright', 'e2e'], рефактор: ['archaeologist', 'refactor'],
  безопас: ['security', 'audit', 'owasp'], уязвим: ['security', 'vulnerability'], аудит: ['security', 'audit'], пентест: ['penetration', 'pentest', 'security'],
  база: ['database', 'sql', 'schema'], базы: ['database', 'sql', 'schema'], базу: ['database', 'sql', 'schema'], бд: ['database', 'sql', 'schema'], миграц: ['migration', 'database'],
  депло: ['devops', 'deploy', 'ci'], докер: ['devops', 'docker'], пайплайн: ['devops', 'ci'],
  отлад: ['debug', 'debugger'], баг: ['bug', 'debug', 'debugger'], баги: ['bug', 'debug', 'debugger'], бага: ['bug', 'debug', 'debugger'], багов: ['bug', 'debug', 'debugger'],
  ошиб: ['debug', 'debugger', 'error'], почин: ['debug', 'debugger', 'fix'], исправ: ['debug', 'debugger', 'fix'],
  документ: ['documentation', 'docs'], производител: ['performance', 'optimize'], оптимиз: ['performance', 'optimize'],
  мобил: ['mobile', 'android', 'ios'], андроид: ['android', 'mobile'], игра: ['game', 'unity', 'threejs'], игры: ['game', 'unity', 'threejs'],
  поиск: ['explorer', 'research'], исслед: ['explorer', 'research'], развед: ['explorer', 'research'],
  план: ['plan', 'planner'], архитект: ['architect', 'architecture'], оркестр: ['orchestrator', 'coordinate'], сео: ['seo', 'geo']
};

export function resolveAgentsDir(args = process.argv.slice(2), workspace = resolveWorkspaceRoot({})) {
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--agents-dir' && args[i + 1]) return path.resolve(args[i + 1]);
    if (args[i].startsWith('--agents-dir=')) return path.resolve(args[i].slice(13));
  }
  if (process.env.ANTIGRAVITY_AGENTS_DIR) return path.resolve(process.env.ANTIGRAVITY_AGENTS_DIR);
  const wsAgents = path.join(workspace, '.agents', 'agents');
  if (fs.existsSync(wsAgents) && fs.readdirSync(wsAgents).some((f) => f.endsWith('.md'))) return wsAgents;
  return PLUGIN_AGENTS_DIR;
}

export function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};
  const meta = {};
  let listKey = '';
  for (const line of match[1].split(/\r?\n/)) {
    const item = line.match(/^\s+-\s+(.+)$/);
    if (item && listKey) { meta[listKey].push(item[1].trim().replace(/^["']|["']$/g, '')); continue; }
    listKey = '';
    const idx = line.indexOf(':');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const val = line.slice(idx + 1).trim();
    if (!val) { meta[key] = []; listKey = key; }
    else meta[key] = val.replace(/^["']|["']$/g, '');
  }
  return meta;
}

const tokenize = (text) => String(text || '').toLowerCase().match(/[\p{L}\p{N}_-]+/gu) || [];

function tokenMatches(needle, hayTokens, haySet) {
  if (haySet.has(needle)) return true;
  if (needle.length <= 3) return false;
  return hayTokens.some((ht) => ht.startsWith(needle) || (ht.length >= 4 && needle.startsWith(ht)));
}

function expandSynonyms(token) {
  const out = [token];
  for (const [key, syns] of Object.entries(RU_SYNONYMS)) {
    if (token === key || (key.length >= 4 && token.startsWith(key))) out.push(...syns);
  }
  return out;
}

export function scoreAgent(meta, queryTokens) {
  const skillsStr = Array.isArray(meta.skills) ? meta.skills.join(' ') : (meta.skills || '');
  const hayTokens = tokenize(`${meta.name || ''} ${meta.description || ''} ${skillsStr}`);
  const haySet = new Set(hayTokens);
  let matches = 0;
  for (const token of queryTokens) {
    if (expandSynonyms(token).some((c) => tokenMatches(c, hayTokens, haySet))) matches++;
  }
  return queryTokens.length > 0 ? matches / queryTokens.length : 0;
}

export function findAgents(query, agentsDir = resolveAgentsDir()) {
  if (!fs.existsSync(agentsDir)) throw new Error(`Agents directory not found: ${agentsDir}`);
  const queryTokens = tokenize(query);
  const results = [];
  for (const file of fs.readdirSync(agentsDir).filter((f) => f.endsWith('.md'))) {
    const meta = parseFrontmatter(fs.readFileSync(path.join(agentsDir, file), 'utf8'));
    const score = scoreAgent(meta, queryTokens);
    if (score > 0) {
      results.push({ name: meta.name || file.replace('.md', ''), score: Math.round(score * 100) / 100, description: meta.description || '', skills: meta.skills || [], file });
    }
  }
  results.sort((a, b) => b.score - a.score);
  const top = results[0];
  const isReuse = Boolean(top && top.score >= 0.6);
  return { query, agentsDir, count: results.length, decision: isReuse ? 'REUSE' : 'CREATE_OR_ESCALATE', status: isReuse ? 'REUSE_RECOMMENDED' : 'NO_SUITABLE_AGENT_FOUND', topMatch: top || null, matches: results.slice(0, 5) };
}

export function registerAgent(name, role, skills = [], agentsDir = resolveAgentsDir()) {
  if (!name || !/^[a-z0-9_-]+$/.test(name)) throw new Error(`Invalid name "${name}". Use kebab-case.`);
  if (!fs.existsSync(agentsDir)) fs.mkdirSync(agentsDir, { recursive: true });
  const targetPath = path.join(agentsDir, `${name}.md`);
  if (fs.existsSync(targetPath)) throw new Error(`Agent "${name}" already exists.`);
  const skillList = (skills.length ? skills : ['clean-code', 'ponytail', 'verify-changes']).map((s) => `  - ${s}`).join('\n');
  const template = `---\nname: ${name}\ndescription: ${role}\nversion: "1.0.0"\nmodel: "inherit"\ntools:\n  - run_command\n  - read_file\n  - write_file\n  - edit_file\n  - call_mcp_tool\nskills:\n${skillList}\n---\n\n# ${role}\n\nYou are ${role}, operating within the AGI framework (Ponytail 7-Rung restraint, <=150L files, <=30L functions).\n\n## Carpati Memory & Anti-Slop (R-41)\n- Read \`memory/logs/ActiveSprintLog.md\` and \`memory/Index.md\` first; never read >250L files in full.\n- Log resolved failures in \`memory/wiki/chapters/099_learnings.md\`.\n- Never fabricate facts, institutions, or synthetic telemetry badges; use \`[Плейсхолдер: ...]\` for missing data.\n`;
  fs.writeFileSync(targetPath, template, 'utf8');
  return { success: true, agent: name, path: targetPath };
}

function stripAgentsDirFlag(args) {
  const clean = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--agents-dir') { i++; continue; }
    if (args[i].startsWith('--agents-dir=')) continue;
    clean.push(args[i]);
  }
  return clean;
}

function main() {
  const rawArgs = process.argv.slice(2);
  const agentsDir = resolveAgentsDir(rawArgs);
  const args = stripAgentsDirFlag(rawArgs);
  const cmd = args[0];
  try {
    if (cmd === 'find') {
      const query = args.slice(1).join(' ').trim();
      if (!query) throw new Error('Usage: node agent-registry.mjs find <query>');
      console.log(JSON.stringify(findAgents(query, agentsDir), null, 2));
      return 0;
    }
    if (cmd === 'register') {
      if (!args[1] || !args[2]) throw new Error('Usage: node agent-registry.mjs register <name> <role> [skills...]');
      console.log(JSON.stringify(registerAgent(args[1], args[2], args.slice(3), agentsDir), null, 2));
      return 0;
    }
    throw new Error('Usage: node agent-registry.mjs <find|register> [args...]');
  } catch (err) {
    console.error(JSON.stringify({ error: err.message }));
    return 1;
  }
}

if (isMainModule(import.meta.url)) process.exit(main());

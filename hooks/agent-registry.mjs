#!/usr/bin/env node

/**
 * AGI - Agent Selection & Dynamic Registry (agent-registry.mjs)
 * Implements "Reuse before Create" matching and dynamic agent registration.
 */

import process from 'node:process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const AGENTS_DIR = path.resolve(__dirname, '..', 'agents');

function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};
  const meta = {};
  for (const line of match[1].split(/\r?\n/)) {
    const idx = line.indexOf(':');
    if (idx !== -1) {
      const key = line.slice(0, idx).trim();
      const val = line.slice(idx + 1).trim();
      meta[key] = val;
    }
  }
  return meta;
}

function scoreAgent(meta, queryTokens) {
  const haystack = `${meta.name || ''} ${meta.description || ''} ${meta.skills || ''}`.toLowerCase();
  let matches = 0;
  for (const token of queryTokens) {
    if (haystack.includes(token)) matches++;
  }
  return queryTokens.length > 0 ? matches / queryTokens.length : 0;
}

function findAgents(query) {
  if (!fs.existsSync(AGENTS_DIR)) {
    console.error(JSON.stringify({ error: `Agents directory not found: ${AGENTS_DIR}` }));
    process.exit(1);
  }
  const files = fs.readdirSync(AGENTS_DIR).filter(f => f.endsWith('.md'));
  const queryTokens = query.toLowerCase().split(/\s+/).filter(Boolean);
  const results = [];

  for (const file of files) {
    const fullPath = path.join(AGENTS_DIR, file);
    const content = fs.readFileSync(fullPath, 'utf8');
    const meta = parseFrontmatter(content);
    const score = scoreAgent(meta, queryTokens);
    if (score > 0) {
      results.push({
        name: meta.name || file.replace('.md', ''),
        score: Math.round(score * 100) / 100,
        description: meta.description || '',
        skills: meta.skills || '',
        file
      });
    }
  }

  results.sort((a, b) => b.score - a.score);
  const top = results[0];
  const isReuse = top && top.score >= 0.6;
  console.log(JSON.stringify({
    query,
    count: results.length,
    decision: isReuse ? 'REUSE' : 'CREATE_OR_ESCALATE',
    status: isReuse ? 'REUSE_RECOMMENDED' : 'NO_SUITABLE_AGENT_FOUND',
    topMatch: top || null,
    matches: results.slice(0, 5)
  }, null, 2));
}

function registerAgent(name, role, skills) {
  if (!name || !/^[a-z0-9_-]+$/.test(name)) {
    console.error(JSON.stringify({ error: `Invalid name "${name}". Use kebab-case.` }));
    process.exit(1);
  }
  const targetPath = path.join(AGENTS_DIR, `${name}.md`);
  if (fs.existsSync(targetPath)) {
    console.error(JSON.stringify({ error: `Agent "${name}" already exists.` }));
    process.exit(1);
  }
  const template = `---
name: ${name}
description: ${role}
tools:
  - run_command
  - read_file
  - write_file
  - edit_file
  - call_mcp_tool
---

# ${role}

You are ${role}, operating within the AGI framework.
Strictly adhere to the Ponytail Protocol (Full Senior restraint, 7-rung ladder) and Carpati 2-layer memory.
`;

  fs.writeFileSync(targetPath, template, 'utf8');
  console.log(JSON.stringify({ success: true, agent: name, path: targetPath }, null, 2));
}

function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];
  if (cmd === 'find') {
    const query = args.slice(1).join(' ').trim();
    if (!query) {
      console.error(JSON.stringify({ error: 'Usage: node agent-registry.mjs find <query>' }));
      process.exit(1);
    }
    findAgents(query);
  } else if (cmd === 'register') {
    const name = args[1];
    const role = args[2];
    const skills = args.slice(3);
    if (!name || !role) {
      console.error(JSON.stringify({ error: 'Usage: node agent-registry.mjs register <name> <role> [skills...]' }));
      process.exit(1);
    }
    registerAgent(name, role, skills);
  } else {
    console.error(JSON.stringify({ error: 'Usage: node agent-registry.mjs <find|register> [args...]' }));
    process.exit(1);
  }
}

main();

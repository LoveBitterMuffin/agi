import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ALLOWED_PLUGIN_KEYS = new Set([
  'name',
  'displayName',
  'version',
  'description',
  'logo',
  'author',
  'homepage',
  'repository',
  'suggestedPrompts',
  'disabled'
]);

function readJson(relPath) {
  const fullPath = path.join(ROOT, relPath);
  return JSON.parse(fs.readFileSync(fullPath, 'utf8'));
}

function collectHookCommands(node, out = []) {
  if (Array.isArray(node)) {
    for (const item of node) collectHookCommands(item, out);
    return out;
  }
  if (node && typeof node === 'object') {
    if (typeof node.command === 'string') out.push(node.command);
    for (const val of Object.values(node)) collectHookCommands(val, out);
  }
  return out;
}

function findPythonArtifacts(dir, found = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === '__pycache__') {
        found.push(path.relative(ROOT, fullPath));
      } else {
        findPythonArtifacts(fullPath, found);
      }
    } else if (entry.name.endsWith('.pyc')) {
      found.push(path.relative(ROOT, fullPath));
    }
  }
  return found;
}

test('plugin.json defines AGI branding, allowed keys, and valid SVG logo', () => {
  const manifest = readJson('plugin.json');
  assert.equal(manifest.name, 'agi');
  assert.equal(manifest.displayName, 'AGI');
  assert.equal(manifest.version, '1.5.0');
  assert.equal(manifest.logo, 'assets/logo.svg');
  assert.ok(typeof manifest.description === 'string' && manifest.description.length > 0);
  assert.ok(Array.isArray(manifest.suggestedPrompts) && manifest.suggestedPrompts.length === 3);

  for (const key of Object.keys(manifest)) {
    assert.ok(ALLOWED_PLUGIN_KEYS.has(key), `Unexpected plugin.json key: ${key}`);
  }

  const logoPath = path.join(ROOT, manifest.logo);
  assert.equal(fs.existsSync(logoPath), true, 'Missing logo asset');
  const svg = fs.readFileSync(logoPath, 'utf8');
  assert.match(svg, /viewBox="0 0 256 256"/);
});

test('hooks.json is valid JSON under "agi" and all referenced .mjs scripts exist', () => {
  const hooksConfig = readJson('hooks.json');
  assert.ok(hooksConfig.agi && typeof hooksConfig.agi === 'object');
  const commands = collectHookCommands(hooksConfig.agi);
  assert.ok(commands.length > 0, 'Expected at least one hook command');

  for (const cmd of commands) {
    const matches = cmd.match(/[^\s"']+\.mjs/g) || [];
    assert.ok(matches.length > 0, `No .mjs target found in command: ${cmd}`);
    for (const relTarget of matches) {
      const targetPath = path.resolve(ROOT, relTarget);
      assert.equal(fs.existsSync(targetPath), true, `Missing hook target: ${relTarget}`);
    }
  }
});

test('repository export contains no Python bytecode artifacts and has clean incident log', (t) => {
  if (!fs.existsSync(path.join(ROOT, '.git'))) {
    t.skip('export hygiene applies only to git repository checkouts');
    return;
  }

  const pyArtifacts = findPythonArtifacts(ROOT);
  assert.deepEqual(pyArtifacts, []);

  const incidentsRelPath = path.join('memory', 'harness_incidents.json');
  const incidents = fs.existsSync(path.join(ROOT, incidentsRelPath))
    ? readJson(incidentsRelPath)
    : [];
  assert.deepEqual(incidents, []);
});

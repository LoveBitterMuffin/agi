import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { writeTextAtomic, isProjectRoot } from '../hooks/fs-atomic.mjs';

const PLUGIN_ROOT = path.resolve(import.meta.dirname, '..');
const SYNC_SCRIPT = path.join(PLUGIN_ROOT, 'scripts', 'sync-workspace-core.mjs');

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'agy-sync-test-'));
}

test('writeTextAtomic writes safely and handles directory creation', () => {
  const dir = makeTempDir();
  const target = path.join(dir, 'nested', 'test.txt');
  writeTextAtomic(target, 'hello atomic');
  assert.equal(fs.readFileSync(target, 'utf8'), 'hello atomic');
});

test('sync-workspace-core preserves custom AGENTS.md and user-modified scripts without --force', () => {
  const targetDir = makeTempDir();
  const customAgentsContent = '# Custom Study AGENTS.md\nDo not overwrite!';
  fs.writeFileSync(path.join(targetDir, 'AGENTS.md'), customAgentsContent, 'utf8');

  // Initial sync
  const res1 = spawnSync(process.execPath, [SYNC_SCRIPT, '--target', targetDir], { encoding: 'utf8' });
  assert.equal(res1.status, 0, `Sync 1 failed: ${res1.stderr}`);

  // Custom AGENTS.md must NOT be overwritten
  assert.equal(fs.readFileSync(path.join(targetDir, 'AGENTS.md'), 'utf8'), customAgentsContent);

  // Manifest must be created
  const manifestPath = path.join(targetDir, '.agents', '.core-manifest.json');
  assert.equal(fs.existsSync(manifestPath), true);

  // User modifies a synchronized script
  const scriptToTweak = path.join(targetDir, '.agents', 'scripts', 'get-memory-brief.ps1');
  if (fs.existsSync(scriptToTweak)) {
    fs.writeFileSync(scriptToTweak, '# User local patch', 'utf8');

    // Second sync without --force: must preserve user's patch
    const res2 = spawnSync(process.execPath, [SYNC_SCRIPT, '--target', targetDir], { encoding: 'utf8' });
    assert.equal(res2.status, 0);
    assert.equal(fs.readFileSync(scriptToTweak, 'utf8'), '# User local patch');

    // Third sync with --force: overwrites with core version
    const res3 = spawnSync(process.execPath, [SYNC_SCRIPT, '--target', targetDir, '--force'], { encoding: 'utf8' });
    assert.equal(res3.status, 0);
    assert.notEqual(fs.readFileSync(scriptToTweak, 'utf8'), '# User local patch');
  }
});

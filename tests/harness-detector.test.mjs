import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const PLUGIN_ROOT = path.resolve(import.meta.dirname, '..');
const HARNESS_PATH = path.join(PLUGIN_ROOT, 'harness', 'run-harness.ps1');
const harnessSrc = fs.readFileSync(HARNESS_PATH, 'utf8');
const fnBlock = harnessSrc.slice(
  harnessSrc.indexOf('function Detect-SourceDir'),
  harnessSrc.indexOf('Push-Location $resolvedRoot')
);

function queryHarness(rootDir, isFast = false) {
  const runner = `
    ${fnBlock}
    $c = Detect-TestCommand -Root '${rootDir.replace(/'/g, "''")}' ${isFast ? '-IsFast' : ''}
    $s = Detect-SourceDir -Root '${rootDir.replace(/'/g, "''")}'
    @{ cmd = $c; src = $s } | ConvertTo-Json -Compress
  `;
  const res = spawnSync('powershell', ['-NoProfile', '-Command', runner], { encoding: 'utf8' });
  if (res.status !== 0) throw new Error(res.stderr || res.stdout);
  return JSON.parse(res.stdout.trim() || '{}');
}

test('run-harness.ps1 contains zero references to handwriting_system', () => {
  assert.equal(/handwriting_system/i.test(harnessSrc), false, 'run-harness.ps1 contains handwriting_system');
});

test('Detect-SourceDir discovers standard source folders', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-src-'));
  try {
    assert.equal(queryHarness(tmp).src, '');
    fs.mkdirSync(path.join(tmp, 'app'));
    assert.equal(queryHarness(tmp).src, 'app');
    fs.mkdirSync(path.join(tmp, 'src'));
    assert.equal(queryHarness(tmp).src, 'src');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('Detect-TestCommand identifies Python, Node, Rust, and Go test suites', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-test-detect-'));
  try {
    // 1. Python pytest.ini
    fs.writeFileSync(path.join(tmp, 'pytest.ini'), '[pytest]\n');
    let res = queryHarness(tmp);
    assert.equal(res.cmd?.Cmd, 'python -m pytest');
    assert.equal(res.cmd?.Log, 'pytest_full');

    // 2. Python pyproject.toml & fast test
    fs.unlinkSync(path.join(tmp, 'pytest.ini'));
    fs.writeFileSync(path.join(tmp, 'pyproject.toml'), '[tool.pytest]\n');
    const testsDir = path.join(tmp, 'tests');
    fs.mkdirSync(testsDir);
    fs.writeFileSync(path.join(testsDir, 'test_fast.py'), '# fast test\n');
    res = queryHarness(tmp, true);
    assert.equal(res.cmd?.Cmd, 'python -m pytest tests/test_fast.py');
    assert.equal(res.cmd?.Log, 'pytest_fast');
    fs.unlinkSync(path.join(tmp, 'pyproject.toml'));
    fs.unlinkSync(path.join(testsDir, 'test_fast.py'));

    // 3. Node package.json with test script
    fs.writeFileSync(path.join(tmp, 'package.json'), JSON.stringify({ scripts: { test: 'vitest run' } }));
    res = queryHarness(tmp);
    assert.equal(res.cmd?.Cmd, 'npm test');
    assert.equal(res.cmd?.Log, 'npm_test');
    fs.unlinkSync(path.join(tmp, 'package.json'));

    // 4. Node *.test.mjs
    fs.writeFileSync(path.join(testsDir, 'sample.test.mjs'), 'import test from "node:test";');
    res = queryHarness(tmp);
    assert.equal(res.cmd?.Cmd, 'node --test tests/*.test.mjs');
    assert.equal(res.cmd?.Log, 'node_test');
    fs.unlinkSync(path.join(testsDir, 'sample.test.mjs'));

    // 5. Rust Cargo.toml
    fs.writeFileSync(path.join(tmp, 'Cargo.toml'), '[package]\nname = "test"\n');
    res = queryHarness(tmp);
    assert.equal(res.cmd?.Cmd, 'cargo test');
    assert.equal(res.cmd?.Log, 'cargo_test');
    fs.unlinkSync(path.join(tmp, 'Cargo.toml'));

    // 6. Go go.mod
    fs.writeFileSync(path.join(tmp, 'go.mod'), 'module example.com/test\n');
    res = queryHarness(tmp);
    assert.equal(res.cmd?.Cmd, 'go test ./...');
    assert.equal(res.cmd?.Log, 'go_test');
    fs.unlinkSync(path.join(tmp, 'go.mod'));

    // 7. Unknown / empty
    res = queryHarness(tmp);
    assert.equal(res.cmd, null);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

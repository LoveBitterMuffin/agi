import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';

const PLUGIN_ROOT = path.resolve(import.meta.dirname, '..');
const SCRIPTS_DIR = path.join(PLUGIN_ROOT, 'scripts');
const HARNESS_DIR = path.join(PLUGIN_ROOT, 'harness');

function getPsFiles() {
  const list = [];
  for (const dir of [SCRIPTS_DIR, HARNESS_DIR]) {
    if (fs.existsSync(dir)) {
      for (const file of fs.readdirSync(dir)) {
        if (file.endsWith('.ps1')) list.push(path.join(dir, file));
      }
    }
  }
  return list;
}

test('all PS1 scripts have zero BOM, pure ASCII encoding, and no empty catch blocks', () => {
  const psFiles = getPsFiles();
  assert.ok(psFiles.length >= 25, `Expected >= 25 ps1 files, found ${psFiles.length}`);

  for (const filePath of psFiles) {
    const buf = fs.readFileSync(filePath);
    const rel = path.relative(PLUGIN_ROOT, filePath);

    // 0 BOM check
    const hasBom = buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf;
    assert.equal(hasBom, false, `File contains BOM: ${rel}`);

    // Pure ASCII check (all bytes <= 127)
    for (let i = 0; i < buf.length; i++) {
      assert.ok(buf[i] <= 127, `Non-ASCII byte 0x${buf[i].toString(16)} at index ${i} in ${rel}`);
    }

    // No empty catch block
    const text = buf.toString('ascii');
    const emptyCatch = /catch\s*\{\s*\}/.test(text);
    assert.equal(emptyCatch, false, `File contains empty catch block: ${rel}`);
  }
});

test('all PS1 scripts pass PowerShell 5.1 AST syntax parse with zero parse errors', () => {
  const psFiles = getPsFiles();
  const parseScript = `
    $files = @(${psFiles.map((f) => `'${f.replace(/'/g, "''")}'`).join(',')})
    $errorsCount = 0
    foreach ($f in $files) {
      $tokens = $null
      $errors = $null
      [void][System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errors)
      if ($errors -and $errors.Count -gt 0) {
        Write-Host "ERR in $f : $($errors[0].Message)"
        $errorsCount += $errors.Count
      }
    }
    exit $errorsCount
  `;

  const res = spawnSync('powershell', ['-NoProfile', '-Command', parseScript], { encoding: 'utf8' });
  assert.equal(res.status, 0, `PowerShell syntax errors detected:\n${res.stdout}\n${res.stderr}`);
});

test('smoke test get-memory-brief.ps1 -Init and audit-memory.ps1 in isolated workspace', () => {
  const tempWs = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-ps-test-'));
  const initScript = path.join(SCRIPTS_DIR, 'get-memory-brief.ps1');
  const auditScript = path.join(SCRIPTS_DIR, 'audit-memory.ps1');

  // Run -Init
  const initRes = spawnSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', initScript, '-Init'], {
    cwd: tempWs,
    encoding: 'utf8'
  });
  assert.equal(initRes.status, 0, `get-memory-brief -Init failed:\n${initRes.stdout}\n${initRes.stderr}`);
  assert.equal(fs.existsSync(path.join(tempWs, 'memory', 'Index.md')), true);

  // Run audit-memory.ps1
  const auditRes = spawnSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', auditScript], {
    cwd: tempWs,
    encoding: 'utf8'
  });
  assert.equal(auditRes.status, 0, `audit-memory.ps1 failed:\n${auditRes.stdout}\n${auditRes.stderr}`);
});

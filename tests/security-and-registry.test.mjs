import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { evaluateCommand } from '../hooks/command-guard.mjs';
import { findAgents, registerAgent } from '../hooks/agent-registry.mjs';

test('evaluateCommand blocks destructive commands across Linux and Windows syntax variants', () => {
  // Destructive root/drive deletions
  assert.equal(evaluateCommand('rm -rf /').allowed, false);
  assert.equal(evaluateCommand('sudo rm -rf /*').allowed, false);
  assert.equal(evaluateCommand('powershell -Command "Remove-Item -Recurse -Force C:\\"').allowed, false);
  assert.equal(evaluateCommand('cmd /c "rd /s /q C:\\"').allowed, false);
  assert.equal(evaluateCommand('format C:').allowed, false);
  assert.equal(evaluateCommand('mkfs.ext4 /dev/nvme0n1p1').allowed, false);
  assert.equal(evaluateCommand('dd if=/dev/zero of=/dev/sda bs=1M').allowed, false);

  // Safe commands must pass
  assert.equal(evaluateCommand('npm test').allowed, true);
  assert.equal(evaluateCommand('pytest tests').allowed, true);
  assert.equal(evaluateCommand('git status -s').allowed, true);
  assert.equal(evaluateCommand('rm ./scratch/temp.log').allowed, true);
  assert.equal(evaluateCommand('Remove-Item ./scratch/temp.log').allowed, true);
});

test('evaluateCommand blocks Base64 flag variants and alternative drive roots', () => {
  const b64C = Buffer.from('Remove-Item -Recurse -Force C:\\', 'utf16le').toString('base64');
  const b64D = Buffer.from('Remove-Item -Recurse -Force D:\\', 'utf16le').toString('base64');
  const b64E = Buffer.from('Remove-Item -Recurse -Force E:\\', 'utf16le').toString('base64');

  // Case-insensitivity & aliases for base64 flags
  assert.equal(evaluateCommand(`powershell -ENCODEDCOMMAND ${b64C}`).allowed, false);
  assert.equal(evaluateCommand(`powershell -EncodedCommand ${b64D}`).allowed, false);
  assert.equal(evaluateCommand(`powershell.exe -Enc "${b64E}"`).allowed, false);
  assert.equal(evaluateCommand(`powershell.exe -enc "${b64C}"`).allowed, false);
  assert.equal(evaluateCommand(`pwsh -E ${b64D}`).allowed, false);
  assert.equal(evaluateCommand(`pwsh -e ${b64E}`).allowed, false);

  // Alternative drive roots in raw CLI
  assert.equal(evaluateCommand('powershell -Command "Remove-Item -Recurse -Force D:\\"').allowed, false);
  assert.equal(evaluateCommand('cmd /c "rd /s /q E:\\"').allowed, false);
  assert.equal(evaluateCommand('format D:').allowed, false);
  assert.equal(evaluateCommand('format E:').allowed, false);

  // Safe Base64 commands must pass
  const safeDate = Buffer.from('Get-Date', 'utf16le').toString('base64');
  const safeProc = Buffer.from('Get-Process', 'utf16le').toString('base64');
  assert.equal(evaluateCommand(`powershell -EncodedCommand ${safeDate}`).allowed, true);
  assert.equal(evaluateCommand(`powershell -enc ${safeProc}`).allowed, true);
  assert.equal(evaluateCommand(`pwsh -e ${safeDate}`).allowed, true);
});

test('evaluateCommand blocks inline script root deletions with node --eval and python -c', () => {
  // Destructive node -e and --eval across C, D, and Unix roots
  assert.equal(evaluateCommand('node -e "fs.rmSync(\'C:\\\\\', {recursive:true})"').allowed, false);
  assert.equal(evaluateCommand('node --eval "fs.rmSync(\'D:\\\\\', {recursive:true})"').allowed, false);
  assert.equal(evaluateCommand('node -e "fs.rmdirSync(\'/\')"').allowed, false);

  // Destructive python -c variants across C, E, and Unix roots
  assert.equal(evaluateCommand('python -c "import shutil; shutil.rmtree(\'C:\\\\\')"').allowed, false);
  assert.equal(evaluateCommand('python -c "import shutil; shutil.rmtree(\'E:\\\\\')"').allowed, false);
  assert.equal(evaluateCommand('python3 -c "import os; os.remove(\'/\')"').allowed, false);
  assert.equal(evaluateCommand('python -c "import os; os.unlink(\'/\')"').allowed, false);

  // Safe scripts must pass
  assert.equal(evaluateCommand('node --eval "console.log(process.platform)"').allowed, true);
  assert.equal(evaluateCommand('node -e "console.log(\'hello\')"').allowed, true);
  assert.equal(evaluateCommand('python -c "import os; print(os.name)"').allowed, true);
  assert.equal(evaluateCommand('python -c "print(1)"').allowed, true);
});

test('findAgents resolves agents using Russian and English synonym expansion', () => {
  const dbMatch = findAgents('миграция базы данных и оптимизация sql');
  assert.ok(dbMatch.matches.length > 0);
  assert.equal(dbMatch.matches[0].name, 'database-architect');

  const testMatch = findAgents('напиши автотесты playwright');
  assert.ok(testMatch.matches.length > 0);
  assert.ok(['qa-automation-engineer', 'test-engineer'].includes(testMatch.matches[0].name));

  const debugMatch = findAgents('почини ошибку и баг');
  assert.ok(debugMatch.matches.length > 0);
  assert.equal(debugMatch.matches[0].name, 'debugger');
});

test('registerAgent dynamically creates valid specialist profile with Carpati memory section', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-reg-test-'));
  const regRes = registerAgent('cloud-architect', 'Cloud Infrastructure Architect', ['aws', 'terraform'], tempDir);
  assert.equal(regRes.success, true);

  const fileContent = fs.readFileSync(regRes.path, 'utf8');
  assert.ok(fileContent.includes('name: cloud-architect'));
  assert.ok(fileContent.includes('model: "inherit"'));
  assert.ok(fileContent.includes('Carpati Memory & Anti-Slop'));

  // Duplicate name must throw
  assert.throws(() => registerAgent('cloud-architect', 'Duplicate', [], tempDir));
  // Invalid name must throw
  assert.throws(() => registerAgent('Invalid Name!', 'Bad', [], tempDir));
});

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const SLEEP_ARR = new Int32Array(new SharedArrayBuffer(4));
const RETRY_CODES = new Set(['EPERM', 'EBUSY', 'EACCES']);
const PROJECT_MARKERS = ['.agents', '.git', 'package.json', 'AGENTS.md', 'pyproject.toml', 'Cargo.toml', 'memory'];

export function isMainModule(metaUrl) {
  if (!process.argv[1] || !metaUrl) return false;
  const a = path.resolve(process.argv[1]);
  const b = path.resolve(fileURLToPath(metaUrl));
  return process.platform === 'win32' ? a.toLowerCase() === b.toLowerCase() : a === b;
}

export function sleepSync(ms) {
  Atomics.wait(SLEEP_ARR, 0, 0, ms);
}

export function tryParseJson(raw, fallback = null, onError = null) {
  try {
    return JSON.parse(raw);
  } catch (err) {
    if (onError) onError(err);
    return fallback;
  }
}

function handleRenameFailure(tmp, err, attempt) {
  if (!RETRY_CODES.has(err.code) || attempt === 7) {
    if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
    throw err;
  }
  sleepSync(12 * (attempt + 1));
}

export function writeTextAtomic(filePath, content) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const rand = Math.random().toString(16).slice(2, 8);
  const tmp = `${filePath}.${process.pid}.${Date.now()}.${rand}.tmp`;
  fs.writeFileSync(tmp, content, 'utf8');
  for (let attempt = 0; attempt < 8; attempt++) {
    try {
      fs.renameSync(tmp, filePath);
      return;
    } catch (err) {
      handleRenameFailure(tmp, err, attempt);
    }
  }
}

export function writeJsonAtomic(filePath, data) {
  writeTextAtomic(filePath, JSON.stringify(data, null, 2));
}

function cleanStaleLock(lockPath) {
  try {
    const isStale = Date.now() - fs.statSync(lockPath).mtimeMs > 5000;
    if (isStale) fs.unlinkSync(lockPath);
  } catch (statErr) {
    if (statErr.code !== 'ENOENT') throw statErr;
  }
}

function acquireLock(lockPath) {
  for (let i = 0; i < 60; i++) {
    try {
      return fs.openSync(lockPath, 'wx');
    } catch (err) {
      if (err.code !== 'EEXIST') throw err;
      cleanStaleLock(lockPath);
      sleepSync(15);
    }
  }
  throw new Error(`Timed out acquiring state lock: ${lockPath}`);
}

export function withStateLock(filePath, fn) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const lockPath = `${filePath}.lock`;
  const fd = acquireLock(lockPath);
  try {
    return fn();
  } finally {
    fs.closeSync(fd);
    try {
      fs.unlinkSync(lockPath);
    } catch (err) {
      if (err.code !== 'ENOENT') console.error(`Lock cleanup warning: ${err.message}`);
    }
  }
}

export function resolveWorkspaceRoot(payload = {}) {
  const candidates = [
    payload?.workspaceRoot,
    payload?.workspace,
    payload?.cwd,
    payload?.projectRoot,
    process.env.ANTIGRAVITY_WORKSPACE,
    process.env.WORKSPACE_ROOT,
    process.cwd()
  ];
  for (const c of candidates) {
    if (typeof c === 'string' && c.trim()) return path.resolve(c.trim());
  }
  return process.cwd();
}

export function isProjectRoot(targetDir) {
  if (!targetDir || !fs.existsSync(targetDir)) return false;
  return PROJECT_MARKERS.some((marker) => fs.existsSync(path.join(targetDir, marker)));
}

export function readStdinText(maxBytes = 1024 * 1024) {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      data += chunk;
      if (data.length > maxBytes) reject(new Error('hook payload exceeds size limit'));
    });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', reject);
  });
}

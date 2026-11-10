function stripQuotes(token) {
  return token.replace(/^['"]+|['"]+$/g, '');
}

function tokenizeSegment(seg) {
  const parts = seg.trim().match(/"[^"]*"|'[^']*'|[^\s]+/g) || [];
  return parts.map(stripQuotes).filter(Boolean);
}

function extractWrappedSegments(seg) {
  const m = seg.match(/^(?:powershell(?:\.exe)?|pwsh|cmd(?:\.exe)?)\s+[^\n]*?(?:-command|-c|\/c)\s+["'](.+)["']$/i);
  if (!m?.[1]) return [];
  return m[1].split(/[;&|\r\n]+/).map((s) => s.trim()).filter(Boolean);
}

function extractEncodedSegments(seg) {
  const m = seg.match(/(?:^|[\\/\s])(?:powershell(?:\.exe)?|pwsh)\b[^\n]*?[-/](?:encodedcommand|enc|e)\s+["']?([A-Za-z0-9+/=]{4,})["']?/i);
  if (!m?.[1]) return [];
  try {
    const decoded = Buffer.from(m[1], 'base64').toString('utf16le');
    return decoded.split(/[;&|\r\n]+/).map((s) => s.trim()).filter(Boolean);
  } catch {
    return [];
  }
}

function unwrapShellWrappers(command) {
  const segments = String(command || '').split(/[;&|\r\n]+/).map((s) => s.trim()).filter(Boolean);
  const expanded = [...segments];
  for (const seg of segments) {
    expanded.push(...extractWrappedSegments(seg));
    expanded.push(...extractEncodedSegments(seg));
  }
  return expanded;
}

function isUnixRootTarget(tok) {
  return /^\/+\*?$/.test(tok);
}

function isWinDriveRoot(tok) {
  return /^[A-Za-z]:\\+\*?$/.test(tok);
}

function checkUnixRm(tokens) {
  let idx = 0;
  if (tokens[0]?.toLowerCase() === 'sudo') idx = 1;
  const bin = (tokens[idx] || '').replace(/\\/g, '/').toLowerCase();
  if (bin !== 'rm' && !bin.endsWith('/rm')) return null;

  const args = tokens.slice(idx + 1);
  let hasRec = false;
  let hasForce = false;
  let hasRoot = false;
  for (const arg of args) {
    if (arg.startsWith('--')) {
      if (arg === '--recursive') hasRec = true;
      if (arg === '--force') hasForce = true;
      continue;
    }
    if (arg.startsWith('-') && arg.length > 1) {
      if (/r/i.test(arg)) hasRec = true;
      if (/f/i.test(arg)) hasForce = true;
      continue;
    }
    if (isUnixRootTarget(arg)) hasRoot = true;
  }
  if (hasRec && hasForce && hasRoot) {
    return { allowed: false, rule: 'unix-root-delete', reason: 'recursive deletion of the filesystem root' };
  }
  return null;
}

function checkWinDelete(tokens) {
  const cmd = (tokens[0] || '').toLowerCase();
  const isPs = cmd === 'remove-item' || cmd === 'ri';
  const isCmdDel = cmd === 'del' || cmd === 'erase';
  const isRd = cmd === 'rd' || cmd === 'rmdir';
  if (!isPs && !isCmdDel && !isRd) return null;

  const rest = tokens.slice(1).map((t) => t.toLowerCase());
  const hasRoot = tokens.slice(1).some(isWinDriveRoot);
  if (!hasRoot) return null;

  const hasRec = rest.some((t) => /^-(?:r|rec|recurse)$/.test(t) || t === '/s');
  const hasForce = rest.some((t) => /^-(?:f|fo|force)$/.test(t) || t === '/q');
  if ((isPs && hasRec && hasForce) || (isCmdDel && hasRec) || (isRd && hasRec && hasForce)) {
    return { allowed: false, rule: 'windows-root-delete', reason: 'recursive deletion of a Windows drive root' };
  }
  return null;
}

function checkInlineScriptDelete(seg) {
  const isNode = /\b(?:node|nodejs)\s+[^\n]*?(?:-e|--eval)\b/i.test(seg);
  const isPy = /\bpython[0-9.]*\s+[^\n]*?-c\b/i.test(seg);
  if (!isNode && !isPy) return null;

  const pattern = /(?:rmSync|rmdirSync|\brm\b|rimraf|shutil\.rmtree|os\.(?:remove|rmdir|unlink))\s*\(\s*[rR]?['"](?:[A-Za-z]:(?:\\\\|\\|\/)*|\/+\*?)['"]/i;
  if (pattern.test(seg)) {
    return { allowed: false, rule: 'inline-script-root-delete', reason: 'inline script deletion of filesystem root or drive' };
  }
  return null;
}

function checkSpecialRules(seg) {
  const inlineHit = checkInlineScriptDelete(seg);
  if (inlineHit) return inlineHit;
  if (/^(?:sudo\s+)?(?:\/(?:usr\/)?sbin\/)?mkfs(?:\.[A-Za-z0-9_-]+)?\b/i.test(seg)) {
    return { allowed: false, rule: 'filesystem-format', reason: 'filesystem formatting command' };
  }
  if (/\bdd\b[^\n]*\bof=\/dev\/(?:sd|nvme|vd|xvd|hd|loop|disk)[A-Za-z0-9_-]*/i.test(seg)) {
    return { allowed: false, rule: 'raw-disk-overwrite', reason: 'raw disk overwrite' };
  }
  if (/^format(?:\.com)?\s+['"]?[A-Za-z]:/i.test(seg)) {
    return { allowed: false, rule: 'windows-drive-format', reason: 'Windows drive format' };
  }
  return null;
}

export function evaluateCommand(command) {
  const topInline = checkInlineScriptDelete(command);
  if (topInline) return topInline;
  for (const seg of unwrapShellWrappers(command)) {
    const special = checkSpecialRules(seg);
    if (special) return special;
    const tokens = tokenizeSegment(seg);
    const unixHit = checkUnixRm(tokens);
    if (unixHit) return unixHit;
    const winHit = checkWinDelete(tokens);
    if (winHit) return winHit;
  }
  return { allowed: true, rule: null, reason: 'no destructive command pattern matched' };
}

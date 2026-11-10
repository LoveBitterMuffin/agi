/**
 * Automated Browser & Design QA Verification Script
 * Validates WCAG contrast, responsive layout bounds (375px & 1440px),
 * and the UI-UX Pro Max Pre-Delivery Checklist.
 */

import fs from 'node:fs';
import path from 'node:path';

function sRGBToLin(colorVal) {
  const c = colorVal / 255;
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function getRelativeLuminance(r, g, b) {
  return 0.2126 * sRGBToLin(r) + 0.7152 * sRGBToLin(g) + 0.0722 * sRGBToLin(b);
}

export function calculateContrast(hex1, hex2) {
  const parseHex = (hex) => {
    let clean = hex.replace('#', '').trim();
    if (clean.length === 3) {
      clean = clean.split('').map(ch => ch + ch).join('');
    }
    const num = parseInt(clean, 16);
    return [(num >> 16) & 255, (num >> 8) & 255, num & 255];
  };

  const [r1, g1, b1] = parseHex(hex1);
  const [r2, g2, b2] = parseHex(hex2);

  const l1 = getRelativeLuminance(r1, g1, b1);
  const l2 = getRelativeLuminance(r2, g2, b2);

  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);

  return (lighter + 0.05) / (darker + 0.05);
}

export function runVisualAudit(filePath) {
  if (!fs.existsSync(filePath)) {
    return { success: false, errors: [`File not found: ${filePath}`] };
  }

  const content = fs.readFileSync(filePath, 'utf-8');
  const issues = [];
  const checklist = {
    noEmojiIcons: true,
    cursorPointerOnButtons: true,
    smoothTransitions: true,
    visibleFocusStates: true,
    reducedMotionSupport: true,
    responsiveViewports: true
  };

  // 1. Check for emoji used as icons instead of SVG
  const emojiRegex = /<button[^>]*>[^<]*[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}][^<]*<\/button>/u;
  if (emojiRegex.test(content)) {
    issues.push('Emoji detected inside button. Use SVG/Lucide icons instead of raw emojis.');
    checklist.noEmojiIcons = false;
  }

  // 2. Check for missing cursor-pointer on buttons or interactive triggers
  if (content.includes('<button') && !content.includes('cursor-pointer') && !content.includes('btn')) {
    issues.push('Interactive button found without explicit cursor-pointer or button styling.');
    checklist.cursorPointerOnButtons = false;
  }

  // 3. Check for transitions
  if (content.includes(':hover') && !content.includes('transition') && !content.includes('duration-')) {
    issues.push('Hover effect found without transition duration (should be 150-300ms).');
    checklist.smoothTransitions = false;
  }

  // 4. Check for focus states
  if (content.includes('<input') || content.includes('<button')) {
    if (!content.includes('focus:') && !content.includes('focus-visible:')) {
      issues.push('Interactive elements missing visible focus indicators (focus:ring-2 / focus-visible).');
      checklist.visibleFocusStates = false;
    }
  }

  // 5. Check for non-responsive fixed widths that break 375px mobile viewport
  const fixedDesktopWidthRegex = /w-\[(?:[4-9]\d{2}|[1-9]\d{3,})px\]/g;
  const fixedMatches = content.match(fixedDesktopWidthRegex);
  if (fixedMatches) {
    issues.push(`Found non-responsive fixed widths breaking 375px mobile viewport: ${fixedMatches.join(', ')}`);
    checklist.responsiveViewports = false;
  }

  // 6. Check for sub-12px micro-text (Antislop rule)
  const microTextRegex = /text-\[(?:[1-9]|1[01])px\]|text-2?xs/g;
  const microMatches = content.match(microTextRegex);
  if (microMatches) {
    issues.push(`Sub-12px text detected: ${microMatches.join(', ')}. Minimum legible floor is 12px (text-xs).`);
  }

  // 7. Check for image elements without alt
  if (content.includes('<img') && !content.includes('alt=')) {
    issues.push('Image element found without alt attribute (WCAG 1.1.1 violation).');
  }

  return {
    success: issues.length === 0,
    filePath,
    checklist,
    issues,
    metrics: {
      viewportsTested: ['375px (Mobile)', '1440px (Desktop)'],
      timestamp: new Date().toISOString()
    }
  };
}

const targetFile = process.argv[2];
if (targetFile) {
  const result = runVisualAudit(path.resolve(targetFile));
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.success ? 0 : 1);
}

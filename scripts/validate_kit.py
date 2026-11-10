#!/usr/bin/env python3
"""Self-validate an Antigravity plugin installation."""
from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover
    yaml = None

from component_registry import is_semver, normalize_list


@dataclass
class Finding:
    severity: str
    code: str
    file: str
    line: int
    message: str


REQUIRED_FIELDS = {
    "agent": {"name", "description", "tools", "skills"},
    "skill": {"name", "description"},
    "rule": {"trigger", "description"},
}
REQUIRED_DIRS = ("agents", "skills", "rules", "scripts", "templates", "harness")
SKIP_PARTS = {"__pycache__", "node_modules", ".git"}


def add(
    findings: list[Finding],
    severity: str,
    code: str,
    path: Path,
    message: str,
    line: int = 1,
) -> None:
    findings.append(Finding(severity, code, path.as_posix(), line, message))


def _iter_files(root: Path, pattern: str) -> list[Path]:
    return [
        path
        for path in sorted(root.rglob(pattern))
        if not any(part in SKIP_PARTS for part in path.parts)
    ]


def extract_frontmatter(path: Path) -> tuple[str | None, int]:
    text = path.read_text("utf-8", errors="replace").replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return None, 1
    end = text.find("\n---\n", 4)
    if end < 0:
        return None, 1
    return text[4:end], 1


def fallback_frontmatter(raw: str) -> dict[str, object]:
    data: dict[str, object] = {}
    for line in raw.splitlines():
        if not line or line[0].isspace() or line.lstrip().startswith("#"):
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            key, value = match.groups()
            data[key] = value.strip().strip("\"'")
    return data


def parse_frontmatter(path: Path, rel: Path, findings: list[Finding]) -> dict[str, object] | None:
    raw, _ = extract_frontmatter(path)
    if raw is None:
        add(findings, "error", "frontmatter.missing", rel, "Missing or unterminated YAML frontmatter")
        return None
    if yaml is None:
        return fallback_frontmatter(raw)
    try:
        data = yaml.safe_load(raw)
    except Exception as exc:
        line = int(getattr(getattr(exc, "problem_mark", None), "line", 0)) + 2
        add(findings, "error", "frontmatter.invalid_yaml", rel, str(exc), line)
        return None
    if not isinstance(data, dict):
        add(findings, "error", "frontmatter.not_mapping", rel, "Frontmatter must be a YAML mapping")
        return None
    return data


def validate_json(root: Path, findings: list[Finding]) -> None:
    for path in _iter_files(root, "*.json"):
        try:
            json.loads(path.read_text("utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            line = int(getattr(exc, "lineno", 1))
            add(findings, "error", "json.invalid", path.relative_to(root), str(exc), line)


def validate_plugin_manifest(root: Path, findings: list[Finding]) -> None:
    manifest_path = root / "plugin.json"
    if not manifest_path.is_file():
        add(findings, "error", "plugin.missing", Path("plugin.json"), "plugin.json is missing")
        return
    try:
        data = json.loads(manifest_path.read_text("utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    for key in ("name", "displayName", "version", "description", "logo"):
        if not data.get(key):
            add(findings, "error", "plugin.required_field", Path("plugin.json"), f"Missing plugin field: {key}")
    version = str(data.get("version", ""))
    if version and not is_semver(version):
        add(findings, "error", "plugin.invalid_semver", Path("plugin.json"), f"Invalid SemVer: {version!r}")
    logo = str(data.get("logo", ""))
    if logo and not (root / logo).is_file():
        add(findings, "error", "plugin.missing_logo", Path("plugin.json"), f"Missing logo asset: {logo}")


def _collect_hook_commands(node: object, out: list[str]) -> None:
    if isinstance(node, list):
        for item in node:
            _collect_hook_commands(item, out)
    elif isinstance(node, dict):
        cmd = node.get("command")
        if isinstance(cmd, str):
            out.append(cmd)
        for val in node.values():
            _collect_hook_commands(val, out)


def validate_hooks_config(root: Path, findings: list[Finding]) -> None:
    hooks_path = root / "hooks.json"
    if not hooks_path.is_file():
        add(findings, "error", "hooks.missing", Path("hooks.json"), "hooks.json is missing")
        return
    try:
        data = json.loads(hooks_path.read_text("utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    if not isinstance(data.get("agi"), dict):
        add(findings, "error", "hooks.invalid_schema", Path("hooks.json"), "hooks.json must define 'agi' mapping")
        return
    commands: list[str] = []
    _collect_hook_commands(data["agi"], commands)
    for cmd in commands:
        for rel_target in re.findall(r"[^\s\"']+\.(?:mjs|ps1)", cmd):
            if not (root / rel_target).is_file():
                add(findings, "error", "hooks.missing_script", Path("hooks.json"), f"Missing hook target: {rel_target}")


def validate_plugin_dirs(root: Path, findings: list[Finding]) -> None:
    for dirname in REQUIRED_DIRS:
        if not (root / dirname).is_dir():
            add(findings, "error", "structure.missing_dir", Path(dirname), f"Missing plugin directory: {dirname}")


def _check_component_group(
    root: Path,
    kind: str,
    paths: list[Path],
    findings: list[Finding],
) -> dict[str, dict[str, object]]:
    registry: dict[str, dict[str, object]] = {}
    names_seen: set[str] = set()
    for path in paths:
        rel = path.relative_to(root)
        data = parse_frontmatter(path, rel, findings)
        if data is None:
            continue
        for field in sorted(REQUIRED_FIELDS[kind] - set(data)):
            add(findings, "error", "frontmatter.required_field", rel, f"Missing required field: {field}")
        expected = path.parent.name if kind == "skill" else path.stem
        if kind != "rule":
            name = str(data.get("name", ""))
            if name != expected:
                add(findings, "error", "frontmatter.name_mismatch", rel, f"name={name!r}, expected {expected!r}")
            if name and name in names_seen:
                add(findings, "error", "frontmatter.duplicate_name", rel, f"Duplicate {kind} name: {name}")
            if name:
                names_seen.add(name)
        version = data.get("version")
        if version is not None and not is_semver(str(version)):
            add(findings, "error", "frontmatter.invalid_semver", rel, f"Invalid SemVer: {version!r}")
        registry[expected] = data
    return registry


def validate_frontmatter(
    root: Path, findings: list[Finding]
) -> tuple[dict[str, dict[str, object]], dict[str, dict[str, object]], dict[str, dict[str, object]]]:
    rule_paths = [p for p in sorted((root / "rules").glob("*.md")) if p.name != "AGENTS.md"]
    agents = _check_component_group(root, "agent", sorted((root / "agents").glob("*.md")), findings)
    skills = _check_component_group(root, "skill", sorted((root / "skills").glob("*/SKILL.md")), findings)
    rules = _check_component_group(root, "rule", rule_paths, findings)
    return agents, skills, rules


def validate_references(
    root: Path,
    agents: dict[str, dict[str, object]],
    skills: dict[str, dict[str, object]],
    findings: list[Finding],
) -> None:
    for agent_name, data in agents.items():
        path = Path("agents") / f"{agent_name}.md"
        for skill in normalize_list(data.get("skills")):
            if skill not in skills:
                add(findings, "error", "reference.unknown_skill", path, f"Agent references missing skill: {skill}")

    script_pattern = re.compile(r'["\']((?:skills|scripts)/[^"\']+?\.py)["\']')
    for path in (root / "scripts").glob("*.py"):
        text = path.read_text("utf-8", errors="replace")
        for match in script_pattern.finditer(text):
            target_rel = match.group(1)
            if any(char in target_rel for char in "*?[") or (root / target_rel).is_file():
                continue
            line = text.count("\n", 0, match.start()) + 1
            add(findings, "error", "reference.missing_script", path.relative_to(root), f"Missing script: {target_rel}", line)


def validate_markdown_links(root: Path, findings: list[Finding]) -> None:
    pattern = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
    skip_schemes = ("#", "http://", "https://", "mailto:", "tel:", "data:", "file://")
    resolved_root = root.resolve()
    for path in _iter_files(root, "*.md"):
        text = path.read_text("utf-8", errors="replace")
        for match in pattern.finditer(text):
            target_text = match.group(1).strip().split()[0].strip("<>") if match.group(1).strip() else ""
            if not target_text or target_text.startswith(skip_schemes):
                continue
            target_text = unquote(target_text.split("#", 1)[0])
            if not target_text:
                continue
            if path.relative_to(root).as_posix() == "skills/documentation-templates/SKILL.md" and target_text.startswith("./docs/"):
                continue
            target = (path.parent / target_text).resolve()
            if resolved_root in target.parents and not target.exists():
                line = text.count("\n", 0, match.start()) + 1
                add(findings, "error", "markdown.missing_link", path.relative_to(root), f"Missing local target: {target_text}", line)


def _validate_memory_index(memory_root: Path, findings: list[Finding]) -> None:
    index = memory_root / "MEMORY.md"
    if not index.is_file():
        add(findings, "error", "memory.index_missing", Path("memory/MEMORY.md"), "Memory index is missing")
        return
    lines = index.read_text("utf-8").splitlines()
    if len(lines) > 200:
        add(findings, "error", "memory.index_too_large", Path("memory/MEMORY.md"), f"Memory index has {len(lines)} lines; maximum is 200")
    entry_pattern = re.compile(r"^- \[(user|feedback|project|reference)\] .+ → ([A-Za-z0-9._-]+\.md)$")
    for line_no, line in enumerate(lines, 1):
        if not line.startswith("- ["):
            continue
        match = entry_pattern.fullmatch(line)
        if not match:
            add(findings, "error", "memory.invalid_entry", Path("memory/MEMORY.md"), "Invalid memory index entry", line_no)
        elif not (memory_root / match.group(2)).is_file():
            add(findings, "error", "memory.missing_topic", Path("memory/MEMORY.md"), f"Missing topic file: {match.group(2)}", line_no)


def validate_memory(root: Path, findings: list[Finding]) -> None:
    memory_root = root / "memory"
    _validate_memory_index(memory_root, findings)
    topics = ("feedback-history.md", "project-conventions.md", "tech-decisions.md", "user-preferences.md")
    for topic in topics:
        path = memory_root / topic
        rel = Path("memory") / topic
        if not path.is_file():
            add(findings, "error", "memory.required_topic", rel, "Required memory topic is missing")
            continue
        data = parse_frontmatter(path, rel, findings)
        if data is None:
            continue
        for field in sorted({"type", "created", "updated"} - set(data)):
            add(findings, "error", "memory.required_field", rel, f"Missing required field: {field}")
        if str(data.get("type", "")) not in {"user", "feedback", "project", "reference"}:
            add(findings, "error", "memory.invalid_type", rel, f"Invalid memory type: {data.get('type')!r}")


def validate_python(root: Path, findings: list[Finding]) -> None:
    for path in _iter_files(root, "*.py"):
        try:
            ast.parse(path.read_text("utf-8"), filename=str(path))
        except (OSError, SyntaxError) as exc:
            add(findings, "error", "python.syntax", path.relative_to(root), str(exc), int(getattr(exc, "lineno", 1) or 1))


def validate_ps1_hygiene(root: Path, findings: list[Finding]) -> None:
    for path in sorted((root / "scripts").glob("*.ps1")):
        rel = path.relative_to(root)
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            add(findings, "error", "ps1.utf8_bom", rel, "PowerShell script contains UTF-8 BOM")
        non_ascii = sum(1 for b in raw if b > 0x7F)
        if non_ascii:
            add(findings, "error", "ps1.non_ascii", rel, f"PowerShell script contains {non_ascii} non-ASCII byte(s)")
        text = raw.decode("utf-8", errors="replace")
        if re.search(r"catch\s*\{\s*\}", text):
            add(findings, "error", "ps1.empty_catch", rel, "Empty catch {} block detected")
        if re.search(r"\bSet-Content\b", text) or "[System.Text.Encoding]::UTF8" in text:
            add(findings, "error", "ps1.unsafe_utf8", rel, "Use UTF8Encoding($false) instead of Set-Content / Encoding::UTF8")


def validate(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    validate_json(root, findings)
    validate_plugin_manifest(root, findings)
    validate_hooks_config(root, findings)
    validate_plugin_dirs(root, findings)
    agents, skills, _rules = validate_frontmatter(root, findings)
    validate_references(root, agents, skills, findings)
    validate_markdown_links(root, findings)
    validate_memory(root, findings)
    validate_python(root, findings)
    validate_ps1_hygiene(root, findings)
    return findings


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="Validate Antigravity plugin structure and contracts")
    parser.add_argument("path", nargs="?", default=None, help="Path to plugin root (defaults to parent of scripts/)")
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()
    root = Path(args.path).resolve() if args.path else Path(__file__).resolve().parents[1]
    if not root.is_dir():
        parser.error(f"Toolkit directory does not exist: {root}")
    findings = validate(root)
    errors = [item for item in findings if item.severity == "error"]
    warnings = [item for item in findings if item.severity == "warning"]
    if args.as_json:
        payload = {"toolkit": str(root), "passed": not errors, "summary": {"errors": len(errors), "warnings": len(warnings)}, "findings": [item.__dict__ for item in findings]}
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"Antigravity plugin self-validation: {root}")
        for item in findings:
            print(f"[{item.severity.upper()}] {item.file}:{item.line} {item.code} - {item.message}")
        print(f"Summary: {len(errors)} error(s), {len(warnings)} warning(s)")
        print("[PASS] Plugin is structurally valid." if not errors else "[FAIL] Plugin validation failed.")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())

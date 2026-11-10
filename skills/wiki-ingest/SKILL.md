---
name: wiki-ingest
description: Compile raw files from memory/raw/inbox/ into structured wiki chapters with lossless pointers and SemVer bumping.
---
1. Ensure `memory/` structure exists (`.agents/scripts/get-memory-brief.ps1 -Init` if missing) and scan `memory/raw/inbox/` (ignoring `.gitkeep`). If empty, exit.
2. Move each intake file to `memory/raw/vault/` as `RAW-YYYY-NNN_<slug>.md` with an ASCII-safe slug (via `.agents/scripts/ingest.ps1` or atomic move).
3. Read `memory/Index.md` and `memory/MOC.md` to map target chapters (`chapter_id: CH-NNN`) in `memory/wiki/chapters/`.
4. Update chapters: synthesize high-level rules and contracts; replace raw data, transcripts, and large tables with lossless pointers (`See memory/raw/vault/RAW-YYYY-NNN_<slug>.md lines X-Y`).
5. Bump SemVer `version` in each modified chapter's YAML frontmatter, sync `memory/Index.md` and `memory/MOC.md`, and verify integrity with `.agents/scripts/audit-memory.ps1`.

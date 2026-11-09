---
name: wiki-ingest
description: Compile raw files from memory/raw/inbox/ into structured wiki chapters with lossless pointers and SemVer bumping.
---
1. Scan `memory/raw/inbox/`. If empty, exit.
2. Move each file to `memory/raw/vault/` as `RAW-YYYY-NNN_<slug>.md`.
3. Read `memory/Index.md`, map target chapters in `memory/wiki/chapters/`.
4. Update chapters: write high-level rules; replace raw data/tables with lossless pointers (`See memory/raw/vault/RAW-YYYY-NNN.md lines X-Y`).
5. Bump version in chapter YAML header and sync `memory/Index.md`.

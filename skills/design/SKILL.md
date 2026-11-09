---
name: design
description: "Autonomous multi-agent UI/UX design and frontend development workflow powered by UI-UX Pro Max design intelligence. Orchestrates sub_agent_color_stylist, sub_agent_ux_stylist, sub_agent_ui_stylist, and sub_agent_coder for end-to-end interface creation, automated browser verification, and generative UI prototyping."
allowed-tools:
  - invoke_subagent
  - send_message
  - manage_subagents
  - ask_question
  - write_file
  - read_file
  - run_command
---

# /design: Autonomous UI/UX & Frontend Multi-Agent Workflow

This skill defines the end-to-end autonomous multi-agent pipeline for designing and developing production-grade UI components and pages, enhanced with the **UI-UX Pro Max** local design intelligence engine.

## Orchestration Architecture with UI-UX Pro Max

```
User Directive (/design <prompt>)
               │
               ▼
   [Main Orchestrator Agent]
               │
      ┌────────┴────────┐  (Step 1: Parallel Research & Domain Query)
      ▼                 ▼
[color_stylist]   [ux_stylist]
(ui-search.py     (ui-search.py
 --domain color)   --domain ux/landing)
      │                 │
      └────────┬────────┘
               ▼           (Step 2: Synthesis & Design System)
        [ui_stylist]
       (ui-search.py --design-system, --domain style/typography/motion)
       (Output: DESIGN_BRIEF.md with 8pt grid & fluid motion)
               │
               ▼           (Step 3: Frontend Implementation)
         [coder_agent]
       (ui-search.py --domain react/icons)
       (React + Tailwind CSS conforming to Pre-Delivery Checklist)
               │
               ▼           (Step 4: Autonomous QA Loop <= 3 tries)
   [Browser Verification]  (Chrome DevTools + verify-ui.mjs: 375px/1440px, WCAG)
               │
        ┌──────┴──────┐
     Passed?        Failed?
      │                │
     YES               └──► [Self-Healing Iteration]
      ▼
[/generative_ui & Chat Summary: Palette, UX Logic, React Code]
```

---

## 4-Step Execution Protocol

### Step 1: Brief & Research (Parallel Swarm Dispatch)
- If the user request contains ambiguities, execute **Gate 0** with `ask_question`.
- Concurrently dispatch (`invoke_subagent` in a single turn):
  1. `sub_agent_color_stylist`:
     - Runs: `python .agents/scripts/ui-search.py "<product/domain>" --domain color`
     - Evaluates brand psychology, semantic token mapping, and WCAG AA/AAA / APCA contrast.
  2. `sub_agent_ux_stylist`:
     - Runs: `python .agents/scripts/ui-search.py "<query>" --domain ux` and `--domain landing` / `--domain app-interface`
     - Analyzes information architecture, competitive UX patterns, user flow, and component state matrix.

### Step 2: Design Specification Generation (`DESIGN_BRIEF.md`)
- Dispatch `sub_agent_ui_stylist` providing the outputs of both stylists.
- `sub_agent_ui_stylist`:
  - Runs: `python .agents/scripts/ui-search.py "<product>" --design-system`
  - Runs: `python .agents/scripts/ui-search.py "<style>" --domain style`
  - Runs: `python .agents/scripts/ui-search.py "<mood>" --domain typography`
  - Runs: `python .agents/scripts/ui-search.py "<motion>" --domain motion`
  - Compiles the master `DESIGN_BRIEF.md` containing:
    * Curated Color Tokens (JSON specification with hex/rgb/contrast).
    * Semantic Blocks & Wireframe IA.
    * 8pt Spatial Grid (`p-2`, `p-4`, `p-6`, `p-8`, `gap-4`, etc.).
    * Fluid Typographic Scale (`rem`, weights, line-heights, Google Fonts imports).
    * Border geometry & corner radii.
    * Antigravity & Fluid Motion Physics (springs, cubic-bezier, zero CLS, reduced-motion).

### Step 3: Development & Browser Verification
- Dispatch `sub_agent_coder` with `DESIGN_BRIEF.md`.
- `sub_agent_coder`:
  1. Implements production-ready React + TypeScript + Tailwind CSS code conforming to Micro-modularity (<=150 lines/file, <=30 lines/function).
  2. Enforces the **UI-UX Pro Max Pre-Delivery Checklist**:
     - No emoji icons (Lucide icons only).
     - `cursor-pointer` on all interactive triggers.
     - Smooth 150-300ms transitions.
     - Visible focus rings (`focus-visible:ring-2`).
     - `prefers-reduced-motion` fallbacks.
     - Responsive layouts for 375px & 1440px.
  3. Compiles code in the project sandbox environment.
  4. Launches Chrome DevTools / `verify-ui.mjs` verification to inspect:
     - Mobile Viewport: 375px.
     - Desktop Viewport: 1440px.
     - Console error logs.
     - Text contrast ratios.
     - Horizontal overflow / layout shifts.

### Step 4: Quality Control & Self-Healing QA Loop
- If defects or contrast violations are caught, `sub_agent_coder` executes autonomous self-correction (maximum 3 iterations).
- Generates a self-contained interactive Generative UI HTML prototype.

---

## Output Protocol
1. **Generative UI Prototype:** Deploy artifact to `<appDataDir>\brain\<conversation-id>/prototype.html` and embed with `<agent-embed src="file:///<artifact_path>/prototype.html"></agent-embed>`.
2. **Chat Executive Summary:**
   - **Color Palette:** Table of HEX values, roles, and contrast scores.
   - **UX & State Logic:** Information Architecture and state transitions.
   - **Production Code:** Full React + Tailwind CSS component code.

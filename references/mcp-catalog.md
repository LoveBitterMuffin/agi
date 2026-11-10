# Antigravity Cross-Plugin MCP Tool Gateway Catalog

This reference document defines the routing, capabilities, and security boundaries for external Model Context Protocol (MCP) servers integrated across the Antigravity ecosystem.

---

## 1. Supported MCP Servers & Capabilities

### A. Figma MCP Server (`figma_*`)
- **Plugin / Provider:** `antigravity-plugins-official/plugin/figma`
- **Key Tools:**
  - `get_design_context`: Extract layout, typography, components, and CSS from Figma nodes.
  - `use_figma`: Programmatic interaction with the Figma file context.
  - `create_new_file`: Generate new Figma Design, FigJam, or Slides documents.
  - `generate_diagram`: Render sequence diagrams, flowcharts, and ERDs in FigJam.
  - `get_code_connect_map`: Inspect code-to-Figma component mappings.
- **Assigned Agents:** `sub_agent_ui_stylist`, `frontend-specialist`, `product-designer`.
- **Security & Sandboxing:** Read-only access to existing design systems by default. File mutations restricted to designated project canvases.

### B. Chrome DevTools MCP Server (`chrome-devtools-*`)
- **Plugin / Provider:** `antigravity-plugins-official/plugin/chrome-devtools-plugin`
- **Key Tools:**
  - `navigate_page`: Load local or remote URLs in headless Chrome.
  - `click`, `fill`, `fill_form`, `type_text`: Interactive DOM automation.
  - `take_screenshot`: Visual verification of responsive layouts (375px mobile, 1440px desktop).
  - `list_console_messages`: Capture console errors, unhandled rejections, and warnings.
  - `list_network_requests`: Audit HTTP status codes, latency, and failed requests.
  - `evaluate_script`: Headless JavaScript evaluation in page context.
- **Assigned Agents:** `sub_agent_coder`, `qa-automation-engineer`, `penetration-tester`, `performance-optimizer`.
- **Security & Sandboxing:** Headless sandbox bound to `localhost` or verified test environments. No exfiltration of cookies or credentials.

### C. Android CLI & Device Hub MCP (`android-*`)
- **Plugin / Provider:** `android-cli-plugin`
- **Key Tools:**
  - `android`: CLI engine for project scaffolding, APK builds, and SDK management.
  - `device-hub`: AVD lifecycle management, screen inspection, touch/key injection.
  - `compose-preview`: Isolated Jetpack Compose `@Preview` rendering in sidecar.
- **Assigned Agents:** `mobile-developer`, `qa-automation-engineer`.
- **Security & Sandboxing:** Local emulator execution only. No untrusted APK sideloading.

### D. Context7 Documentation MCP (`context7_*`)
- **Plugin / Provider:** `agi/mcp/context7`
- **Key Tools:**
  - `resolve-library-id`: Search for verified library identifiers.
  - `query-docs`: Retrieve current library documentation, type signatures, and migration guides.
- **Assigned Agents:** `orchestrator`, `codebase-scout`, `backend-specialist`, `frontend-specialist`.
- **Protocol:** Mandatory lookup for third-party libraries (Next.js 15, Tailwind v4, Pydantic v2) instead of assuming outdated knowledge.

---

## 2. Dynamic Routing & Boundaries Matrix

| Agent Role | Primary MCP Server | Secondary MCP Server | Prohibited Actions | Read/Write Policy |
|:---|:---|:---|:---|:---|
| **sub_agent_ui_stylist** | `figma_*` | `layout-math` | Browser navigation, native terminal | Read Design Tokens, Export Specs |
| **sub_agent_coder** | `chrome-devtools-*` | `context7_*` | Direct Figma mutation, un-shielded bash | Localhost DOM verification, Sandbox |
| **mobile-developer** | `android-*` | `context7_*` | Web browser automation | AVD lifecycle, Compose preview |
| **backend-specialist** | `context7_*` | None | Figma API, UI rendering | Read official docs, typed schemas |
| **qa-automation-engineer** | `chrome-devtools-*` | `android-*` | Modifying production source code | Read DOM, Capture logs, Run tests |

---

## 3. Sandboxing & Context Shielding Invariant
1. All network requests and browser traces from MCP servers must be clamped to avoid flooding parent context.
2. Screenshots and trace artifacts must be stored in `scratch/` or `artifacts/` and referenced via absolute markdown links.

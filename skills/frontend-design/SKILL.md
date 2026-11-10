---
name: frontend-design
description: Anti-slop frontend design for web UI — landing pages, portfolios, marketing/product sites, and redesigns. Reads the brief, infers the right direction, and ships interfaces that don't look templated. Real design systems when applicable, audit-first on redesigns, strict pre-flight check. NOT for mobile apps.
when_to_use: "When designing or building web UI — components, layouts, color, typography, landing pages, or redesigns. NOT for mobile apps (use mobile-design)."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
version: 1.0.0
---

> **Style variants & tools** — read the matching file only when the brief calls for it:
>
> | File | When to read |
> |------|--------------|
> | [style-minimalist.md](style-minimalist.md) | Clean, editorial, monochrome minimalism |
> | [style-brutalist.md](style-brutalist.md) | Raw industrial / terminal, data-heavy |
> | [redesign.md](redesign.md) | Upgrading an existing UI (audit-first) |
> | [references/design-details.md](references/design-details.md) | Full design system tables (2.A/2.B), bias-correction catalogs (4.1-4.11), TSX skeletons (5.A-5.C), AI Tells (9.A-9.F), pattern vocabulary (10), redesign protocol (11), block schema (12), Appendices A-C |
> | `scripts/ux_audit.py` | UX & accessibility audit of built UI |
> | `scripts/accessibility_checker.py` | Focused accessibility check |
>
> _Design rules below adapted from [taste-skill](https://github.com/Leonxlnx/taste-skill) by Leonxlnx (MIT). Mobile UI lives in the separate `mobile-design` skill._


# Frontend Design — Anti-Slop Web UI

> Landing pages, portfolios, and redesigns. Not dashboards, not data tables, not multi-step product UI.
> Every rule below is **contextual**. None of it fires automatically. First read the brief, then pull only what fits.

---

## 0. BRIEF INFERENCE (Read the Room Before Anything Else)

Before touching code or tweaking dials, **infer what the user actually wants**. Most LLM design output is bad because the model jumps to a default aesthetic instead of reading the room.

### 0.A Read these signals first
1. **Page kind** - landing (SaaS / consumer / agency / event), portfolio (dev / designer / creative studio), redesign (preserve vs overhaul), editorial / blog.
2. **Vibe words** the user used - "minimalist", "calm", "Linear-style", "Awwwards", "brutalist", "premium consumer", "Apple-y", "playful", "serious B2B", "editorial", "agency-y", "glassy", "dark tech".
3. **Reference signals** - URLs they linked, screenshots they pasted, products they named, brands they're competing with.
4. **Audience** - B2B procurement panel vs. design-conscious consumer vs. recruiter scanning a portfolio. The audience picks the aesthetic, not your taste.
5. **Brand assets that already exist** - logo, color, type, photography. For redesigns, these are starting material, not optional input (see Section 11).
6. **Quiet constraints** - accessibility-first audiences, public-sector, regulated industries, trust-first commerce, kids' products. These constraints OVERRIDE aesthetic preference.

### 0.B Output a one-line "Design Read" before generating
Before any code, state in one line: **"Reading this as: \<page kind> for \<audience>, with a \<vibe> language, leaning toward \<design system or aesthetic family>."**

Example reads:
- *"Reading this as: B2B SaaS landing for technical buyers, with a Linear-style minimalist language, leaning toward Tailwind utilities + Geist + restrained motion."*
- *"Reading this as: solo designer portfolio for hiring managers, with an editorial / kinetic-type language, leaning toward native CSS + scroll-driven animation + custom typography."*
- *"Reading this as: redesign of a public-sector service site, with a trust-first language, leaning toward GOV.UK Frontend or USWDS."*

### 0.C If the brief is ambiguous, ask one question, do not guess
Ask exactly **one** clarifying question - never a multi-question dump - and only when the design read genuinely diverges. Example: *"Should this feel closer to Linear-clean or Awwwards-experimental?"*

If you can confidently infer from context, **do not ask**. Just declare the design read and proceed.

### 0.D Anti-Default Discipline
Do not default to: AI-purple gradients, centered hero over dark mesh, three equal feature cards, generic glassmorphism on everything, infinite-loop micro-animations everywhere, Inter + slate-900. These are the LLM defaults. Reach past them deliberately based on the design read.

---

## 1. THE THREE DIALS (Core Configuration)

After the design read, set three dials. Every layout, motion, and density decision below is gated by these.

* **`DESIGN_VARIANCE: 8`** - 1 = Perfect Symmetry, 10 = Artsy Chaos
* **`MOTION_INTENSITY: 6`** - 1 = Static, 10 = Cinematic / Physics
* **`VISUAL_DENSITY: 4`** - 1 = Art Gallery / Airy, 10 = Cockpit / Packed Data

**Baseline:** `8 / 6 / 4`. Use these unless the design read overrides them. Do not ask the user to edit this file - overrides happen conversationally.

### 1.A Dial Inference (design read → dial values)
| Signal | VARIANCE | MOTION | DENSITY |
|---|---|---|---|
| "minimalist / clean / calm / editorial / Linear-style" | 5-6 | 3-4 | 2-3 |
| "premium consumer / Apple-y / luxury / brand" | 7-8 | 5-7 | 3-4 |
| "playful / wild / Dribbble / Awwwards / experimental / agency" | 9-10 | 8-10 | 3-4 |
| "landing page / portfolio / marketing site (default)" | 7-9 | 6-8 | 3-5 |
| "trust-first / public-sector / regulated / accessibility-critical" | 3-4 | 2-3 | 4-5 |
| "redesign - preserve" | match existing | +1 | match existing |
| "redesign - overhaul" | +2 | +2 | match existing |

### 1.B Use-Case Presets
| Use case | VARIANCE | MOTION | DENSITY |
|---|---|---|---|
| Landing (SaaS, mainstream) | 7 | 6 | 4 |
| Landing (Agency / creative) | 9 | 8 | 3 |
| Landing (Premium consumer) | 7 | 6 | 3 |
| Portfolio (Designer / studio) | 8 | 7 | 3 |
| Portfolio (Developer) | 6 | 5 | 4 |
| Editorial / Blog | 6 | 4 | 3 |
| Public-sector service | 3 | 2 | 5 |
| Redesign - preserve | match | match+1 | match |
| Redesign - overhaul | +2 | +2 | match |

### 1.C How the Dials Drive Output
Use these (or user-overridden values) as global variables. Cross-references throughout this document refer to these exact variable names - never invent aliases like `LAYOUT_VARIANCE` or `ANIM_LEVEL`.

---

---

## 2. BRIEF ? DESIGN SYSTEM MAP

Pick the right foundation from the design read (Section 0) and dials (Section 1).
- **Real Design Systems:** When the brief aligns with Material 3, Fluent UI, Carbon, Polaris, Atlaskit, Primer, GOV.UK, USWDS, Bootstrap, Radix, shadcn/ui, or Tailwind v4, use the **official** package (never hand-recreate CSS or override 90% of tokens). **One system per project.**
- **Aesthetics (not systems):** Glassmorphism, Bento, Brutalism, Editorial, Dark Tech, Aurora, Kinetic Type, and Web Liquid Glass approximations use native CSS + Tailwind; label approximations honestly.
- Full selection tables (2.A & 2.B): [references/design-details.md](references/design-details.md#2-brief--design-system-map).

## 3. DEFAULT ARCHITECTURE & CONVENTIONS

- **Stack:** React/Next.js with Server Components default; isolate Motion/scroll/pointer logic in `"use client"` leaf components. **Tailwind v4** (`@tailwindcss/postcss` or Vite plugin); `motion/react`; `next/font` or self-hosted `@font-face` with `font-display: swap`.
- **State & Deps:** Use `useMotionValue`/`useTransform`/`useScroll` for continuous input (never `useState`). Verify every dependency in `package.json` before importing.
- **Icons, Emojis & Layout:** Use `@phosphor-icons/react`, `hugeicons-react`, `@radix-ui/react-icons`, or `@tabler/icons-react` (discourage `lucide-react`; never hand-roll SVG icons or mix families). Avoid emojis by default. Use `min-h-[100dvh]` (never `h-screen`), CSS Grid over flex-math, and `max-w-[1400px]` / `max-w-7xl`.
- Full details (3.A?3.F): [references/design-details.md](references/design-details.md#3-default-architecture--conventions).

## 4. DESIGN ENGINEERING DIRECTIVES (Summary)

- **Typography & Color:** Avoid `Inter` default; **`Fraunces` and `Instrument_Serif` are BANNED as defaults**; emphasize via italic/bold of the **same** font with `leading-[1.1]` + `pb-1` clearance. Enforce **Color Consistency Lock** (1 accent, saturation <80%), **LILA Rule** (no default AI purple), and **Premium-Consumer Palette Ban** (no default warm cream/beige + brass/clay/oxblood + espresso; rotate alternatives).
- **Layout, States & Assets:** Avoid centered hero for `DESIGN_VARIANCE > 4`; enforce **Shape Consistency Lock**; pass WCAG AA Button/Form Contrast, **CTA Wrap Ban**, and **No Duplicate CTA Intent**. Keep Hero in initial viewport (`pt-24` max, <=4 text elements, logo wall below hero), single-line nav <=80px, max 1 eyebrow per 3 sections, no split-headers, >=4 layout families per 8 sections, zigzag cap <=2. Visuals: image-gen -> Picsum/real assets -> explicit `<!-- TODO -->` slots (no div fake screenshots). Audit all visible copy; lock one Page Theme (Section 4.11).
- Full directives, banned hex lists, serif pool & spec-sheet alternatives (4.1?4.11): [references/design-details.md](references/design-details.md#4-design-engineering-directives-bias-correction).

## 5. CONTEXT-AWARE PROACTIVITY & 6. GUARDRAILS

- **Motion & Proactivity:** Animate only `transform`/`opacity`; honor `prefers-reduced-motion` when `MOTION_INTENSITY > 3`. Every animation must be motivated; **Marquee max-one-per-page**; GSAP Sticky-Stack/Horizontal-Pan must pin at `start: "top top"`. **NEVER** use `window.addEventListener("scroll")`, `window.scrollY` state, or `rAF` touching React state.
- **Performance & Dual Mode:** Target LCP <2.5s, INP <200ms, CLS <0.1; grain only on `fixed pointer-events-none`; systemic z-index scale; support light + dark mode unless instructed otherwise (no pure `#000000`/`#ffffff`).
- Full TSX skeletons (5.A?5.C), guardrails (6.A?6.F), dial definitions (7), and Dark Mode Protocol (8): [references/design-details.md](references/design-details.md#5-context-aware-proactivity).

## 9. AI TELLS (Forbidden Patterns)

Banned defaults: outer neon glows, pure `#000000`, custom cursors, 3-equal feature cards, "Jane Doe"/Acme/99.99%/filler-verb copy, div fake screenshots, hero version eyebrows (`V0.6`, `BETA`), numbered eyebrows (`00 / INDEX`), excessive `?`, decorative status dots, rotated vertical text, poetic headings ("Field notes", "Quietly in use at"), weather/locale strips, scroll cues, photo overlay pills, version footers, hero bottom strips, floating top-right sub-text, `border-t`+`border-b` spec rows, and filled comparison progress bars. Full catalog (9.A?9.F): [references/design-details.md](references/design-details.md#9-ai-tells-forbidden-patterns).

### 9.G EM-DASH BAN (the single most-violated Tell)

**Em-dash (`—`) is COMPLETELY banned.** It is the LLM's signature stylistic crutch and it is the #1 visual Tell in production tests. There is no "limited use" allowance, no "natural language frequency" allowance, no "in body copy is fine" allowance. None.

* **Banned in headlines.** Use a period or a comma.
* **Banned in eyebrows / labels / pills / button text / image captions / nav items.** Replace with line breaks, columns, or hairlines.
* **Banned in body copy.** Restructure the sentence: two sentences with a period, OR a comma, OR parentheses, OR a colon.
* **Banned in quote attribution.** Use a normal hyphen with spaces (` - `) or a line break + smaller-weight name.
* **Banned in en-dash form too (`–`) when used as a separator.** Date ranges (`2018-2026`) use a hyphen. Number ranges (`€40-80k`) use a hyphen.

The ONLY permitted dash characters on the page are:
* Regular hyphen `-` (for compound words, ranges, line dividers in markup)
* Minus sign in math (`-5°C`)

If your output contains a single `—` or `–` anywhere visible to the user, the output fails the Pre-Flight Check and must be rewritten.

This rule is non-negotiable. The agent has historically ignored em-dash limits when phrased as "use sparingly." The phrasing here is binary: zero em-dashes.


## 10. VOCABULARY, 11. REDESIGN & 12. BLOCK LIBRARY

- **10. Reference Vocabulary:** Hero/nav/layout/card/scroll/gallery/text patterns; never mix GSAP/Three.js with Motion in the same tree.
- **11. Redesign Protocol:** Detect mode (Greenfield / Preserve / Overhaul), audit tokens/IA/SEO first, modernize in order (Type -> Spacing -> Color -> Motion -> Hero -> Blocks), never silently alter URLs, nav labels, form fields, logos, or legal copy (also see [redesign.md](redesign.md)).
- **12. Block Library Contract:** Standalone block schema under `blocks/<category>/<name>.md`.
- Full catalogs & checklists (10?12): [references/design-details.md](references/design-details.md#10-reference-vocabulary-pattern-names-the-agent-should-know).

---

## 13. OUT OF SCOPE

This skill is NOT for:
* Dashboards / dense product UI / admin panels (use Fluent, Carbon, Atlassian, or Polaris from Section 2.A).
* Data tables (use TanStack Table or AG Grid).
* Multi-step forms / wizards (use Form-specific patterns; this skill won't make them better).
* Code editors (use Monaco / CodeMirror with their official skinning).
* Native mobile (use Apple HIG / Material directly).
* Realtime collab UIs (presence, cursors, OT-aware - different problem class).

If the brief is one of the above, **say so explicitly**, point to the right tool, and only apply this skill's marketing-page / about-page / landing-page parts to the surfaces where they apply.

---

## 14. FINAL PRE-FLIGHT CHECK

Run this matrix before outputting code. This is the last filter.

**THIS IS NOT OPTIONAL. Run every box. If any box fails, the output is not done.**

- [ ] **Brief inference** declared (Section 0.B one-liner)?
- [ ] **Dial values** explicit and reasoned from the brief, not silently using baseline?
- [ ] **Design system** chosen from Section 2 if applicable, or aesthetic labeled honestly?
- [ ] **Redesign mode** detected and audit performed (if applicable, Section 11)?
- [ ] **ZERO em-dashes (`—`) anywhere on the page.** Headlines, eyebrows, pills, body, quotes, attribution, captions, buttons, alt text. Zero. (Section 9.G - non-negotiable.)
- [ ] **Page Theme Lock**: ONE theme (light, dark, or auto) for the whole page. No section flips to inverted mode mid-page (Section 4.11)?
- [ ] **Color Consistency Lock**: one accent color used identically across all sections (Section 4.2)?
- [ ] **Shape Consistency Lock**: one corner-radius system applied consistently (Section 4.4)?
- [ ] **Button Contrast Check**: every CTA text is readable against its background (no white-on-white, WCAG AA 4.5:1)?
- [ ] **CTA Button Wrap**: no CTA label wraps to 2+ lines at desktop?
- [ ] **Form Contrast Check**: form inputs, placeholders, focus rings, labels all pass WCAG AA against the section background?
- [ ] **Serif discipline**: if a serif is used, it is NOT Fraunces or Instrument_Serif (or it is, with explicit brand justification)? Different serif from your previous project?
- [ ] **Premium-consumer palette check**: if the brief is premium-consumer (cookware / wellness / artisan / luxury), the palette is NOT the AI-default beige+brass+oxblood+espresso family? Different family from your previous premium-consumer project?
- [ ] **Italic descender clearance**: every italic word with `y g j p q` has `leading-[1.1]` min + `pb-1` reserve?
- [ ] **Hero fits the viewport**: headline ≤ 2 lines, subtext ≤ 20 words AND ≤ 4 lines, CTA visible without scroll, font scale planned around image?
- [ ] **Hero top padding**: max `pt-24` at desktop, hero content does not float halfway down the viewport?
- [ ] **Hero stack discipline**: max 4 text elements in hero (eyebrow OR brand strip, headline, subtext, CTAs)? No tiny tagline below CTAs, no trust micro-strip in hero?
- [ ] **EYEBROW COUNT (mechanical)**: count instances of `uppercase tracking` micro-labels above section headlines across all components. Count ≤ ceil(sectionCount / 3)? Hero counts as 1.
- [ ] **Split-Header Ban**: no "left big headline + right small explainer paragraph" pattern as a section header (vertical stack instead)?
- [ ] **Zigzag Alternation Cap**: no 3+ consecutive sections with the same image+text-split layout?
- [ ] **No Duplicate CTA Intent**: no two CTAs with the same intent ("Get in touch" + "Let's talk" both on page = Fail)?
- [ ] **Logo wall = logo only**: no industry / category labels printed below logos?
- [ ] **Bento Background Diversity**: at least 2-3 bento cells have real visual variation (image, gradient, pattern), not all white-on-white text cards?
- [ ] **"Used by / Trusted by" logo wall** lives UNDER the hero, not inside it, uses REAL SVG logos (Simple Icons / devicon) or generated SVG marks, NOT plain text wordmarks?
- [ ] **Copy Self-Audit**: every visible string re-read, no grammatically-broken or AI-hallucinated phrases ("free on its past" type) shipped?
- [ ] **Motion motivated**: every animation can be justified in one sentence (hierarchy / storytelling / feedback / state transition), no GSAP-for-show?
- [ ] **Marquee max-one-per-page**: no two horizontal marquees on the same page?
- [ ] **Navigation on ONE line** at desktop, height ≤ 80px?
- [ ] **Section-Layout-Repetition** check: no two sections share the same layout family (at least 4 different families across 8 sections)?
- [ ] **Bento has rhythm AND exact cell count** (N items → N cells, no empty cells in middle or at end)?
- [ ] **Long lists use the right UI component** (not default `<ul>` with `divide-y` for > 5 items - see Section 4.9 alternatives)?
- [ ] **Real images used** (gen-tool first, then Picsum-seed, then explicit placeholder slots) - NO div-based fake screenshots, NO hand-rolled decorative SVGs, NO pure-text minimalism?
- [ ] **No pills/labels overlaid on images** (no `Plate · Brand`, no `Field notes - journal`)?
- [ ] **No photo-credit captions as decoration** (`Field study no. 12 · Ines Caetano`)?
- [ ] **No version footers** (`v1.4.2`, `Build 0048`) on marketing pages?
- [ ] **No micro-meta-sentences** under eyebrows ("Each of these is a feature we ship today...")?
- [ ] **No decoration text strip at hero bottom** (`BRAND. MOTION. SPATIAL.`)?
- [ ] **No floating top-right sub-text** in section headings?
- [ ] **No scoring/progress bars with filled background tracks** as comparison visuals?
- [ ] **No locale / city-name / time / weather strips** unless brief is genuinely globally-distributed or place-focused?
- [ ] **No scroll cues** (`Scroll`, `↓ scroll`, `Scroll to explore`)?
- [ ] **No version labels in hero** (V0.6, BETA, INVITE-ONLY) unless the brief is a launch?
- [ ] **No section-numbering eyebrows** (`00 / INDEX`, `001 · Capabilities`, `06 · how it works`)?
- [ ] **No decorative dots** (zero by default, only for real semantic state)?
- [ ] **No `border-t` + `border-b` on every row** of long lists / spec tables?
- [ ] **Content density** sane: no 20-row data tables, no fake-precise specs without justification, ≤ 25-word sub-paragraphs by default?
- [ ] **Quotes ≤ 3 lines** of body, attribution clean (no em-dash)?
- [ ] **Motion claimed = motion shown**: if `MOTION_INTENSITY > 4`, page actually animates, not just claimed?
- [ ] **GSAP sticky-stack / horizontal-pan** implemented per Section 5.A / 5.B canonical skeleton (`start: "top top"`, `pin: true`, correct scrub)?
- [ ] **No `window.addEventListener('scroll')`** - using Motion `useScroll()` / ScrollTrigger / IntersectionObserver / CSS scroll-driven animations only?
- [ ] **Reduced motion** wrapped for everything `MOTION_INTENSITY > 3`?
- [ ] **Dark mode** tokens defined and tested in both modes?
- [ ] **Mobile collapse** explicit (`w-full`, `px-4`, `max-w-7xl mx-auto`) for high-variance layouts?
- [ ] **Viewport stability**: `min-h-[100dvh]`, never `h-screen`?
- [ ] **`useEffect` animations** have strict cleanup functions?
- [ ] **Empty / loading / error** states provided?
- [ ] **Cards omitted** in favor of spacing where possible?
- [ ] **Icons** from an allowed library only (Phosphor / HugeIcons / Radix / Tabler), no hand-rolled SVG paths?
- [ ] **Motion** isolated in client-leaf components with `'use client'` at the top, memoized?
- [ ] **No AI Tells** from Section 9 (Inter as default, AI-purple, three-equal cards, Jane Doe, Acme, "Quietly in use at")?
- [ ] **Core Web Vitals** plausibly hit (LCP < 2.5s, INP < 200ms, CLS < 0.1)?
- [ ] **One design system** per project (no Material + shadcn mixed)?

If a single checkbox cannot be honestly ticked, the page is not done. Fix it before delivering.

---


---

## APPENDICES - Real Source-Backed Reference Material

Full install commands per design system (**Appendix A**), canonical official docs (**Appendix B**), and the labeled **Apple Liquid Glass** web approximation CSS (**Appendix C**) live in [references/design-details.md](references/design-details.md#appendices---real-source-backed-reference-material).

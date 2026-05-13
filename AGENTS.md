# AGENTS.md

## Developer Commands

```bash
npm run build      # tsc + postbuild: chmod +x dist/index.js
npm run watch      # tsc --watch
npm run dev        # tsx watch src/index.ts (hot reload, no build needed)
npm run lint       # eslint src
npm run lint:fix   # eslint src --fix
npm run format     # prettier --write src
npm run format:check
npm run check      # format:check -> lint -> build (run before commits)
npm test           # NOT a test runner — runs `tsx src/index.ts` (smoke test the server)
```

- `npm install` triggers `prepare` → auto-runs `npm run build`
- `npm run dev` uses `tsx` (TypeScript executor) — no build step needed for dev

## TypeScript & Lint Rules

- **Strict mode** in `tsconfig.json`; no `any` (`@typescript-eslint/no-explicit-any: error`)
- **DOM types** (`"lib": ["ES2022", "DOM", "DOM.Iterable"]`) — intentional for Patchright in-page DOM evaluations
- **Prefer `const`** (`prefer-const: error`), **always `===` / `!==`** (`eqeqeq: error`)
- **Consistent type imports** enforced (`consistent-type-imports: warn`, `prefer: "type-imports"`)
- **No `console.log`** — `no-console: warn`; `console.error` is allowed. Off for `src/utils/cli-handler.ts` and `src/cli/**/*.ts`
- Unused vars allowed if prefixed with `_` (`varsIgnorePattern: "^_"`)

## Architecture

- **Entry point**: `src/index.ts` — CLI arg parsing, MCP wiring, transport selection
- **Tool definitions**: `src/tools/definitions/*.ts` (modular by category: ask-question, notebook-management, session-management, sources, system)
- **Tool handlers**: `src/tools/handlers.ts` — all tool implementation logic
- **Tool definitions builder**: `src/tools/definitions.ts` — aggregates definitions, injects dynamic library context into `ask_question` description
- **MCP SDK**: `@modelcontextprotocol/sdk` (v1.x)
- **Browser automation**: Patchright (stealth builds + persistent Chrome profile)
- **Transports**: stdio (default) + Streamable-HTTP (`src/transport/http.ts`)
- **Server instructions**: `SERVER_INSTRUCTIONS` in `src/index.ts:59` — MCP-spec instructions consumed by clients at init; key cross-tool workflow guidance (first-run flow, session ID flow, audio async chain)
- **Config priority**: env vars > `settings.json` (`<configDir>/settings.json`) > built-in defaults. No config file otherwise. `.env` at repo root loaded automatically by `dotenv`
- **CLI subcommand**: `npx notebooklm-mcp config (get|set|reset)` manages profile/disabled-tools before the server starts

## Directory Ownership

| Directory | Purpose |
|-----------|---------|
| `src/auth/` | Auth manager, account switcher |
| `src/browser/` | Chromium fallback, watchdog |
| `src/library/` | Local notebook library (JSON at `<dataDir>/library.json`) |
| `src/notebooklm/` | DOM selectors, chat, citations, audio, sources |
| `src/resources/` | MCP resource handlers (`notebooklm://library`, etc.) |
| `src/session/` | Browser session manager |
| `src/tools/` | Tool definitions + handlers |
| `src/transport/` | HTTP transport (Node stdlib `http`, no Express) |
| `src/utils/` | Settings, logger, CLI handler, cleanup, disclaimer |

## Config & Environment

- **All config via env vars** — see `docs/configuration.md` for full reference
- Persistent profile/disabled-tools state: `<configDir>/settings.json` (managed via `config` CLI subcommand)
- `NOTEBOOKLM_PROFILE` env var overrides `settings.json` profile without persisting
- `NOTEBOOKLM_DISABLED_TOOLS` CSV env var merges with persisted disabled list
- Default viewport: **1920×1080** — NotebookLM switches to mobile tab layout below ~1280px, breaking selectors
- Browser channel: `chrome` (system) by default, `chromium` forces bundled Patchright build
- Headless Linux: `setup_auth` needs a display; run once under `xvfb-run`, subsequent runs go fully headless

## Prettier Config

- Semicolons: yes, Quotes: double, Trailing comma: es5, Print width: 100, End of line: LF (watch for CRLF on Windows)

## Operational Gotchas

- `setup_auth` + `re_auth` accept `show_browser` (bool) or `browser_options.show`
- `generate_audio` is **non-blocking** by default — poll `get_audio_status` every ~30s, then call `download_audio`
- 5-second shutdown watchdog prevents orphan Chrome processes (`src/index.ts:464`)
- `NOTEBOOK_PROFILE_STRATEGY=auto` (default) creates isolated profile copies when base is locked; set `single` or `isolated` to control explicitly
- Free Google accounts: 50 NotebookLM queries/day — `re_auth` or `--account` to rotate
- **No test suite** — only manual smoke testing via `npm run dev`
- `Old_Python_Vesion/` excluded from TypeScript/ESLint — legacy artifact

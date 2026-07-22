# file-agents

Mastra-style, file-based agent definitions for the [Pi coding agent](https://github.com/mariozechner/pi-coding-agent). Define named agents on disk and activate one at a time inside a Pi session with `/agents`.

Zero external dependencies: the extension imports only Node builtins and Pi-provided modules (`@mariozechner/pi-coding-agent`, `@mariozechner/pi-tui`, `typebox`). Mastra is **not** installed or imported — only its on-disk conventions are mirrored.

## What activating an agent does

- Appends the agent's `instructions.md` to the system prompt, per turn, live (via `before_agent_start`).
- Switches Pi's model to the agent's `model` (if declared and available).
- Registers the agent's `tools/` as namespaced Pi tools and restricts the active tool set to the agent's allow-list.
- Contributes the agent's `skills/` to Pi's native skill engine (`/skill:` + progressive disclosure) via `resources_discover`.
- Exposes each `subagents/<id>/` as a delegation tool that spawns a scoped `pi` subprocess.

## Agent definition layout

Agents are discovered from two roots:

| Scope | Location | Trust |
|---|---|---|
| Global | `~/.pi/agent/agents/<id>/` | trusted |
| Project | `<cwd-or-ancestor>/.pi/agents/<id>/` | confirmed before first activation |

A directory qualifies as an agent only if it contains `config.json` (flat `*.md` files under `agents/`, used by Pi's native subagents, are ignored).

```
<agent-id>/
├── config.json                 required
├── instructions.md             required unless config.instructions is set
├── tools/                      optional — flat only, one Pi ToolDefinition per file
│   └── <tool_id>.ts|.js|.mjs
├── skills/                     optional — Pi native skill files
│   ├── <name>.md               flat: name + description frontmatter
│   └── <name>/SKILL.md         packaged: + references/, assets/
└── subagents/                  optional — one level, same dir shape
    └── <sub-id>/
        ├── config.json         description REQUIRED
        └── instructions.md
```

Discovery rules (mirrored from Mastra): agent id = directory name unless `config.id`; tool id = filename without extension; symlinks skipped everywhere; `*.test.*` / `*.spec.*` skipped under `tools/`; `tools/` is flat (no recursion). Tool files may be `.ts`, `.js`, or `.mjs` (`.js`/`.mjs` are the no-jiti fallback).

## `config.json`

```jsonc
{
  "id":            "researcher",                  // optional; default = dir name
  "name":          "Researcher",                  // optional; display only
  "description":   "Fast recon…",                 // required ONLY for subagents
  "model":         "anthropic/claude-sonnet-4-5", // optional "provider/model-id"; omitted = keep current
  "instructions":  "…",                           // optional inline; overrides instructions.md
  "thinkingLevel": "medium",                      // optional: off|minimal|low|medium|high|xhigh
  "tools":         ["search", "fetch"],           // optional allow-list of discovered tool ids; omitted = all
  "builtinTools":  ["read", "grep"]               // optional; omitted = all builtins; [] = none
}
```

`instructions.md` is plain Markdown, applied verbatim per turn (no frontmatter, no templating).

Tool files are Pi `ToolDefinition` modules with a default export:

```ts
import { Type } from "typebox";
import { defineTool } from "@mariozechner/pi-coding-agent";

export default defineTool({
  name: "echo",
  label: "Echo",
  description: "Echo back the input",
  parameters: Type.Object({ text: Type.String() }),
  async execute(_id, params) {
    return { content: [{ type: "text", text: params.text }], details: {} };
  },
});
```

The tool's model-facing name is namespaced to `<agentId>__<toolId>`; the filename wins as the id.

Skills use Pi's native `SKILL.md` format. Pi requires both `name` (matching the file/dir) and `description` in frontmatter; Mastra requires only `description`, so add a one-line `name:`.

## `/agents` command

| Invocation | Behavior |
|---|---|
| `/agents` | Selector of every discovered agent; the active one is marked. A `— none —` entry deactivates. |
| `/agents <id>` | Activates `<id>` directly. Disambiguate cross-scope collisions with `<id>@global` / `<id>@project`. |
| `/agents none` | Deactivates: restores the full built-in tool set, leaves the model unchanged. |

While an agent is active a status entry (`agent: <id>`) and an `aboveEditor` widget (`⌾ <id> · <model> · N tools · M skills`) are shown. All UI is gated behind `ctx.hasUI`, so print/JSON mode is silent.

The active choice is persisted as a session entry (`file-agents/active`) and rehydrated on `session_start` by scanning the branch, so `/fork`, `/resume`, `/reload`, and branch navigation reconstruct the correct active agent. `/new` starts with no active agent.

## Mastra → Pi mapping

| Mastra concept | file-agents / Pi realization |
|---|---|
| `src/mastra/agents/<id>/` discovery | `~/.pi/agent/agents/<id>/` (global) + `<project>/.pi/agents/<id>/` (project) |
| `config.ts` (`agentConfig()`) | `config.json` (parsed with `node:fs` + `JSON.parse`; no TS eval) |
| `config.model` (required) | `config.model` optional `"provider/id"` → `modelRegistry.find` + `setModel` |
| `config.instructions` (string/fn) | `config.instructions` string only (no dynamic fn form) |
| `instructions.md` (build-time inline) | applied per turn via `before_agent_start` (hot) |
| `tools/*.ts` = `createTool()` | `tools/*.{ts,js,mjs}` = Pi `ToolDefinition` (TypeBox), dynamic-imported, registered `<id>__<tool>` |
| filename = tool id | preserved; model-facing name namespaced to avoid cross-agent collisions |
| `config.tools` object-merge / fn-disable | `config.tools` = allow-list of ids via `setActiveTools` (no merge/fn semantics — JSON) |
| `skills/*.md`, `<name>/SKILL.md` | contributed to Pi native skills via `resources_discover` (on-demand + `/skill:`) |
| skill `createSkill()` TS module | not supported (would need TS eval) — use markdown skill forms |
| `subagents/<id>/` = delegation tool | `subagents/<id>/` → delegation tool spawning `pi --mode json -p --no-session …` (v1: single-task, 1 level) |
| subagent `description` required | required in sub `config.json` (delegation-tool description) |
| no inheritance to subagents | preserved (each subagent self-contained) |
| symlinks skipped / test files ignored | preserved exactly |
| `config.thinkingLevel` | `setThinkingLevel` (Pi extra; not a Mastra field) |
| `memory`, `workspace`, `processors`, `scorers`, `defaultOptions`, `maxRetries`, storage, observability | out of scope — no Pi analogue; silently ignored so a shared Mastra repo still loads |

## Error handling

The extension never crashes Pi. Discovery skips unreadable dirs; a malformed `config.json` skips that agent; a throwing tool file is skipped with a warning while the rest of the agent activates; a missing/unavailable model keeps the current one; a failing subagent returns a clean error result; every event handler wraps its body in `try/catch` and returns a neutral value.

## Deferred (v1 scope)

Subagent parallel/chain modes and nesting beyond one level are out of scope for v1.

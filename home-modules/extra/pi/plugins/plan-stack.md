# plan-stack.ts — /btw aside agent (+ parked /plan stack)

Design and handoff notes for `home-modules/extra/pi/plugins/plan-stack.ts`.
Read this before editing the file; the in-file header covers the same ground
in shorter form.

## Shipped surface

`/btw <text>` — opens a **centered overlay popup** (`ctx.ui.custom` with
`{ overlay: true, overlayOptions: { anchor: "center", width: "66%" } }`).
The popup owns input while open (focused overlay): typing fills the chat
box, `enter` sends, `↑↓`/wheel scroll the transcript (2/3-line steps,
PageUp/PageDown 8-line), `escape` closes — **esc kills the child process,
removes the temp dir, and closes**. There is no exit button.

Each turn spawns a one-shot read-only child:

```
pi --mode json -p --no-session \
  -e  <tmpDir>/plan-bridge.ts \
  --tools read,grep,find,ls[,plan_add_step] \
  --append-system-prompt <tmpDir>/system-prompt.md \
  "<question or history-primed follow-up>"
```

- Follow-ups spawn a **new child** per turn; prior exchanges are re-primed
  into the prompt (last 3 kept).
- NDJSON events parsed on stdout: `tool_execution_start/end` drive the
  status-colored dot rows (yellow ● ok, red ● error, animated braille in
  flight, capitalized tool names, one-cell result summaries);
  `message_end` (assistant) captures the reply; `agent_end` finalizes the
  turn. Reply is markdown-rendered (cached per text in `mdCacheMap`).
- `esc` mid-run sends SIGTERM to the child (`currentProc`).

## Main-chat context

`mainContextBlock(ctx)` inlines a trimmed main-session transcript into the
child's system prompt, **recomputed every turn**. Contents: user text,
assistant thinking, assistant tool calls (with one-cell arg summaries via
`argSummary`), tool-result first lines. **Age-tiered clip budgets**:

| tier | age (items) | user/text | thinking | tool args | results |
|---|---|---|---|---|---|
| recent | last 12 | 400 | 500 | 120 | 120 |
| middle | 13–30 | 200 | 150 | 80 | 60 |
| ancient | 31+ | 120 | dropped | 60 (arg stub) | dropped |

Rationale: recent thinking is the highest-value content (answers "why did
you do it that way"); ancient results are noise; ancient tool-call args are
dense signal and survive as stubs. Whole-line cap 8000 chars, dropping
oldest *entire lines* (never mid-sentence), with an explicit
`… N earlier items omitted` marker.

## Plan tool (bridge)

`plan_add_step` is registered into the child **only while a plan is active**
(`goal` set via `/plan`; the child simply lacks the tool otherwise — it
cannot mutate the plan, not just "is told not to").

Mechanism: the child can't call into our process, so `BRIDGE_EXT` (a
template-literal source written to `<tmpDir>/plan-bridge.ts` and `-e`-loaded)
registers `plan_add_step`, which appends `{"step": "..."}` JSON lines to
`PI_PLAN_BRIDGE_FILE` (env). The popup's 80 ms tick polls that file
(`pollBridge`) and applies pushes: `stack.unshift(..., pushed: true)` + a
`◆ queued at front of plan` sys row + a `btw-note` breadcrumb entry.

**Breadcrumbs only for plan mutations.** Question-asides leave no
transcript trace at all.

## /btw's design language

Yellow (base0A) = /btw identity: border, ◈ header, spinner, user rail, ●
dots, `◆` queued marker. Red (base08) = failed calls. Cyan = plan/next
(parked). No background band (base01 bands are reserved for user follow-up
rows). No prefixes on replies. Blank lines bracket each user message.

## PARKED: the /plan stack

Unregistered in the "shipped" cut. The designed lifecycle, ready to revive:

1. `/plan <goal>` → agent gets one conversational turn to propose steps →
   steps land as `▹` (proposed, numbered), phase `ready`.
2. `/plan go` → phase `running`, front `▹` becomes `▶`. The only gate.
3. Execution: agent completes steps via the `plan_stack` tool (not yet
   built) or user `/plan done`; `/btw` work-asides push `▲` to the front.
4. Empty stack → wrap-up. `/plan off` clears everything.

Still mock even when revived: seeded demo steps, no session persistence
(plan state should move to session custom entries, rebuilt on
`session_start`), no `plan_stack` tool for the main agent.

Widget state that revives with it: `phase` (currently frozen at
`"running"` — the `phase === "ready"` ▹ branch in `widgetLines` is dead),
`doneCount` (never increments without `/plan done`), `ensureSeeded`
(removed with the command; bring back a real drafting turn instead).

## Dead-code inventory (while /plan is parked)

- `phase` frozen at `"running"`; `phase === "ready"` ▹ branch in
  `widgetLines` unreachable (annotated in-file).
- `Pending["plan"]` kind + the `kind === "plan"` branch in `startPending`
  unreachable (annotated in-file).
- `startPending`/`fakeCard`/`fakeReply` are the **non-TUI fallback**
  (print/json modes can't open the popup) — fake data, not a real path.
- alt+a / alt+x shortcuts and the widget-anchored aside panel were removed
  when the popup became the aside surface; don't reintroduce them.

## Gotchas (learned the hard way)

- Measure with `visibleWidth` (pi-tui's, re-exported via
  `visibleLen`), never `.length` after a naive strip — OSC/APC escapes and
  ambiguous-width glyphs (`—`, `▌`, `▌`) desync borders.
- The user rail `▎` is placed at a **known 1-cell width**, never measured.
- No RESET inside a colored span: an embedded RESET kills the active color
  *and* any band bg; re-apply the color after every embedded RESET (see
  the rule builders).
- The banded user row keeps `USER_BG` open until the row's final RESET —
  `userRail` intentionally has no trailing RESET.
- Command args: subcommands are first-token verbs; `add` was deliberately
  dropped (plain chat + the plan tool cover it).
- `/btw` must not call `ensureSeeded`-style plan fabrication — it works
  plan-less by design.

## Gates

- Typecheck: `./result/bin/tsc --noEmit -p tsconfig.json` (result symlink
  → typescript), diff against the pre-change baseline — only new errors
  count (custom-ui.ts has baseline noise under newer tsc).
- Headless e2e recipe: stub `ctx.ui.custom` to invoke the factory with a
  fake `{ requestRender }` TUI, drive `overlay.handleInput("<raw keys>")`
  (`"\r"`, `"\x1b[B"`, `"\x1b[<64;…M"` wheel, `"\x1b"`), inspect
  `overlay.render(width)` with SGR stripped (remember `\x1b_pi:c\x07`).
  Mock `sessionManager.getBranch()` for context-block tests.

## Backlog

- Tool-call budget (~8/ask, from pi-btw-extension) to stop runaway
  investigations.
- `/btw:tangent` — contextless flag (skip `mainContextBlock`).
- Rolling side-thread summary instead of last-3-exchanges priming.
- Text streaming into the popup (`message_update` text_delta) instead of
  reply-at-turn-end.
- Plan state persistence via session custom entries.
- The parked `/plan`, if wanted — build it fresh, not on the mock remnants.

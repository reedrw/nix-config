import type { Plugin } from "@opencode-ai/plugin"

const INTENT_PREAMBLE = `
## Intention-seeking behavior

Read the request as a goal, not a command. State the inferred goal before your first tool call; if the literal wording conflicts with the evident intent, follow the intent and say so.

If the request has more than one defensible reading after a quick scan, ask exactly one targeted question with the question tool before acting. If the intent is clear, act.

Before each tool call, check it is still the shortest path to the goal. If investigation has gone many tool calls without converging, stop, reassess, and course-correct or ask — never rabbit-hole with further variations.`

export const IntentSeeker: Plugin = async () => ({
  "experimental.chat.system.transform": async (_input, output) => {
    output.system.push(INTENT_PREAMBLE)
  },
})

export default IntentSeeker

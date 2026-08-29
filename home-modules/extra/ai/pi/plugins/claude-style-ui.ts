// claude-style-ui: Claude Code inspired rendering for pi's built-in tools.
//
// One-line calls (`● edit src/foo.ts`), one-line result summaries
// (`⎿  +12 −3`, `⎿  42 lines`), no boxes — full output on demand via
// ctrl+o. The render slots live in lib/claude-style.ts and are shared with:
//   - nix-comma.ts, which owns `bash` (its registration installs the PATH
//     spawn hook that the bash tool needs) and adds the bash slots there
//   - image-history.ts, which owns `read` (it appends inline image cells)
// Tool names can only be registered by one extension, hence the split.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	createEditTool,
	createFindTool,
	createGrepTool,
	createLsTool,
	createWriteTool,
} from "@earendil-works/pi-coding-agent";
import { claudeStyleEnabled, edit, find, grep, ls, write } from "./lib/claude-style.ts";

export default function claudeStyleUi(pi: ExtensionAPI) {
	// With the style disabled, don't override anything — pi's built-in tools
	// (and their default rendering) stay in place.
	if (!claudeStyleEnabled()) return;
	// Original tools are recreated per cwd at execute time (cached); the
	// registration itself only borrows description/parameters/prompt metadata
	// from the cwd at load time.
	const cache = new Map<string, Record<string, ReturnType<typeof createEditTool>>>();
	function builtins(cwd: string) {
		let tools = cache.get(cwd);
		if (!tools) {
			tools = {
				edit: createEditTool(cwd),
				write: createWriteTool(cwd),
				grep: createGrepTool(cwd),
				find: createFindTool(cwd),
				ls: createLsTool(cwd),
			};
			cache.set(cwd, tools);
		}
		return tools;
	}

	const slots = { edit, write, grep, find, ls } as const;
	for (const name of Object.keys(slots) as Array<keyof typeof slots>) {
		const original = builtins(process.cwd())[name]!;
		const slot = slots[name];
		pi.registerTool({
			...original,
			renderShell: slot.renderShell,
			renderCall: slot.renderCall,
			renderResult: slot.renderResult,
			async execute(toolCallId, params, signal, onUpdate, ctx) {
				return builtins(ctx.cwd)[name]!.execute(toolCallId, params, signal, onUpdate);
			},
		});
	}
}

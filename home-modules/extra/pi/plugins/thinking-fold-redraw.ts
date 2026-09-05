// thinking-fold-redraw: repaint shim for @99percentpeople/pi-thinking-fold.
//
// pi-thinking-fold consumes ctrl+t (app.thinking.toggle) in an onTerminalInput
// listener and mutates its folded-thinking components — but neither it nor pi
// schedules a repaint: pi's input loop returns early on consumed input, before
// the requestImmediateRender() that follows every unconsumed keypress. Result:
// the fold state changes but the screen doesn't update until the next key
// event (ctrl+o, scrolling, …).
//
// This extension loads before configured packages (global extensions are
// discovered before settings.json packages), so its input listener sees
// ctrl+t first. It never consumes; it just defers a requestRender — by the
// time the timeout fires, thinking-fold's synchronous toggle has already
// mutated the components. With thinking-fold absent, pi's own toggle repaints
// anyway and the extra frame is harmless.
//
// The TUI handle is captured through a zero-line widget (same trick as the
// statusline's footer capture; the UI context exposes no requestRender).

import { getKeybindings } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function thinkingFoldRedraw(pi: ExtensionAPI) {
	let tui: { requestRender(): void } | null = null;
	let scheduled = false;
	let removeInputListener: (() => void) | null = null;

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		// Zero-line widget: invisible, but its factory hands us the TUI.
		ctx.ui.setWidget("thinking-fold-redraw", (t) => {
			tui = t;
			return {
				render: () => [],
				invalidate() {},
				dispose() {
					tui = null;
				},
			};
		});

		// Re-registering on every session_start would stack listeners.
		removeInputListener?.();
		removeInputListener = ctx.ui.onTerminalInput((data) => {
			if (!tui || scheduled) return undefined;
			if (!getKeybindings().matches(data, "app.thinking.toggle")) return undefined;
			scheduled = true;
			setTimeout(() => {
				scheduled = false;
				tui?.requestRender();
			}, 0);
			return undefined;
		});
	});

	pi.on("session_shutdown", () => {
		removeInputListener?.();
		removeInputListener = null;
		tui = null;
	});
}

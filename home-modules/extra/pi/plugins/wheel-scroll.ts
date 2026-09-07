// wheel-scroll: configurable lines per mouse-wheel tick in fullscreen mode.
//
// pi constructs TuiAltScreen (tuiMode = "fullscreen") without a
// wheelScrollLines option, so pi-tui falls back to 1 line per tick — glacial
// next to tmux scrollback speed. pi exposes no setting for it, and the TUI
// handle widget factories receive is a getter-only proxy (writes land on the
// empty proxy target, never the TUI instance), so this used to be a
// postFixup sed on the dist file in pkgs/alias.nix. Prototype patch instead:
// extensions resolve @earendil-works/pi-tui to pi's own module instance via
// the loader's jiti alias table (same proof as the ToolExecutionComponent
// patches), so patching TuiAltScreen.prototype.routeWheel reaches the real
// fullscreen TUI.
//
// Configuration: `wheelScrollLines` in .pi/settings.json (project wins over
// global, same scope rules as the lib's customUiEnabled). The generated
// global settings.json sets it to 5 (home-modules/extra/pi/default.nix);
// re-read per event so hand edits to either scope apply without a restart.
//
// routeWheel computes `remaining = event.direction * this.wheelScrollLines`
// and direction is used nowhere else, so scaling the direction by N is
// exactly wheelScrollLines = N.
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { TuiAltScreen } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const WHEEL_PATCHED = Symbol.for("pi-custom-ui/wheel-scroll");
const DEFAULT_LINES_PER_TICK = 5;

function resolveWheelScrollLines(): number {
	for (const path of [
		join(process.cwd(), ".pi", "settings.json"),
		join(homedir(), ".pi", "agent", "settings.json"),
	]) {
		try {
			const settings = JSON.parse(readFileSync(path, "utf8")) as {
				wheelScrollLines?: unknown;
			};
			const value = settings.wheelScrollLines;
			if (typeof value === "number" && Number.isFinite(value) && value >= 1) {
				return Math.floor(value);
			}
		} catch {
			// Missing or unparsable — fall through to the next scope.
		}
	}
	return DEFAULT_LINES_PER_TICK;
}

export default function wheelScroll(_pi: ExtensionAPI) {
	const prototype = TuiAltScreen.prototype as unknown as Record<PropertyKey, unknown>;
	if (typeof prototype.routeWheel !== "function" || prototype[WHEEL_PATCHED]) return;
	prototype[WHEEL_PATCHED] = true;
	const originalRouteWheel = prototype.routeWheel as (
		this: unknown,
		event: { direction: number } & Record<string, unknown>,
	) => void;
	prototype.routeWheel = function (
		this: unknown,
		event: { direction: number } & Record<string, unknown>,
	) {
		return originalRouteWheel.call(this, {
			...event,
			direction: event.direction * resolveWheelScrollLines(),
		});
	};
}

// Desktop pet for pi — terminal-native fork of pi-dsh-pet (MIT,
// https://github.com/SOMWHY/pi-dsh-pet). Instead of an Electron overlay window,
// the pet is a kitty-graphics animation living in a pi widget above the prompt
// input: frames (precomputed by plugins/pet-assets/) are transmitted once over
// the kitty graphics protocol directly to stdout, kitty itself loops the
// animation (terminal-driven, zero CPU in pi), and the widget renders only a
// placement line. As real layout rows the widget never obscures output —
// unlike an overlay, whose band is padded with spaces over the transcript.
//
// Commands:
//   /pet [small|normal|large]  — show the pet (above the prompt input)
//   /pet-stop                  — close it
//
// Requires fullscreen mode and a kitty-graphics terminal (kitty, Ghostty,
// WezTerm, Warp). Works inside tmux (`allow-passthrough on`) via the stdout
// filter in lib/pet/tmux.ts.

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	allocateImageId,
	getCapabilities,
	getCellDimensions,
	renderImage,
	type Component,
	type TUI,
	type TuiMouseEvent,
} from "@earendil-works/pi-tui";
import {
	CODING_TOOLS,
	codingAnim,
	pickClick,
	pickIdleChain,
	thinkingAnim,
	type PetState,
} from "./lib/pet/anim.ts";
import { buildTransmitSequence, deleteImageLine, placementLine } from "./lib/pet/kitty.ts";
import { installTmuxPassthrough, outerTerminalHasKittyGraphics } from "./lib/pet/tmux.ts";

// ---- Assets (installed as ~/.pi/agent/extensions/pet-assets/) ----
const ASSETS_DIR = join(dirname(fileURLToPath(import.meta.url)), "pet-assets");

interface AnimMeta {
	frames: number;
	fps: number;
	width: number;
	height: number;
}

let manifest: Record<string, AnimMeta> | null = null;
const frameCache = new Map<string, string[]>();

function loadManifest(): Record<string, AnimMeta> {
	if (!manifest) {
		manifest = JSON.parse(readFileSync(join(ASSETS_DIR, "manifest.json"), "utf8")) as Record<
			string,
			AnimMeta
		>;
	}
	return manifest;
}

function availableAnims(): Set<string> {
	return new Set(Object.keys(loadManifest()));
}

function loadFrames(name: string): string[] {
	let frames = frameCache.get(name);
	if (!frames) {
		const meta = loadManifest()[name];
		if (!meta) throw new Error(`pet: unknown animation ${name}`);
		frames = [];
		for (let i = 1; i <= meta.frames; i++) {
			const file = join(ASSETS_DIR, name, `f${String(i).padStart(4, "0")}.png`);
			frames.push(readFileSync(file).toString("base64"));
		}
		frameCache.set(name, frames);
	}
	return frames;
}

// ---- Sizes ----
// Height-driven (rows): the frames are cropped to the character's bounding
// box, so the pet's aspect varies per animation — the width is derived from
// the target height and the animation's own aspect in play().
const SIZE_ROWS: Record<string, number> = { small: 6, normal: 9, large: 12 };
const MAX_COLS = 48;

// ---- Widget component ----
class PetWidget implements Component {
	private tui: TUI;
	private requestRender: () => void;
	private targetRows: number;

	private line: string | null = null;
	private sizeCols = 1;
	private sizeRows = 1;
	private imageId: number | null = null;
	private currentAnim: string | null = null;
	private animEndsAt = 0;
	private state: PetState = "idle";
	/** One-shot interaction animation (click response) currently playing. */
	private interaction: string | null = null;
	private available = availableAnims();
	private disposed = false;

	private timer: ReturnType<typeof setInterval> | null = null;
	private onResize: () => void = () => {};

	constructor(tui: TUI, requestRender: () => void, targetRows: number) {
		this.tui = tui;
		this.requestRender = requestRender;
		this.targetRows = targetRows;

		this.timer = setInterval(() => this.tick(), 250);
		this.timer.unref?.();

		// Terminal resize: pi's full redraw repaints our placement line at the
		// new center, but the old kitty placement stays put (images survive
		// clears and pi doesn't manage ours). Replay the current
		// animation with a fresh image id — the transmit deletes the old one.
		this.onResize = () => {
			if (this.currentAnim) this.play(this.currentAnim, true);
		};
		process.stdout.on("resize", this.onResize);

		// First animation: something from the idle chain (usually breathing).
		const first = pickIdleChain(this.available) ?? Object.keys(this.available)[0];
		if (first) this.play(first);
	}

	/** Switch animations. Same-name calls are ignored (no retransmit) unless forced. */
	private play(name: string, force = false): void {
		if (this.disposed || (!force && name === this.currentAnim) || !this.available.has(name)) return;
		const meta = loadManifest()[name]!;
		const frames = loadFrames(name);
		const gapMs = Math.round(1000 / meta.fps);
		const id = allocateImageId();
		// Height-driven placement size: rows = target, cols from the animation's
		// own cropped aspect (real cell dimensions — cells are ~2:1).
		const cell = getCellDimensions();
		const cols = Math.min(
			MAX_COLS,
			Math.max(
				1,
				Math.ceil((meta.width * this.targetRows * cell.heightPx) / meta.height / cell.widthPx),
			),
		);
		// renderImage registers the kitty metadata pi's renderer needs for its
		// placement cache; the sequence it builds is discarded — transmission
		// happens below, outside pi's render pipeline.
		const rendered = renderImage(frames[0]!, { widthPx: meta.width, heightPx: meta.height }, {
			imageId: id,
			maxWidthCells: cols,
			maxHeightCells: this.targetRows,
			moveCursor: false,
		});
		const sizeCols = rendered?.columns ?? cols;
		const sizeRows = rendered?.rows ?? this.targetRows;
		// Transmit + start the loop OUTSIDE pi's render pipeline. The widget
		// line is placement-only, so pi's repaints never retransmit frames — a
		// retransmitted image id is deleted and re-created by kitty, which
		// resets the animation to frame 1 on every repaint.
		process.stdout.write(
			buildTransmitSequence({ imageId: id, frames, gapMs, prevImageId: this.imageId ?? undefined }),
		);
		this.imageId = id;
		this.sizeCols = sizeCols;
		this.sizeRows = sizeRows;
		this.line = placementLine(id, sizeCols, sizeRows);
		this.currentAnim = name;
		this.animEndsAt = Date.now() + frames.length * gapMs;
		this.requestRender();
	}

	private stateAnim(): string {
		if (this.state === "thinking") return thinkingAnim;
		if (this.state === "coding") return codingAnim;
		return pickIdleChain(this.available, this.currentAnim ?? undefined) ?? thinkingAnim;
	}

	/** Animation-chain driver: runs the state machine as animations end. */
	private tick(): void {
		if (this.disposed || this.line === null || Date.now() < this.animEndsAt) return;
		if (this.interaction) {
			// Interaction anim finished — resume the agent-state animation.
			this.interaction = null;
			this.play(this.stateAnim());
			return;
		}
		if (this.state === "idle") {
			const next = pickIdleChain(this.available, this.currentAnim ?? undefined);
			if (next) this.play(next);
		} else if (this.currentAnim === this.stateAnim()) {
			// Looping state animation: kitty loops seamlessly, just extend.
			const meta = loadManifest()[this.currentAnim!]!;
			this.animEndsAt = Date.now() + (meta.frames / meta.fps) * 1000;
		} else {
			this.play(this.stateAnim());
		}
	}

	/** Agent state change from pi events. Interaction anims play out first. */
	setState(state: PetState): void {
		if (state === this.state) return;
		this.state = state;
		if (this.interaction) return; // tick resumes the state anim when it ends
		this.play(this.stateAnim());
	}

	handleMouse(event: TuiMouseEvent): { handled: boolean } | undefined {
		// Click reactions (fullscreen routes layout mouse events to the widget
		// rows). Press/drag are left unhandled — the pet is stationary now.
		if (event.type !== "click" || event.button !== "left") return undefined;
		const anim = pickClick(this.available);
		if (!anim) return { handled: true };
		this.interaction = anim;
		this.play(anim);
		return { handled: true };
	}

	render(width: number): string[] {
		if (this.line === null) return [];
		// Center the pet above the prompt: the widget spans the full terminal
		// width and the kitty placement lands at the current cursor position, so
		// leading spaces offset it to the middle (recomputed per render, so
		// terminal resizes recenter).
		const pad = Math.max(0, Math.floor((width - this.sizeCols) / 2));
		const lines: string[] = [" ".repeat(pad) + this.line];
		for (let i = 1; i < this.sizeRows; i++) lines.push("");
		return lines;
	}

	invalidate(): void {}

	dispose(): void {
		this.disposed = true;
		if (this.timer) {
			clearInterval(this.timer);
			this.timer = null;
		}
		process.stdout.removeListener("resize", this.onResize);
		if (this.imageId !== null) {
			// Widget is gone — free the kitty image data. Raw write is safe:
			// APC sequences carry no cursor movement and kitty parses them
			// between pi's writes (the tmux passthrough filter, if installed,
			// wraps this along with everything else).
			process.stdout.write(deleteImageLine(this.imageId));
			this.imageId = null;
		}
		this.line = null;
	}
}

// ---- Extension ----
// The active pet lives on globalThis so /reload doesn't orphan a running
// widget (its setState wiring would die with the old module instance).
interface PetHandle {
	widget: PetWidget;
}

function petRef(): PetHandle | null {
	return ((globalThis as Record<string, unknown>).__piPetOverlay as PetHandle | undefined) ?? null;
}

function setPetRef(handle: PetHandle | null): void {
	if (handle) (globalThis as Record<string, unknown>).__piPetOverlay = handle;
	else delete (globalThis as Record<string, unknown>).__piPetOverlay;
}

const WIDGET_KEY = "pet";

export default function petExtension(pi: ExtensionAPI) {
	pi.registerCommand("pet", {
		description: "Show the desktop pet above the prompt (kitty graphics; fullscreen + kitty/Ghostty/WezTerm)",
		getArgumentCompletions: (prefix: string) => {
			const sizes = ["small", "normal", "large"];
			const items = sizes.filter((s) => s.startsWith(prefix)).map((s) => ({ value: s, label: s }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/pet requires interactive mode", "error");
				return;
			}
			if (process.env.TMUX) {
				// tmux swallows kitty graphics unless wrapped in DCS passthrough;
				// install a stdout filter that wraps every kitty sequence (ours
				// and pi's own image management) for the outer terminal. Only safe
				// under tmux — a bare terminal can't unwrap `DCS tmux;`.
				if (!outerTerminalHasKittyGraphics()) {
					ctx.ui.notify("/pet in tmux needs a kitty-graphics outer terminal (kitty, Ghostty, WezTerm, Warp)", "error");
					return;
				}
				installTmuxPassthrough();
			} else if (getCapabilities().images !== "kitty") {
				ctx.ui.notify("/pet needs a kitty-graphics terminal (kitty, Ghostty, WezTerm, Warp)", "error");
				return;
			}
			if (petRef()) {
				ctx.ui.notify("Pet already running — use /pet-stop first", "info");
				return;
			}
			const sizeArg = (args ?? "").trim().toLowerCase();
			const targetRows = SIZE_ROWS[sizeArg in SIZE_ROWS ? sizeArg : "normal"]!;

			try {
				loadManifest();
			} catch (e) {
				ctx.ui.notify(`pet assets missing: ${(e as Error).message}`, "error");
				return;
			}

			ctx.ui.setWidget(WIDGET_KEY, (tui) => {
				// Fullscreen only: the regular-mode renderer has no kitty placement
				// cache, so image lines there would retransmit on every repaint.
				const fullscreen =
					(tui as unknown as { altScreenActive?: boolean }).altScreenActive !== undefined;
				if (!fullscreen) {
					ctx.ui.notify("/pet needs fullscreen mode", "error");
					return {
						render: () => [] as string[],
						invalidate() {},
					};
				}
				const widget = new PetWidget(tui, () => tui.requestRender(), targetRows);
				setPetRef({ widget });
				return widget;
			});
		},
	});

	pi.registerCommand("pet-stop", {
		description: "Close the desktop pet",
		handler: async (_args, ctx) => {
			const handle = petRef();
			if (!handle) {
				ctx.ui.notify("No pet running", "info");
				return;
			}
			setPetRef(null);
			handle.widget.dispose(); // idempotent; also fires if pi replaces the widget
			ctx.ui.setWidget(WIDGET_KEY, undefined);
			ctx.ui.notify("Pet closed", "info");
		},
	});

	// ---- Agent state → animation state ----
	pi.on("agent_start", () => {
		petRef()?.widget.setState("thinking");
	});

	pi.on("tool_call", (event) => {
		if (CODING_TOOLS.has(event.toolName)) {
			petRef()?.widget.setState("coding");
		}
	});

	pi.on("agent_settled", () => {
		petRef()?.widget.setState("idle");
	});

	pi.on("session_shutdown", (_event, ctx) => {
		const handle = petRef();
		if (handle) {
			setPetRef(null);
			handle.widget.dispose();
			ctx.ui.setWidget(WIDGET_KEY, undefined);
		}
	});
}

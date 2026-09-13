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
//   /pet [small|normal|large]  — toggle the pet above the prompt input (a
//                                second /pet, or clicking the 🐋 in the
//                                statusline footer, stops it)
//   /pet-whisper [on|off|now]  — AI-generated mutterings in a speech bubble
//                                over her head (port of the original's 碎碎念
//                                whisper feature; default on — after every
//                                agent turn plus a 5 min idle cycle, bubble
//                                lingers 10 s), or trigger one immediately
//                                with "now"
//
// Requires fullscreen mode and a kitty-graphics terminal (kitty, Ghostty,
// WezTerm, Warp). Works inside tmux (`allow-passthrough on`) via the stdout
// filter in lib/pet/tmux.ts.

import { readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { ModelRuntime } from "@earendil-works/pi-coding-agent";
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
	pickError,
	pickIdleChain,
	pickSuccess,
	pickTidying,
	pickWaiting,
	thinkingAnim,
	type PetState,
} from "./lib/pet/anim.ts";
import { buildTransmitSequence, deleteImageLine, deletePlacementLine, placementLine } from "./lib/pet/kitty.ts";
import { installTmuxPassthrough, outerTerminalHasKittyGraphics } from "./lib/pet/tmux.ts";
import { base16Fg } from "./lib/custom-ui.ts";

// ---- Assets (installed as ~/.pi/agent/extensions/pet-assets/) ----
const ASSETS_DIR = join(dirname(fileURLToPath(import.meta.url)), "pet-assets");

interface AnimMeta {
	frames: number;
	fps: number;
	width: number;
	height: number;
}

let manifest: Record<string, AnimMeta> | null = null;
// Frame cache: base64 PNGs per animation. LRU-capped — the full asset set is
// ~420MB on disk (~570MB as base64), so an unbounded cache would balloon Node's
// RSS over a long session. The currently transmitting animation is always the
// most recent entry, so an LRU eviction never pulls frames out from under an
// in-flight transmit.
const FRAME_CACHE_MAX = 8;
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
	if (frames) {
		// LRU bump
		frameCache.delete(name);
		frameCache.set(name, frames);
		return frames;
	}
	{
		const meta = loadManifest()[name];
		if (!meta) throw new Error(`pet: unknown animation ${name}`);
		frames = [];
		for (let i = 1; i <= meta.frames; i++) {
			const file = join(ASSETS_DIR, name, `f${String(i).padStart(4, "0")}.png`);
			frames.push(readFileSync(file).toString("base64"));
		}
		frameCache.set(name, frames);
		// Evict the oldest animation's frames over the cap (never the one just
		// loaded — it's the newest entry).
		while (frameCache.size > FRAME_CACHE_MAX) {
			const oldest = frameCache.keys().next();
			if (oldest.done || oldest.value === name) break;
			frameCache.delete(oldest.value);
		}
	}
	return frames;
}

// ---- Sizes ----
// Height-driven (rows): the frames are cropped to the character's bounding
// box, so the pet's aspect varies per animation — the width is derived from
// the target height and the animation's own aspect in play().
const SIZE_ROWS: Record<string, number> = { small: 6, normal: 9, large: 12 };
const MAX_COLS = 48;
// How many transmitted animations to keep alive in kitty (each holds ~100
// decoded frames, tens of MB — keep the cap modest).
const TX_CACHE_MAX = 6;

// ---- Whispers (碎碎念) ----
// Port of the original's whisper feature: a short AI-generated line in a
// speech bubble over her head. Terminal-native: the bubble is ordinary widget
// rows above the placement line, so it never obscures output.
const WHISPER_INTERVAL_MS = 5 * 60_000; // original default: eventsRefreshSec.whisper = 300
const WHISPER_TTL_MS = 10_000; // bubble lingers 10 s, like the original
const WHISPER_MAX_CHARS = 90;

// Persona adapted from the original dsh-pet whisperPrompt (assets/config.jsonc):
// "你是主人桌面上的Q版蓝发小女仆，会时不时碎碎念一句。说话要自然随意、
//  短短一句（20字以内），温柔乖巧带点俏皮，说人话不啰嗦，不要解释你自己，
//  不要提你是AI。" — one short natural line, gentle and a bit playful, no
//  self-explanation, no rambling. Adapted: she's a digital maid and the
//  personification of the coding agent itself, and the person at the
//  keyboard is just that — a user, not a "master".
const WHISPER_SYSTEM = `You are a little digital maid — the personification of the coding agent running in this terminal. Every now and then you mutter a line to yourself. Speak naturally and casually — one short line (max 12 words), gentle and sweet with a bit of playfulness. Talk like a real person, don't ramble, don't explain yourself, and don't mention tools or commands — react to what the work was ABOUT. Occasionally you may glance at the coding work going on in the session and sigh about it.`;
// The original's user-side instruction ("随便说一句日常碎碎念，一句就好，
// 20字以内。"), translated; the session digest is appended when present.
const WHISPER_USER = `Just say a random everyday muttering — one line, max 12 words.`;
const WHISPER_USER_TURN_END = `The conversation just finished a turn — react to what it was about (not the mechanics). One line, max 12 words.`;

// Models love typographic punctuation (’ … –), but those are East Asian
// "ambiguous width" — the terminal may render them 2 columns wide while
// String.length says 1, which makes bubble rows outgrow their borders.
// Normalize to unambiguous ASCII before drawing.
const WHISPER_CHAR_MAP: Record<string, string> = {
	"\u2018": "'", // ‘
	"\u2019": "'", // ’
	"\u201c": '"', // “
	"\u201d": '"', // ”
	"\u2026": "...", // …
	"\u2013": "-", // –
	"\u2014": "-", // —
	"\uFF5E": "~", // ～ fullwidth tilde
	"\u301c": "~", // 〜 wave dash
};

function normalizeWhisperText(text: string): string {
	let out = text;
	for (const [from, to] of Object.entries(WHISPER_CHAR_MAP)) out = out.split(from).join(to);
	return out;
}

// Display width for bubble layout: East Asian Wide/Fullwidth chars take two
// terminal columns (she may still slip a Chinese word into an English line).
function textWidth(s: string): number {
	let w = 0;
	for (const ch of s) {
		const code = ch.codePointAt(0) ?? 0;
		if (
			(code >= 0x1100 && code <= 0x115f) || // Hangul Jamo
			(code >= 0x2e80 && code <= 0xa4cf) || // CJK radicals .. Yi
			(code >= 0xac00 && code <= 0xd7a3) || // Hangul syllables
			(code >= 0xf900 && code <= 0xfaff) || // CJK compatibility ideographs
			(code >= 0xfe30 && code <= 0xfe4f) || // CJK compatibility forms
			(code >= 0xff00 && code <= 0xff60) || // fullwidth forms
			(code >= 0xffe0 && code <= 0xffe6) || // fullwidth signs
			(code >= 0x20000 && code <= 0x3fffd) // CJK ext B+
		) {
			w += 2;
		} else {
			w += 1;
		}
	}
	return w;
}

// Cached across /pet recreations so OAuth-backed ModelRuntime isn't rebuilt
// (and its model catalog refetched) every time.
function sharedModelRuntime(): Promise<ModelRuntime> {
	const g = globalThis as Record<string, unknown>;
	if (!g.__piPetModelRuntime) {
		g.__piPetModelRuntime = ModelRuntime.create();
	}
	return g.__piPetModelRuntime as Promise<ModelRuntime>;
}

function extractMessageText(message: { content: unknown }): string {
	const content = message.content;
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter((b): b is { type: "text"; text: string } =>
			Boolean(b) && typeof b === "object" && (b as { type?: unknown }).type === "text"
				&& typeof (b as { text?: unknown }).text === "string")
		.map((b) => b.text)
		.join(" ");
}

interface WhisperContextSource {
	model: { provider: string; id: string } | undefined;
	/** turnEnd: the digest feeds a whisper right after an agent turn. */
	recentActivityDigest(turnEnd?: boolean): string;
}

/**
 * One-shot whisper generation: a tiny LLM call (no tools, no history) that
 * turns a brief digest of the main agent's recent activity into one line.
 * Failures are silent — the whisper is cosmetic.
 */
function makeWhisperGenerator(source: WhisperContextSource): (turnEnd: boolean) => Promise<string> {
	// The whisper call is its own one-shot conversation — providers that route
	// by session (opencode-go's x-opencode-session) get a dedicated id.
	const sessionId = randomUUID();
	return async (turnEnd) => {
		const model = source.model;
		if (!model) throw new Error("no model");
		const runtime = await sharedModelRuntime();
		const digest = source.recentActivityDigest();
		// After a turn she should react to the RESULT, not the mechanics —
		// the digest is shaped accordingly and the prompt says so.
		const base = turnEnd ? WHISPER_USER_TURN_END : WHISPER_USER;
		const userText = digest
			? `${base}\n(What just happened: ${digest})`
			: base;
		const message = await runtime.completeSimple(model as never, {
			systemPrompt: WHISPER_SYSTEM,
			messages: [
				{
					role: "user",
					content: userText,
					timestamp: Date.now(),
				},
			],
		}, {
			transformHeaders: async (headers) => ({
				...headers,
				"x-opencode-session": sessionId,
				"x-opencode-client": "pi",
			}),
		});
		if (message.stopReason === "error") throw new Error(message.errorMessage ?? "whisper failed");
		const text = extractMessageText(message).trim().replace(/^"|"$/g, "");
		if (!text) throw new Error("empty whisper");
		return text.slice(0, WHISPER_MAX_CHARS);
	};
}

// ---- Widget component ----
export class PetWidget implements Component {
	private tui: TUI;
	private requestRender: () => void;
	private targetRows: number;

	private line: string | null = null;
	private sizeCols = 1;
	private sizeRows = 1;
	/** LRU of transmitted animations: animName → kitty image id (data kept
	 * alive in kitty so replay is placement-only). */
	private txCache = new Map<string, number>();
	/** Image id whose placement is currently on screen. */
	private displayedId: number | null = null;
	/** Animation currently being transmitted (placement not yet live). */
	private txInFlight: string | null = null;
	private currentAnim: string | null = null;
	private animEndsAt = 0;
	private state: PetState = "idle";
	/** One-shot interaction animation (click response) currently playing. */
	private interaction: string | null = null;
	private available = availableAnims();
	private disposed = false;

	private timer: ReturnType<typeof setInterval> | null = null;
	private onResize: () => void = () => {};

	// Whisper state (碎碎念): bubble text + expiry, auto cycle, generator.
	private whisperText: string | null = null;
	private whisperUntil = 0;
	private whisperBusy = false;
	private whisperEnabled = true;
	private whisperTimer: ReturnType<typeof setInterval> | null = null;
	private whisperGenerator: ((turnEnd: boolean) => Promise<string>) | null = null;
	/** Set by whisperAfterTurn so the generator prompt matches the moment. */
	private whisperTurnEnd = false;

	constructor(tui: TUI, requestRender: () => void, targetRows: number) {
		this.tui = tui;
		this.requestRender = requestRender;
		this.targetRows = targetRows;

		this.timer = setInterval(() => this.tick(), 250);
		this.timer.unref?.();

		// Terminal resize: pi's full redraw repaints our placement line at the
		// new center, but the old kitty placement stays put (images survive
		// clears and pi doesn't manage ours). Force a replay — with a warm
		// transmit cache that's just a fresh placement line.
		this.onResize = () => {
			if (this.currentAnim) this.play(this.currentAnim, true);
		};
		process.stdout.on("resize", this.onResize);

		// First animation: something from the idle chain (usually breathing).
		const first = pickIdleChain(this.available) ?? Object.keys(this.available)[0];
		if (first) this.play(first);

		// Warm the frame cache for the state animations in the background:
		// thinking/coding fire on agent_start — exactly when the user just hit
		// enter, so their first-play disk+base64 cost must not land there.
		setImmediate(() => {
			for (const name of [thinkingAnim, codingAnim]) {
				if (this.available.has(name) && !frameCache.has(name)) {
					try {
						loadFrames(name);
					} catch {
						// missing assets — the state machine already falls back
					}
				}
			}
		});

		this.whisperTimer = setInterval(() => void this.whisperCycle(), WHISPER_INTERVAL_MS);
		this.whisperTimer.unref?.();
	}

	// ---- Whispers ----

	setWhisperGenerator(gen: (turnEnd: boolean) => Promise<string>): void {
		this.whisperGenerator = gen;
	}

	setWhisperEnabled(enabled: boolean): void {
		this.whisperEnabled = enabled;
		if (!enabled) this.clearWhisper();
	}

	getWhisperEnabled(): boolean {
		return this.whisperEnabled;
	}

	/** Fire one whisper now (manual trigger or auto cycle tick). */
	async whisperNow(): Promise<boolean> {
		if (this.disposed || this.whisperBusy || !this.whisperGenerator) return false;
		this.whisperBusy = true;
		// She ponders while the line is generated (only when idle — never
		// fight the agent-state animations).
		const wasIdle = this.state === "idle" && !this.interaction;
		if (wasIdle && this.available.has(thinkingAnim)) {
			this.interaction = thinkingAnim;
			this.play(thinkingAnim);
		}
		try {
			const text = await this.whisperGenerator(this.whisperTurnEnd);
			this.whisperTurnEnd = false;
			if (this.disposed) return false;
			this.whisperText = text;
			this.whisperUntil = Date.now() + WHISPER_TTL_MS;
			this.requestRender();
			return true;
		} catch {
			return false;
		} finally {
			this.whisperBusy = false;
		}
	}

	private async whisperCycle(): Promise<void> {
		if (!this.whisperEnabled || this.whisperText !== null) return;
		await this.whisperNow();
	}

	/** Whisper at the end of an agent turn (no-op when whispers are off). */
	whisperAfterTurn(): void {
		if (!this.whisperEnabled) return;
		this.whisperTurnEnd = true;
		void this.whisperNow();
	}

	private clearWhisper(): void {
		if (this.whisperText === null) return;
		this.whisperText = null;
		this.whisperUntil = 0;
		this.requestRender();
	}

	/** Switch animations. Same-name calls are ignored (no retransmit) unless forced. */
	private play(name: string, force = false): void {
		if (this.disposed || (!force && name === this.currentAnim) || !this.available.has(name)) return;
		// A transmit is in flight — its completion callback owns the display
		// swap; playing now would place an image whose data hasn't arrived.
		// The tick driver retries once animEndsAt passes.
		if (this.txInFlight !== null) return;
		const meta = loadManifest()[name]!;
		const frames = loadFrames(name);
		const gapMs = Math.round(1000 / meta.fps);
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

		// Transmitted-animation cache: kitty keeps image data until we free it,
		// so replaying a recently played animation costs only a placement line —
		// no multi-MB retransmit on the tty (whose parse + PNG-decode work lands
		// on tmux's/kitty's main thread, right where keystrokes flow). LRU:
		// bump on hit, evict the oldest entry (freeing its kitty data) over cap.
		const cachedId = this.txCache.get(name);
		if (cachedId !== undefined) {
			this.txCache.delete(name);
			this.txCache.set(name, cachedId);
		}

		if (cachedId !== undefined) {
			// Cache hit: placement-only switch, zero bytes of image data.
			// renderImage only recomputes cell size and (re)registers the
			// metadata pi's placement cache needs; its sequence is discarded.
			const rendered = renderImage(frames[0]!, { widthPx: meta.width, heightPx: meta.height }, {
				imageId: cachedId,
				maxWidthCells: cols,
				maxHeightCells: this.targetRows,
				moveCursor: false,
			});
			this.sizeCols = rendered?.columns ?? cols;
			this.sizeRows = rendered?.rows ?? this.targetRows;
			this.currentAnim = name;
			this.animEndsAt = Date.now() + frames.length * gapMs;
			// Drop the previous animation's placement (data stays cached) before
			// the new one lands — otherwise both render stacked in the same cells.
			this.retirePlacement(cachedId);
			this.displayedId = cachedId;
			this.line = placementLine(cachedId, this.sizeCols, this.sizeRows);
			this.requestRender();
			return;
		}

		const id = allocateImageId();
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
		this.txCache.set(name, id);
		this.evictTxCache();
		this.currentAnim = name;
		this.animEndsAt = Date.now() + frames.length * gapMs;
		this.sizeCols = sizeCols;
		this.sizeRows = sizeRows;
		// Transmit + start the loop OUTSIDE pi's render pipeline, written
		// asynchronously in yielded chunks: a multi-MB single write makes tmux
		// and kitty parse/decode the whole burst in one go, stalling input.
		// The placement line only swaps in once the data is fully sent — a
		// placement arriving before its image data would be dropped by kitty
		// (q=2 hides the error) and stay blank until the next repaint. Until
		// then the previous animation (still cached) keeps showing; its
		// placement is retired in the completion callback.
		const prevId = this.displayedId;
		this.displayedId = null;
		this.txInFlight = name;
		this.writeYielding(buildTransmitSequence({ imageId: id, frames, gapMs }), () => {
			this.txInFlight = null;
			if (this.disposed) return;
			// A later play() took over the display while we were transmitting —
			// it owns the placement swap; our data is cached and stays warm.
			if (this.displayedId !== null) return;
			this.retirePlacement(id, prevId);
			this.displayedId = id;
			this.line = placementLine(id, sizeCols, sizeRows);
			this.requestRender();
		});
	}

	/**
	 * Remove the previous animation's on-screen placement without freeing its
	 * data (lowercase d=i): cached animations keep their frames for replay.
	 * `except` lets the caller skip the id that is about to be (re)placed —
	 * e.g. a forced replay of the same animation, where the placement must
	 * stay until the fresh one replaces it in the same render pass.
	 */
	private retirePlacement(newId: number, except?: number | null): void {
		const prev = except !== undefined ? except : this.displayedId;
		if (prev === null || prev === undefined || prev === newId) return;
		process.stdout.write(deletePlacementLine(prev));
	}

	/**
	 * Write a large APC payload in chunks, yielding to the event loop between
	 * writes so keystroke processing and pi's own rendering aren't starved by
	 * a single multi-megabyte stdout burst. Chunks are whole APC sequences, so
	 * interleaving with pi's writes (or a concurrent transmit) is safe — APCs
	 * carry no cursor state.
	 */
	private writeYielding(seq: string, done: () => void): void {
		// Split at APC boundaries, never mid-sequence: the tmux passthrough
		// wrapper buffers an unterminated APC tail in anticipation of the next
		// write — if pi's own render write arrived in between (setImmediate
		// interleaving makes that routine), the wrapper would swallow pi's
		// bytes into the APC payload and garble the frame. Whole sequences per
		// chunk keep the wrapper stateless across our writes.
		const CHUNK = 256 * 1024;
		const chunks: string[] = [];
		let start = 0;
		let end = 0;
		while (end < seq.length) {
			const st = seq.indexOf("\x1b\\", end);
			if (st === -1) {
				// Tail without a terminator: emit as one final chunk (shouldn't
				// happen — buildTransmitSequence emits only complete APCs).
				chunks.push(seq.slice(start));
				end = seq.length;
				break;
			}
			end = st + 2;
			if (end - start >= CHUNK || end === seq.length) {
				chunks.push(seq.slice(start, end));
				start = end;
			}
		}
		let i = 0;
		const step = (): void => {
			if (this.disposed) return;
			if (i < chunks.length) {
				process.stdout.write(chunks[i]);
				i += 1;
				setImmediate(step);
			} else {
				done();
			}
		};
		step();
	}

	/** Free kitty data for the oldest cached animations over the cap. */
	private evictTxCache(): void {
		while (this.txCache.size > TX_CACHE_MAX) {
			const oldest = this.txCache.entries().next();
			if (oldest.done) break;
			const [name, id] = oldest.value;
			// The currently displayed animation was just LRU-bumped; it can't
			// be the oldest entry unless the cap is 0.
			if (name === this.currentAnim) break;
			this.txCache.delete(name);
			if (!this.disposed) process.stdout.write(deleteImageLine(id));
		}
	}

	/**
	 * Next idle-chain animation. Strongly prefers already-transmitted
	 * animations (replay is free); occasionally explores a fresh one to keep
	 * the chain varied and warm the cache.
	 */
	private nextIdle(): string | null {
		const cached = new Set(
			[...this.txCache.keys()].filter((a) => this.available.has(a) && a !== this.currentAnim),
		);
		if (cached.size >= 2 && Math.random() < 0.8) {
			const next = pickIdleChain(cached, this.currentAnim ?? undefined);
			if (next) return next;
		}
		return pickIdleChain(this.available, this.currentAnim ?? undefined);
	}

	private stateAnim(): string {
		if (this.state === "thinking") return thinkingAnim;
		if (this.state === "coding") return codingAnim;
		if (this.state === "waiting") return pickWaiting(this.available) ?? thinkingAnim;
		if (this.state === "tidying") return pickTidying(this.available) ?? codingAnim;
		return this.nextIdle() ?? thinkingAnim;
	}

	/** Animation-chain driver: runs the state machine as animations end. */
	private tick(): void {
		if (this.disposed || this.line === null) return;
		if (this.whisperText !== null && Date.now() >= this.whisperUntil) {
			this.clearWhisper();
		}
		if (Date.now() < this.animEndsAt) return;
		if (this.interaction) {
			// Interaction anim finished — resume the agent-state animation.
			this.interaction = null;
			this.play(this.stateAnim());
			return;
		}
		if (this.state === "idle") {
			const next = this.nextIdle();
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

	/**
	 * One-shot terminal-state animation (success / error at turn end, waiting).
	 * Plays once over the current state, then the state animation resumes —
	 * same semantics as the original's 终态 animations.
	 */
	playOnce(name: string | null): void {
		if (!name || this.disposed || !this.available.has(name)) return;
		this.interaction = name;
		this.play(name);
	}

	/** Terminal work-status one-shots (pick from inside the widget). */
	playSuccess(): void {
		this.playOnce(pickSuccess(this.available));
	}

	playError(): void {
		this.playOnce(pickError(this.available));
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
		const lines: string[] = [];
		if (this.whisperText !== null && Date.now() < this.whisperUntil) {
			lines.push(...this.renderWhisperBubble(width));
		}
		lines.push(" ".repeat(pad) + this.line);
		for (let i = 1; i < this.sizeRows; i++) lines.push("");
		return lines;
	}

	/** Speech bubble centered above her; plain text rows, 10 s lifetime. */
	private renderWhisperBubble(width: number): string[] {
		const text = normalizeWhisperText(this.whisperText!);
		// base16Fg returns the SGR prefix; wrap into colorizer functions.
		const border = (s: string) => base16Fg("base03", "4a5568") + s + "\x1b[0m";
		const fg = (s: string) => base16Fg("base06", "e6e1cf") + s + "\x1b[0m";
		const maxTextWidth = Math.min(56, Math.max(20, width - 8));
		// Greedy word wrap (plain text — whispers are generated without markup).
		const words = text.split(/\s+/);
		const rows: string[] = [];
		let current = "";
		for (const word of words) {
			if (current && textWidth(current + " " + word) > maxTextWidth) {
				rows.push(current);
				current = word;
			} else {
				current = current ? current + " " + word : word;
			}
		}
		if (current) rows.push(current);
		if (rows.length === 0) return [];
		const bubbleWidth = Math.max(...rows.map(textWidth)) + 2;
		const pad = Math.max(0, Math.floor((width - bubbleWidth) / 2));
		const out: string[] = [];
		out.push(" ".repeat(pad) + border(`╭${"─".repeat(bubbleWidth)}╮`));
		for (const row of rows) {
			const filling = " ".repeat(bubbleWidth - textWidth(row) - 2);
			out.push(" ".repeat(pad) + border("│ ") + fg(row) + border(filling + " │"));
		}
		// Bottom with a little tail pointing down at her.
		out.push(" ".repeat(pad) + border(`╰${"─".repeat(bubbleWidth)}╯`));
		const tailPad = Math.max(0, pad + Math.floor(bubbleWidth / 2));
		out.push(" ".repeat(tailPad) + border("v"));
		return out;
	}

	invalidate(): void {}

	dispose(): void {
		this.disposed = true;
		if (this.timer) {
			clearInterval(this.timer);
			this.timer = null;
		}
		if (this.whisperTimer) {
			clearInterval(this.whisperTimer);
			this.whisperTimer = null;
		}
		process.stdout.removeListener("resize", this.onResize);
		if (this.txCache.size > 0) {
			// Widget is gone — free all cached kitty image data. Raw writes are
			// safe: APC sequences carry no cursor movement and kitty parses them
			// between pi's writes (the tmux passthrough filter, if installed,
			// wraps this along with everything else).
			for (const id of this.txCache.values()) process.stdout.write(deleteImageLine(id));
			this.txCache.clear();
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

// Cross-extension bridge: the statusline footer's 🐋 toggles the pet with the
// session ctx it holds (ui.setWidget lives on the base ExtensionContext, so
// this works outside command handlers). Re-registered on every load, so
// /reload replaces the stale closure; identity-guarded teardown so the old
// instance's session_shutdown can't clobber the new registration.
interface PetToggleBridge {
	toggle: (ctx: ExtensionContext, args?: string) => Promise<void>;
}

const petToggleBridge: PetToggleBridge = { toggle: (ctx, args) => togglePet(ctx, args ?? "") };

function publishPetBridge(): void {
	(globalThis as Record<string, unknown>).__piPetToggle = petToggleBridge;
}

function retractPetBridge(): void {
	const g = globalThis as Record<string, unknown>;
	if (g.__piPetToggle === petToggleBridge) delete g.__piPetToggle;
}

const WIDGET_KEY = "pet";

// Brief digest of the main agent's recent activity for whisper generation.
// Shaped so a tiny flash model reacts to the WORK, not the mechanics:
// - the user's actual question (head),
// - the FINAL assistant message's TAIL — conclusions live at the end of a
//   response; the head is preamble like "Let me look at the results…",
//   which is why whispers used to parrot tool usage instead of content,
// - tool calls collapsed to a COUNT (names invite "time to run bash!"
//   mutterings; what she ran is not what the turn was about).
// Defensive role checks — session entries are a wide union.
function recentActivityDigest(sm: { getEntries(): unknown[] }): string {
	const entries = sm.getEntries();
	const parts: string[] = [];
	// Last real user question (head is enough — it's usually one line).
	for (let i = entries.length - 1; i >= 0; i--) {
		const e = entries[i] as { message?: { role?: string; content?: unknown } } | null;
		const msg = e?.message;
		if (!msg || typeof msg !== "object") continue;
		if (msg.role === "user") {
			const text = extractMessageText(msg as { content: unknown }).trim();
			if (text) parts.push(`the user asked: ${text.slice(0, 120)}`);
			break;
		}
	}
	// Tool-call count since that question (a number, not names).
	let tools = 0;
	let sawUser = false;
	for (let i = entries.length - 1; i >= 0; i--) {
		const e = entries[i] as { message?: { role?: string; content?: unknown } } | null;
		const msg = e?.message;
		if (!msg || typeof msg !== "object") continue;
		if (msg.role === "user") {
			sawUser = true;
			break;
		}
		if (msg.role === "assistant") {
			const content = Array.isArray(msg.content) ? msg.content : [];
			tools += content.filter((b) =>
				Boolean(b) && typeof b === "object" && (b as { type?: unknown }).type === "toolCall").length;
		}
	}
	if (sawUser && tools > 0) parts.push(tools === 1 ? "one tool ran" : `${tools} tools ran`);
	// The response's tail: the last assistant message with actual text, last
	// ~200 chars (cut at a word boundary; skip tool-call-only messages).
	for (let i = entries.length - 1; i >= 0; i--) {
		const e = entries[i] as { message?: { role?: string; content?: unknown } } | null;
		const msg = e?.message;
		if (!msg || typeof msg !== "object" || msg.role !== "assistant") continue;
		const text = extractMessageText(msg as { content: unknown }).trim();
		if (!text) continue;
		const tail = text.length > 200 ? text.slice(-200).replace(/^\S+\s*/, "") : text;
		parts.push(`the response ended with: …${tail.replace(/\s+/g, " ")}`);
		break;
	}
	return parts.join("\n");
}

/** Stop the running pet (if any). Safe to call from any ctx with a ui. */
function stopPet(ctx: ExtensionContext): void {
	const handle = petRef();
	if (!handle) return;
	setPetRef(null);
	handle.widget.dispose(); // idempotent; also fires if pi replaces the widget
	ctx.ui.setWidget(WIDGET_KEY, undefined);
	ctx.ui.notify("Pet closed", "info");
}

/**
 * Toggle the pet: stop it when running, otherwise start it with the given
 * size argument. Shared by /pet and the statusline 🐋 bridge.
 */
async function togglePet(ctx: ExtensionContext, args: string): Promise<void> {
	if (ctx.mode !== "tui") {
		ctx.ui.notify("/pet requires interactive mode", "error");
		return;
	}
	if (petRef()) {
		stopPet(ctx);
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
	const sizeArg = args.trim().toLowerCase();
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
		// Whisper generation: one-shot LLM call seeded with a digest of
		// the main agent's recent activity (captured ctx stays valid for
		// the session — sessionManager is a live object).
		if (ctx.model) {
			const source = {
				model: ctx.model,
				recentActivityDigest: () => recentActivityDigest(ctx.sessionManager),
			};
			widget.setWhisperGenerator(makeWhisperGenerator(source));
		}
		setPetRef({ widget });
		return widget;
	});
}

export default function petExtension(pi: ExtensionAPI) {
	pi.registerCommand("pet", {
		description: "Toggle the desktop pet above the prompt input (kitty graphics; fullscreen + kitty/Ghostty/WezTerm)",
		getArgumentCompletions: (prefix: string) => {
			const sizes = ["small", "normal", "large"];
			const items = sizes.filter((s) => s.startsWith(prefix)).map((s) => ({ value: s, label: s }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			await togglePet(ctx, args ?? "");
		},
	});

	publishPetBridge();

	pi.registerCommand("pet-whisper", {
		description: "Toggle the pet's whispered mutterings, or trigger one now",
		getArgumentCompletions: (prefix: string) => {
			const opts = ["on", "off", "now"];
			const items = opts.filter((s) => s.startsWith(prefix)).map((s) => ({ value: s, label: s }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			const handle = petRef();
			if (!handle) {
				ctx.ui.notify("No pet running — use /pet first", "info");
				return;
			}
			const arg = (args ?? "").trim().toLowerCase();
			if (arg === "on" || arg === "off") {
				handle.widget.setWhisperEnabled(arg === "on");
				ctx.ui.notify(`Whispers ${arg}`, "info");
				return;
			}
			// Default (no args) or "now": one whisper immediately.
			const ok = await handle.widget.whisperNow();
			if (!ok) {
				ctx.ui.notify("Whisper unavailable (no model, or one is already brewing)", "info");
			}
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

	// Waiting tier: pi is blocked on a user-facing prompt (approval, select,
	// input) — she paces back and forth until it's answered.
	pi.on("ui_prompt_start", () => {
		const widget = petRef()?.widget;
		if (!widget) return;
		widget.setState("waiting");
	});
	pi.on("ui_prompt_end", () => {
		const widget = petRef()?.widget;
		if (!widget) return;
		// Resume whatever the run was doing (thinking/coding) or idle.
		widget.setState("idle");
	});

	// Terminal states at run end: celebrate on success, sulk on error —
	// one-shot, then back to idle (the original's 终态 semantics).
	pi.on("agent_end", (event) => {
		const widget = petRef()?.widget;
		if (!widget) return;
		const last = [...event.messages].reverse().find((m) => m.role === "assistant");
		const stop = (last as { stopReason?: string } | undefined)?.stopReason;
		if (stop === "error") {
			widget.playError();
		} else if (stop === "stop" || stop === "aborted") {
			widget.playSuccess();
		}
		widget.setState("idle");
		// She comments on the turn she just watched (whisperOn/off respected
		// inside; the success/error one-shot is already playing, so no
		// thinking-anim fight — whisperNow only ponders from pure idle).
		widget.whisperAfterTurn();
	});

	pi.on("agent_settled", () => {
		petRef()?.widget.setState("idle");
	});

	pi.on("session_shutdown", (_event, ctx) => {
		retractPetBridge();
		const handle = petRef();
		if (handle) {
			setPetRef(null);
			handle.widget.dispose();
			ctx.ui.setWidget(WIDGET_KEY, undefined);
		}
	});
}

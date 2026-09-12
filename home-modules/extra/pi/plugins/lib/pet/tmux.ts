// tmux passthrough for kitty graphics sequences.
//
// tmux normally swallows APC sequences (which include the kitty graphics
// protocol, ESC _ G ... ESC \), so images emitted by a program running inside
// a tmux pane never reach the terminal. tmux's escape hatch is DCS
// passthrough:
//
//   ESC P tmux ; ESC <payload with every ESC doubled> ESC \
//
// which tmux unwraps and forwards verbatim to the outer terminal (requires
// `set -g allow-passthrough on`, the default in this repo's tmux config).
//
// Instead of wrapping every emit site, installTmuxPassthrough() filters
// process.stdout.write itself: every complete kitty sequence passing through
// is wrapped, so sequences written by pi's own renderer (widget placement
// lines, full-redraw image cleanup) are covered too, not just ours. pi's
// internals keep seeing raw sequences, so all of its image-line detection and
// width logic behaves exactly as without tmux.
//
// IMPORTANT: only install this when pi actually runs inside tmux. Wrapped
// sequences are meaningless to a bare terminal — kitty, for one, does not
// unwrap `DCS tmux;` and will spew the payload as text.

// Idempotent across /reload: the patch survives module re-instantiation.
interface TmuxGlobal {
	__piTmuxKittyPassthrough?: boolean;
}

// Sequences longer than this without a terminator are flushed raw rather than
// buffered forever (real transmits are large but always terminate within one
// write).
const MAX_PENDING = 16 << 20;

function makeApcWrapper(): { wrap: (chunk: string) => string; hasPending: () => boolean } {
	let pending = "";
	const wrap = (chunk: string): string => {
		const s = pending + chunk;
		pending = "";
		let out = "";
		let i = 0;
		for (;;) {
			const start = s.indexOf("\x1b_G", i);
			if (start === -1) {
				out += s.slice(i);
				return out;
			}
			out += s.slice(i, start);
			// Kitty sequences are terminated by ST (ESC \) or BEL. Payloads are
			// base64/params and never contain ESC, so the first terminator ends
			// the sequence.
			const stEnd = s.indexOf("\x1b\\", start + 2);
			const belEnd = s.indexOf("\x07", start + 2);
			const bel = belEnd !== -1 && (stEnd === -1 || belEnd < stEnd);
			const end = bel ? belEnd : stEnd;
			if (end === -1) {
				// Unterminated — sequence split across writes. Buffer the tail
				// and prepend it to the next chunk.
				const tail = s.slice(start);
				if (tail.length > MAX_PENDING) {
					out += tail; // give up: emit raw (tmux swallows it)
					return out;
				}
				pending = tail;
				return out;
			}
			// Payload is the complete inner sequence (ESC _G ... terminator), with
			// every ESC doubled — tmux un-doubles them when forwarding. The DCS
			// wrapper itself always ends with ST, as tmux expects.
			let payload = s.slice(start, end + (bel ? 1 : 2));
			// Placement commands (a=p) are positioned by the terminal's cursor.
			// Under tmux that cursor is desynced: pi positions rows with CSI
			// sequences that tmux applies to its own grid, while the forwarded
			// placement executes against kitty's cursor, which sits wherever
			// tmux's last paint left it. So for placements, parse the row paint
			// that pi emitted just before this APC (ESC[<row>;1H ESC[2K <pad
			// spaces>) and prepend an absolute CSI H INSIDE the payload — kitty
			// then positions the image itself, correctly.
			if (/^a=p,/.test(payload.slice(3))) {
				const seg = s.slice(i, start);
				// Anchor on the LAST row reset — pi paints many rows per frame and
				// the placement belongs to the most recent one (which always
				// immediately follows its ESC[r;cH).
				const k = seg.lastIndexOf("\x1b[2K");
				const paint = k !== -1 ? /\x1b\[(\d+);(\d+)H\x1b\[2K$/.exec(seg.slice(0, k + 4)) : null;
				if (paint) {
					const visible = seg.slice(k + 4).replace(/\x1b\[[0-9;]*m/g, "").length;
					payload = `\x1b[${paint[1]};${Number(paint[2]) + visible}H` + payload;
				}
			}
			out += `\x1bPtmux;\x1b${payload.replaceAll("\x1b", "\x1b\x1b")}\x1b\\`;
			i = end + (bel ? 1 : 2);
		}
	};
	return { wrap, hasPending: () => pending.length > 0 };
}

export function installTmuxPassthrough(): void {
	if ((globalThis as TmuxGlobal).__piTmuxKittyPassthrough) return;
	(globalThis as TmuxGlobal).__piTmuxKittyPassthrough = true;

	const orig = process.stdout.write.bind(process.stdout) as (...args: unknown[]) => boolean;
	const apc = makeApcWrapper();
	const patched = (chunk: string | Uint8Array, ...rest: unknown[]): boolean => {
		if (typeof chunk === "string" && (chunk.includes("\x1b_G") || apc.hasPending())) {
			return orig(apc.wrap(chunk), ...rest);
		}
		return orig(chunk, ...rest);
	};
	process.stdout.write = patched as typeof process.stdout.write;
}

/** Is the outer terminal (behind tmux, if any) kitty-graphics capable? */
export function outerTerminalHasKittyGraphics(): boolean {
	const termProgram = (process.env.TERM_PROGRAM ?? "").toLowerCase();
	return Boolean(
		process.env.KITTY_WINDOW_ID ||
			process.env.GHOSTTY_RESOURCES_DIR ||
			process.env.WEZTERM_PANE ||
			termProgram === "kitty" ||
			termProgram === "ghostty" ||
			termProgram === "wezterm" ||
			termProgram === "warpterminal",
	);
}

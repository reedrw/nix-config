// claude-style: Claude Code inspired tool rendering for pi.
//
// One-line tool calls (`● Bash <cmd>`), one-line result summaries
// (`⎿  42 lines`), no boxes. Full output on demand via ctrl+o (the expanded
// flag pi already manages).
//
// This is a *library* module, not an auto-discovered extension: pi only
// auto-loads `extensions/*.ts` and `extensions/*/index.ts`, so files under
// `lib/` are inert on their own. Tool-name ownership is split across
// extensions (nix-comma.ts owns `bash`, image-history.ts owns `read`,
// claude-style-ui.ts owns the rest), and each imports its slots from here.
//
// Self-shell mode (`renderShell: "self"`) drops pi's padded tool Box so rows
// stack tightly, Claude Code style.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Text } from "@earendil-works/pi-tui";
import type { Component } from "@earendil-works/pi-tui";
import type { Theme } from "@earendil-works/pi-coding-agent";

// Max width of a one-line call/summary before ellipsis. Terminal-width-aware
// wrapping is left to Text for expanded output; single-line slots are capped
// hard so parallel tool batches stay scannable.
const MAX_LINE = 120;
// Cap for expanded diff output; bash etc. rely on pi's upstream truncation.
const MAX_EXPANDED_DIFF_LINES = 400;

// Global style toggle: `claudeStyle: false` in .pi/settings.json (project)
// or ~/.pi/agent/settings.json (global; project wins) keeps pi's default
// rendering. Checked when extensions register their render slots, so a
// toggle needs a restart or /reload to take effect.
export function claudeStyleEnabled(): boolean {
	for (const path of [
		join(process.cwd(), ".pi", "settings.json"),
		join(homedir(), ".pi", "agent", "settings.json"),
	]) {
		try {
			const settings = JSON.parse(readFileSync(path, "utf8")) as { claudeStyle?: unknown };
			if (typeof settings.claudeStyle === "boolean") return settings.claudeStyle;
		} catch {
			// Missing or unparsable — fall through to the next scope.
		}
	}
	return true;
}

type RenderSlots = {
	renderShell: "self";
	renderCall: (args: any, theme: Theme, context: any) => Component;
	renderResult: (result: any, options: any, theme: Theme, context: any) => Component;
};

function shortenPath(path: string): string {
	const home = homedir();
	return path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

function clip(text: string, max = MAX_LINE): string {
	const line = text.replace(/\s+/g, " ").trim();
	return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

function firstLine(text: string): string {
	for (const line of text.split("\n")) {
		if (line.trim()) return line;
	}
	return "";
}

function lastLine(text: string): string {
	return firstLine(text.split("\n").reverse().join("\n"));
}

// `● label arg` — the call row. Status dot: grey while pending/running, then
// red on error / green on success. The call slot doesn't re-render by itself
// once the call settles, so the status is kept in context.state (shared
// across the row's slots) and written by settleStatus() from renderResult,
// which invalidates the row to repaint the dot. Claude Code style call:
// bold label with the argument inside parentheses.
function statusDot(theme: Theme, context: any): string {
	const status = context?.state?.status;
	if (status === "error") return theme.fg("error", "●");
	if (status === "success") return theme.fg("success", "●");
	return theme.fg("muted", "●");
}

// Record the final status of a tool row and request a repaint so the call
// slot's dot picks it up. Only invalidates on change — renderResult runs on
// every row render, and an unconditional invalidate would loop forever. The
// invalidate must be deferred: calling it synchronously from inside
// renderResult re-enters the row's updateDisplay() mid-rebuild, and the
// aborted outer pass appends its components again — duplicating every line.
export function settleStatus(context: any, error: boolean): void {
	const status = error ? "error" : "success";
	if (context?.state && context.state.status !== status) {
		context.state.status = status;
		setTimeout(() => context.invalidate(), 0);
	}
}

function callLine(label: string, arg: string, theme: Theme, suffix = "", context?: any): Text {
	const body = arg
		? `${theme.fg("toolTitle", "(")}${theme.fg("accent", clip(arg))}${theme.fg("toolTitle", ")")}`
		: "";
	return new Text(`${statusDot(theme, context)} ${theme.fg("toolTitle", theme.bold(label))}${body}${suffix}`, 0, 0);
}

// `⎿  summary` — the result row, indented under the call. Muted connector,
// dim summary on success, red on error.
function resultLine(theme: Theme, summary: string, error = false): Text {
	const body = error ? theme.fg("error", summary) : theme.fg("dim", summary);
	return new Text(`  ${theme.fg("muted", "⎿")}  ${body}`, 0, 0);
}

function multiLine(prefix: string, text: string, theme: Theme, error = false): Text {
	const color = error ? "error" : "toolOutput";
	return new Text(prefix + text.split("\n").map((l) => theme.fg(color, l)).join("\n"), 0, 0);
}

function resultText(result: any): string {
	const part = result?.content?.find((c: any) => c.type === "text");
	return part?.type === "text" ? part.text : "";
}

function truncationNote(details: any, theme: Theme): string {
	if (!details?.truncation?.truncated) return "";
	return theme.fg("warning", " [truncated]");
}

function withMore(text: string, cap: number, theme: Theme): string {
	const lines = text.split("\n");
	if (lines.length <= cap) return text;
	return lines.slice(0, cap).join("\n") + theme.fg("muted", `\n… (${lines.length - cap} more lines)`);
}

// ---------------------------------------------------------------------------
// bash — success collapses to the first output line; errors collapse to the
// exit code plus the last output line (where the useful part usually is).
// Pi appends "Command exited with code N" to the output text of failed runs.
// ---------------------------------------------------------------------------

export const bash: RenderSlots = {
	renderShell: "self",
	renderCall(args, theme, context) {
		const timeout = args.timeout ? theme.fg("muted", ` (timeout ${args.timeout}s)`) : "";
		return callLine("Bash", args.command ?? "", theme, timeout, context);
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		const text = resultText(result);
		if (isPartial && !context.isError) {
			const live = lastLine(text);
			return resultLine(theme, live ? `Running… ${clip(live, 80)}` : "Running…");
		}
		settleStatus(context, context.isError);
		if (context.isError) {
			const exit = text.match(/Command exited with code (\d+)/);
			const output = text.replace(/\n*Command exited with code \d+\n?$/, "").trimEnd();
			const status = exit ? `exit ${exit[1]}` : "failed";
			if (expanded) {
				return multiLine(`  ${theme.fg("muted", "⎿")}  ${theme.fg("error", status)}\n`, text, theme, true);
			}
			const tail = lastLine(output);
			return resultLine(theme, tail ? `${status}: ${clip(tail, 80)}${truncationNote(result.details, theme)}` : status, true);
		}
		if (expanded) {
			return multiLine(`  ${theme.fg("muted", "⎿")}\n`, text, theme);
		}
		const lineCount = text.split("\n").filter((l) => l.trim()).length;
		const head = firstLine(text);
		const count = lineCount > 1 ? theme.fg("muted", ` · ${lineCount} lines`) : "";
		return resultLine(theme, `${clip(head, 90) || "Done"}${count}${truncationNote(result.details, theme)}`);
	},
};

// ---------------------------------------------------------------------------
// read — `path:12-40` range suffix, "N lines" summary. Call and text half of
// the result are exported separately so image-history.ts (which owns `read`
// and appends inline image cells to the row) can compose them.
// ---------------------------------------------------------------------------

export function readCallSlot(args: any, theme: Theme, context?: any): Component {
	let arg = shortenPath(args.path ?? "");
	if (args.offset !== undefined || args.limit !== undefined) {
		const start = args.offset ?? 1;
		arg += theme.fg("muted", `:${start}${args.limit !== undefined ? `-${start + args.limit - 1}` : ""}`);
	}
	return callLine("Read", arg, theme, "", context);
}

export function readTextResult(result: any, { expanded, isPartial }: any, theme: Theme): Component {
	if (isPartial) return resultLine(theme, "Reading…");
	const text = resultText(result);
	if (!text) return new Text("", 0, 0);
	if (expanded) {
		return multiLine(`  ${theme.fg("muted", "⎿")}\n`, text, theme);
	}
	return resultLine(theme, `${text.split("\n").length} lines${truncationNote(result.details, theme)}`);
}

// ---------------------------------------------------------------------------
// edit — diff stat summary (+a −r), colored diff when expanded.
// ---------------------------------------------------------------------------

function diffStats(diff: string): { adds: number; dels: number } {
	let adds = 0;
	let dels = 0;
	for (const line of diff.split("\n")) {
		if (line.startsWith("+") && !line.startsWith("+++")) adds++;
		else if (line.startsWith("-") && !line.startsWith("---")) dels++;
	}
	return { adds, dels };
}

export const edit: RenderSlots = {
	renderShell: "self",
	renderCall(args, theme, context) {
		const count = Array.isArray(args.edits) ? args.edits.length : 0;
		const suffix = count > 1 ? theme.fg("muted", ` (${count} edits)`) : "";
		return callLine("Edit", shortenPath(args.path ?? ""), theme, suffix, context);
	},
	renderResult(result, { expanded, isPartial }, theme, context) {
		if (isPartial) return resultLine(theme, "Editing…");
		settleStatus(context, context.isError);
		const text = resultText(result);
		if (context.isError) {
			return resultLine(theme, clip(firstLine(text) || "error", 90), true);
		}
		const diff: string | undefined = result.details?.diff;
		if (!diff) return resultLine(theme, "Applied");
		if (expanded) {
			const colored = withMore(diff, MAX_EXPANDED_DIFF_LINES, theme)
				.split("\n")
				.map((line) => {
					if (line.startsWith("+") && !line.startsWith("+++")) return theme.fg("success", line);
					if (line.startsWith("-") && !line.startsWith("---")) return theme.fg("error", line);
					return theme.fg("dim", line);
				})
				.join("\n");
			return new Text(`  ${theme.fg("muted", "⎿")}\n${colored}`, 0, 0);
		}
		const { adds, dels } = diffStats(diff);
		return new Text(
			`  ${theme.fg("muted", "⎿")}  ${theme.fg("success", `+${adds}`)} ${theme.fg("error", `−${dels}`)}`,
			0,
			0,
		);
	},
};

// ---------------------------------------------------------------------------
// write — line count from the call args (the result carries no size info).
// ---------------------------------------------------------------------------

export const write: RenderSlots = {
	renderShell: "self",
	renderCall(args, theme, context) {
		const lines = typeof args.content === "string" ? args.content.split("\n").length : 0;
		const suffix = lines > 0 ? theme.fg("muted", ` (${lines} lines)`) : "";
		return callLine("Write", shortenPath(args.path ?? ""), theme, suffix, context);
	},
	renderResult(result, { isPartial }, theme, context) {
		if (isPartial) return resultLine(theme, "Writing…");
		settleStatus(context, context.isError);
		if (context.isError) {
			return resultLine(theme, clip(firstLine(resultText(result)) || "error", 90), true);
		}
		return resultLine(theme, "Written");
	},
};

// ---------------------------------------------------------------------------
// grep / find / ls — count-based summaries. The call rows differ per tool,
// so countResult only provides the shared result slot.
// ---------------------------------------------------------------------------

function countResult(unitSingular: string, unitPlural: string) {
	return {
		renderShell: "self" as const,
		renderResult(result: any, { expanded, isPartial }: any, theme: Theme, context: any): Component {
			if (isPartial) return resultLine(theme, "Searching…");
			settleStatus(context, context.isError);
			const text = resultText(result);
			if (context.isError) {
				return resultLine(theme, clip(firstLine(text) || "error", 90), true);
			}
			if (expanded) {
				return multiLine(`  ${theme.fg("muted", "⎿")}\n`, text, theme);
			}
			const count = text.split("\n").filter((l) => l.trim()).length;
			const limit = result.details?.matchLimitReached ??
				result.details?.resultLimitReached ?? result.details?.entryLimitReached;
			const note = limit ? theme.fg("warning", " (limit)") : "";
			const unit = count === 1 ? unitSingular : unitPlural;
			return resultLine(theme, count > 0 ? `${count} ${unit}${note}` : `no ${unitPlural}${note}`);
		},
	};
}

export const grep: RenderSlots = {
	...countResult("match", "matches"),
	renderCall(args, theme, context) {
		let arg = `/${args.pattern ?? ""}/`;
		if (args.path) arg += ` in ${shortenPath(args.path)}`;
		if (args.glob) arg += ` (${args.glob})`;
		return callLine("Grep", arg, theme, "", context);
	},
};

export const find: RenderSlots = {
	...countResult("file", "files"),
	renderCall(args, theme, context) {
		const arg = args.path ? `${args.pattern ?? ""} in ${shortenPath(args.path)}` : (args.pattern ?? "");
		return callLine("Find", arg, theme, "", context);
	},
};

export const ls: RenderSlots = {
	...countResult("entry", "entries"),
	renderCall(args, theme, context) {
		return callLine("Ls", shortenPath(args.path ?? "."), theme, "", context);
	},
};

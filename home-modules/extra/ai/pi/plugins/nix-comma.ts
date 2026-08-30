// nix-comma: comma-style "command not found" provisioning for the pi agent.
//
// When a bash tool call fails because a binary is missing, look it up in the
// nix-index database (same flags as the interactive command_not_found_handler
// in home-modules/core/comma/command-not-found.nix), build the package, and
// prepend its bin directory to PATH for every later bash call in the session
// via the bash tool's spawn hook. The agent just re-runs the command; nothing
// is installed into the user profile.
//
// Existence probes are answered with an informational availability note
// instead — probing means "can I use this?", so nothing is provisioned until
// the agent asks via `nix_provision`. `which`/`type` misses print distinctive
// markers, so they're detected from output even inside compound commands
// (`which foo; echo $?`); silent `command -v` misses are pre-scanned from the
// command string on failed calls and self-verified with a real shell lookup.
//
// Ambiguity: if several attrs ship the binary and none is an exact match,
// nothing is built — the agent picks a variant with the `nix_provision` tool.
// Provisions are moved to the front of the PATH prefix, so the most recent
// choice shadows older ones for same-named binaries while keeping the older
// packages' other binaries available.
//
// Runs entirely against the pinned `nixpkgs` registry entry, falling back to
// nixpkgs-unstable only when the attribute is missing there.

import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { Type as TType } from "typebox";

const NIX_INDEX_DB = join(homedir(), ".cache/nix-index");
const PRIMARY_BRANCH = "nixpkgs";
const FALLBACK_BRANCH = "github:NixOS/nixpkgs/nixpkgs-unstable";
const MAX_ATTR_CANDIDATES = 5;
const LOCATE_TIMEOUT_MS = 60_000;
const BUILD_TIMEOUT_MS = 600_000;
const MARKER = "[nix-comma]";

interface Provisioned {
	cmd: string;
	attr: string;
	branch: string;
	binDirs: string[];
	candidates: string[];
}

type Outcome =
	| { kind: "provisioned"; provision: Provisioned }
	| { kind: "not-in-index" }
	| { kind: "ambiguous"; candidates: string[] }
	| { kind: "build-failed"; candidates: string[] }
	| { kind: "aborted" };

interface CommaContext {
	signal?: AbortSignal;
	hasUI: boolean;
	ui: { notify: (message: string, level?: "info" | "warning" | "error") => void };
}

// Result of trying to make one attr available on one branch set.
type AttrResolution =
	| { kind: "ok"; branch: string; binDirs: string[] }
	| { kind: "missing" }
	| { kind: "failed"; detail: string };

export default function nixCommaExtension(pi: ExtensionAPI) {
	// bin directories provisioned this session, most recent first; prepended to
	// PATH on every bash spawn. PATH search is first-match, so the most recent
	// provision shadows older ones for same-named binaries.
	const sessionPaths: string[] = [];

	// Move the given bin dirs to the front of the PATH prefix so the most
	// recent provision wins for same-named binaries. Re-provisioning the same
	// dir moves it back to the front instead of duplicating it.
	function prependSessionPaths(binDirs: string[]) {
		const fresh = [...new Set(binDirs)];
		for (let i = sessionPaths.length - 1; i >= 0; i--) {
			if (fresh.includes(sessionPaths[i])) sessionPaths.splice(i, 1);
		}
		sessionPaths.unshift(...fresh);
	}
	// cmd -> outcome, so repeats are instant and failures aren't retried.
	const resolved = new Map<string, Outcome>();
	// Commands already told "provisioned but still not found" (once per session).
	const stillFailingNotified = new Set<string>();
	// Names already answered with a probe-availability note (once per session).
	const checkNotified = new Set<string>();
	const inFlight = new Map<string, Promise<Outcome>>();

	// nix-locate isn't on the global PATH here; cache how to invoke it.
	let locateInvocation: string[] | undefined;
	function locateInvocationFor(): string[] {
		if (locateInvocation) return locateInvocation;
		for (const dir of (process.env.PATH ?? "").split(":")) {
			if (!dir) continue;
			const candidate = join(dir, "nix-locate");
			if (existsSync(candidate)) {
				locateInvocation = [candidate];
				return locateInvocation;
			}
		}
		// Fall back to a cached `nix shell` (adds ~1s of eval per lookup).
		locateInvocation = ["nix", "shell", "nixpkgs#nix-index", "-c", "nix-locate"];
		return locateInvocation;
	}

	// Probe tokens scannable in the command string, including multi-name probes
	// like `which jq rg fd`. The run of names ends at any shell metacharacter
	// (| > ; & " ' ( ) etc.), which the name charset excludes. Names are
	// restricted to a shell-safe charset so they can be interpolated into
	// single quotes. Subsequent names must start with a letter so redirection
	// digits (`which jq rg 2>/dev/null`) aren't mistaken for command names.
	const PROBE_TOKEN_PATTERNS: Array<{ pattern: RegExp; mode: "command" | "type" }> = [
		{
			pattern: /\bwhich\s+(?:-{1,2}[A-Za-z-]+\s+)*([A-Za-z0-9_.+-]+(?:\s+[A-Za-z][A-Za-z0-9_.+-]*)*)/g,
			mode: "command",
		},
		{
			pattern: /\bcommand\s+(?:-{1,2}[A-Za-z-]+\s+)*-[vV]\s+([A-Za-z0-9_.+-]+(?:\s+[A-Za-z][A-Za-z0-9_.+-]*)*)/g,
			mode: "command",
		},
		{
			pattern: /\btype\s+(?:-{1,2}[A-Za-z-]+\s+)*([A-Za-z0-9_.+-]+(?:\s+[A-Za-z][A-Za-z0-9_.+-]*)*)/g,
			mode: "type",
		},
	];

	// `which`/`type` miss markers in command output — authoritative evidence of
	// a probe miss, valid even when the compound's last command exited 0.
	const PROBE_MISS_MARKERS: RegExp[] = [
		/\bwhich: no ([A-Za-z0-9_.+-]+) in \(/g,
		/\btype: ([A-Za-z0-9_.+-]+): not found/g,
	];

	// Segments that only produce output and can't change whether a probe ran
	// (`command -v foo; echo $?`, `command -v foo && echo found || echo missing`).
	function isOutputOnly(segment: string): boolean {
		return /^\s*(?:echo|printf|:)\b/.test(segment);
	}

	// True when every ;/&&/||-separated segment is a probe or output-only
	// statement. Such probes may exit 0 with some names missing (bash's
	// `command -v a b` semantics, or a trailing `echo`), so they're always
	// scanned; mixed commands still require isError to avoid noise on
	// successful commands that merely mention probe syntax
	// (e.g. `rg 'command -v foo' src/`).
	function isPureProbe(command: string): boolean {
		const segments = command.split(/[;&|]+/).map((seg) => seg.trim()).filter(Boolean);
		return (
			segments.length > 0 &&
			segments.every((seg) => isOutputOnly(seg) || /^\s*(?:which|command\s+-[vV]|type)\s+/.test(seg))
		);
	}

	function extractProbeTargets(command: string): Array<{ name: string; mode: "command" | "type" }> {
		const targets = new Map<string, "command" | "type">();
		for (const { pattern, mode } of PROBE_TOKEN_PATTERNS) {
			for (const [, names] of command.matchAll(pattern)) {
				for (const name of names.split(/\s+/).slice(0, MAX_ATTR_CANDIDATES)) {
					if (!targets.has(name)) targets.set(name, mode);
				}
			}
		}
		return [...targets].map(([name, mode]) => ({ name, mode }));
	}

	function extractProbeMisses(output: string): string[] {
		const names = new Set<string>();
		for (const pattern of PROBE_MISS_MARKERS) {
			for (const [, name] of output.matchAll(pattern)) {
				names.add(name);
			}
		}
		return [...names];
	}

	// Real shell lookup, with the session PATH prefix applied so already-
	// provisioned binaries are seen as present. undefined = verification failed.
	async function isMissing(name: string, mode: "command" | "type"): Promise<boolean | undefined> {
		const prefix = sessionPaths.length > 0 ? `PATH=${sessionPaths.join(":")}:$PATH; ` : "";
		const probe = mode === "type" ? "type" : "command -v";
		try {
			const result = await pi.exec(
				"/bin/bash",
				["-c", `${prefix}${probe} '${name}' >/dev/null 2>&1`],
				{ timeout: 5_000 },
			);
			return result.code !== 0;
		} catch {
			return undefined;
		}
	}

	// PATH injection hook, published for whoever owns the `bash` tool
	// registration (custom-ui loads first and consults it; without it
	// pi's built-in bash runs un-provisioned). Publishing a hook instead of
	// registering bash keeps this extension independent of any UI.
	(globalThis as Record<string, unknown>).__nixCommaSpawnHook = ({ env }: { env: Record<string, string | undefined> }) =>
		sessionPaths.length === 0
			? undefined
			: { env: { ...env, PATH: `${sessionPaths.join(":")}:${env.PATH ?? process.env.PATH ?? ""}` } };


	// Explicit provisioning: pick a variant among ambiguous candidates, override
	// an earlier auto-provision, or make a known attr available on demand.
	// Opts into custom-ui rendering via its runtime API (if loaded); without
	// it the tool registers plain.
	const provisionTool = {
		name: "nix_provision",
		label: "Nix Provision",
		description: `Provision a nixpkgs package for this session: builds it (cached after the first time) and prepends its bin directories to PATH for all later bash calls. Later provisions shadow earlier ones for same-named binaries. Use it when a ${MARKER} note lists several candidate attrs (nothing is built until you choose), to override an earlier auto-provision, or to make a known attr available on demand.`,
		promptSnippet: "Provision a nixpkgs attr onto this session's PATH",
		promptGuidelines: [
			`Use nix_provision when a ${MARKER} tool result lists multiple candidate attrs and you need a specific variant, or to swap a previously provisioned binary for a different variant.`,
		],
		parameters: Type.Object({
			attr: Type.String({ description: "nixpkgs attribute, e.g. ffmpeg-headless" }),
			cmd: Type.Optional(
				Type.String({
					description:
						"Binary name to verify inside the package's bin directory. When omitted, all bin directories of the attr's outputs are added.",
				}),
			),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const resolution = await resolveAttr(params.attr, params.cmd ?? null, signal);
			if (resolution.kind === "missing") {
				throw new Error(
					`${MARKER} attribute '${params.attr}' was not found in ${PRIMARY_BRANCH} or the fallback branch.`,
				);
			}
			if (resolution.kind === "failed") {
				throw new Error(
					`${MARKER} building ${PRIMARY_BRANCH}#${params.attr} failed: ${resolution.detail}`,
				);
			}
			prependSessionPaths(resolution.binDirs);
			const shadowNote =
				sessionPaths.length > resolution.binDirs.length
					? " These shadow earlier provisions of same-named binaries."
					: "";
			const note = `${MARKER} provisioned ${resolution.branch}#${params.attr}; added ${resolution.binDirs.join(", ")} to PATH for the rest of the session.${shadowNote} Re-run your command.`;
			// UI note via ctx.ui.notify: folded into the custom-ui batch when
			// that UI is loaded; the model reads the content copy either way.
			ctx.ui?.notify?.(note);
			return {
				content: [{ type: "text", text: note }],
				details: { attr: params.attr, branch: resolution.branch, binDirs: resolution.binDirs },
			};
		},
	};
	const styleApi = (globalThis as Record<string, unknown>).__piCustomUi as
		| { maybeDecorate: (tool: any, opts?: { label?: string; argOf?: (args: any) => string }) => any }
		| undefined;
	pi.registerTool(
		styleApi?.maybeDecorate(provisionTool, {
			label: "Nix Provision",
			argOf: (args: any) => `${args.attr ?? ""}${args.cmd ? ` · ${args.cmd}` : ""}`,
		}) ?? provisionTool,
	);

	// Tell the agent up front that missing commands resolve themselves.
	pi.on("before_agent_start", async (event) => {
		if (event.systemPrompt.includes(MARKER)) return;
		return {
			systemPrompt: `${event.systemPrompt}\n\n## Missing commands\n\nCommands that are not installed on this machine fail with "command not found". When that happens, an extension automatically finds the binary in the nix-index database, builds it, and prepends its bin directory to PATH for the rest of the session — the tool result will say so. Simply re-run the command; do not apologize, install anything, or give up. If a tool result lists several candidate attrs, pick the variant you need with the nix_provision tool before re-running. Failed existence checks (which, command -v, type) are answered with availability info instead — nothing is provisioned until you call nix_provision. You can also use any nixpkgs package without provisioning it: \`nix run nixpkgs#<attr> -- <args>\`.`,
		};
	});

	pi.on("tool_result", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		if (!existsSync(NIX_INDEX_DB)) return;

		const command = commandOf(event.input);
		const output = textOf(event.content);

		const notes: string[] = [];

		// Run misses: auto-provision. Don't require event.isError: a chain like
		// `cmd; echo done` exits 0 even when cmd was missing. The anchored
		// patterns are specific enough ("bash: line 1: foo: command not found")
		// to avoid grep-of-log false positives.
		if (/(^|\n)[\w./-]*(bash|sh|zsh): (line \d+: )*[^\s:]+: command not found/m.test(output)) {
			for (const name of extractMissingCommands(output, command, event.isError === true)) {
				if (resolved.has(name)) {
					const note = stillFailingNote(name);
					if (note) notes.push(note);
					continue;
				}
				// Dedupe concurrent provisioning of the same command (parallel calls).
				let pending = inFlight.get(name);
				if (!pending) {
					pending = provision(name, ctx).finally(() => inFlight.delete(name));
					inFlight.set(name, pending);
				}
				let outcome: Outcome;
				try {
					outcome = await pending;
				} catch {
					continue;
				}
				// Ambiguous outcomes aren't memoized: re-running the command
				// re-prompts until the agent picks a variant with nix_provision.
				if (outcome.kind !== "aborted" && outcome.kind !== "ambiguous") {
					resolved.set(name, outcome);
				}
				const note = noteFor(name, outcome);
				if (note) notes.push(note);
			}
		}

		// Existence probes: answer the question, provision nothing. `which`/`type`
		// miss markers are authoritative in output even when the compound exited 0
		// (`which foo; echo $?`); silent `command -v` misses are pre-scanned from
		// the command string on failed calls and verified with a real lookup.
		// Skipped when a run miss was already handled — running beats probing.
		if (notes.length === 0) {
			const probeNames = new Set<string>(extractProbeMisses(output));
			if ((event.isError || isPureProbe(command)) && probeNames.size === 0) {
				for (const { name, mode } of extractProbeTargets(command)) {
					if (resolved.has(name) || checkNotified.has(name)) continue;
					if (await isMissing(name, mode)) probeNames.add(name);
				}
			}
			for (const name of probeNames) {
				const note = await checkNote(name, ctx);
				if (note) notes.push(note);
			}
		}

		if (notes.length === 0) return;
		const joined = notes.join("\n\n");
		ctx.ui?.notify?.(joined);
		return {
			content: [...event.content, { type: "text", text: joined }],
		};
	});

	function commandOf(input: unknown): string {
		return input && typeof input === "object" && "command" in input
			? String((input as { command: unknown }).command ?? "")
			: "";
	}

	function textOf(content: unknown): string {
		if (!Array.isArray(content)) return "";
		return content
			.map((block) =>
				block && typeof block === "object" && "text" in block
					? String((block as { text: unknown }).text)
					: "",
			)
			.join("\n");
	}

	function extractMissingCommands(output: string, command: string, isError: boolean): string[] {
		const names = new Set<string>();
		// bash style:  bash: line 1: jq: command not found
		for (const [, name] of output.matchAll(/(?:^|\n)[\w./-]*(?:bash|sh|zsh): (?:line \d+: )*([^\s:|;&()<>'"]+): command not found/g)) {
			names.add(name);
		}
		// zsh style:   command not found: jq
		for (const [, name] of output.matchAll(/command not found:\s*([^\s:|;&()<>'"]+)/g)) {
			names.add(name);
		}
		if (names.size === 0 && isError) {
			// Fall back to the first word of the command itself.
			const first = command.trim().split(/\s+/)[0]?.replace(/^["']+|["']+$/g, "");
			if (first) names.add(first);
		}
		return [...names].filter(
			(name) => name.length > 0 && !name.startsWith("-") && !name.includes("/") && !name.includes("$"),
		);
	}

	// Build one attr across the primary and fallback branches. With cmd, the
	// attr must ship that binary; without, all bin dirs of its outputs are used.
	async function resolveAttr(
		attr: string,
		cmd: string | null,
		signal?: AbortSignal,
	): Promise<AttrResolution> {
		for (const branch of [PRIMARY_BRANCH, FALLBACK_BRANCH]) {
			if (signal?.aborted) return { kind: "failed", detail: "aborted" };
			let build;
			try {
				build = await pi.exec(
					"nix",
					["build", `${branch}#${attr}`, "--no-link", "--print-out-paths"],
					{ signal, timeout: BUILD_TIMEOUT_MS },
				);
			} catch {
				return { kind: "failed", detail: "aborted" };
			}
			if (build.code !== 0) {
				// Attribute missing in this branch -> try the fallback branch.
				// Anything else (real build failure) -> give up for this attr.
				if (/attribute .*missing|does not provide attribute/i.test(build.stderr)) continue;
				return { kind: "failed", detail: lastLines(build.stderr) };
			}
			const outPaths = build.stdout
				.split("\n")
				.map((line) => line.trim())
				.filter(Boolean);
			const binDirs = outPaths
				.map((path) => join(path, "bin"))
				.filter((binDir) => existsSync(binDir));
			if (cmd && !binDirs.some((binDir) => existsSync(join(binDir, cmd)))) {
				// Attr exists but doesn't ship this binary — no point trying branches.
				return { kind: "missing" };
			}
			if (binDirs.length === 0) return { kind: "missing" };
			return { kind: "ok", branch, binDirs };
		}
		return { kind: "missing" };
	}

	function lastLines(text: string, n = 3): string {
		const lines = text.split("\n").map((l) => l.trim()).filter(Boolean);
		return lines.slice(-n).join(" | ") || "unknown error";
	}

	// Look up candidate attrs for a binary (mirrors the zsh handler's
	// nix-locate flags). [] = not in the index, undefined = aborted.
	async function lookupAttrs(cmd: string, ctx: CommaContext): Promise<string[] | undefined> {
		const locateArgs = [
			"-d",
			NIX_INDEX_DB,
			"--minimal",
			"--at-root",
			"--whole-name",
			`/bin/${cmd}`,
		];
		const [locateBin, ...locateRest] = locateInvocationFor();
		let locate;
		try {
			locate = await pi.exec(locateBin, [...locateRest, ...locateArgs], {
				signal: ctx.signal,
				timeout: LOCATE_TIMEOUT_MS,
			});
		} catch {
			return undefined;
		}
		if (locate.code !== 0 || !locate.stdout.trim()) return [];

		// `jq.bin` -> `jq`, `nodejs.out` -> `nodejs` (same as ${attr%.*} in the zsh handler).
		return [
			...new Set(
				locate.stdout
					.split("\n")
					.map((line) => line.trim().replace(/\.[^.]+$/, ""))
					.filter(Boolean),
			),
		].sort((a, b) => Number(b === cmd) - Number(a === cmd) || a.length - b.length);
	}

	async function provision(cmd: string, ctx: CommaContext): Promise<Outcome> {
		const signal = ctx.signal;
		if (signal?.aborted) return { kind: "aborted" };

		const candidates = await lookupAttrs(cmd, ctx);
		if (candidates === undefined) return { kind: "aborted" };
		if (candidates.length === 0) return { kind: "not-in-index" };

		// Ambiguous without an exact attr-name match: don't evaluate anything,
		// let the agent choose via nix_provision (avoids building the wrong,
		// possibly large variant).
		if (candidates.length > 1 && !candidates.includes(cmd)) {
			return { kind: "ambiguous", candidates: candidates.slice(0, MAX_ATTR_CANDIDATES) };
		}

		for (const attr of candidates.slice(0, MAX_ATTR_CANDIDATES)) {
			if (signal?.aborted) return { kind: "aborted" };
			const resolution = await resolveAttr(attr, cmd, signal);
			if (resolution.kind === "ok") {
				prependSessionPaths(resolution.binDirs);
				return {
					kind: "provisioned",
					provision: {
						cmd,
						attr,
						branch: resolution.branch,
						binDirs: resolution.binDirs,
						candidates: candidates.filter((c) => c !== attr),
					},
				};
			}
			if (resolution.kind === "failed") continue; // try next candidate attr
		}
		return { kind: "build-failed", candidates };
	}

	// Informational answer for existence probes: never provisions anything.
	async function checkNote(cmd: string, ctx: CommaContext): Promise<string | undefined> {
		if (checkNotified.has(cmd)) return undefined;
		const candidates = await lookupAttrs(cmd, ctx);
		if (candidates === undefined) return undefined;
		checkNotified.add(cmd);
		if (candidates.length === 0) {
			return `${MARKER} \`${cmd}\` isn't installed and isn't in the nix-index database — no nixpkgs package ships it.`;
		}
		const how = `Call nix_provision to put it on PATH for the session, or run it once via \`nix run nixpkgs#<attr> -- <args>\`. Nothing has been provisioned.`;
		if (candidates.length === 1) {
			return `${MARKER} \`${cmd}\` isn't installed, but is available as nixpkgs#${candidates[0]}. ${how}`;
		}
		return `${MARKER} \`${cmd}\` isn't installed, but is available from nixpkgs attrs: ${candidates.slice(0, MAX_ATTR_CANDIDATES).join(", ")}. ${how}`;
	}

	function noteFor(cmd: string, outcome: Outcome): string | undefined {
		switch (outcome.kind) {
			case "provisioned": {
				const { attr, branch, binDirs, candidates } = outcome.provision;
				let note = `${MARKER} \`${cmd}\` was not installed. Provisioned ${branch}#${attr} and added ${binDirs.join(", ")} to PATH for the rest of the session — re-run the command and it will now be found.`;
				if (candidates.length > 0) {
					note += `\nOther attrs also ship \`${cmd}\`; if a different variant is needed, call nix_provision with attr set to one of: ${candidates.join(", ")}.`;
				}
				return note;
			}
			case "ambiguous":
				return `${MARKER} \`${cmd}\` is provided by multiple nixpkgs attrs: ${outcome.candidates.join(", ")}. Nothing was built yet — call the nix_provision tool with the attr you want (it will be built and put on PATH), then re-run the command.`;
			case "not-in-index":
				return `${MARKER} \`${cmd}\` was not found in the nix-index database. Search manually with \`nix-locate -d ~/.cache/nix-index --minimal --at-root --whole-name /bin/${cmd}\` or check https://search.nixos.org.`;
			case "build-failed":
				return `${MARKER} \`${cmd}\` matches nixpkgs attrs [${outcome.candidates.slice(0, MAX_ATTR_CANDIDATES).join(", ")}] but none could be provisioned. Inspect with \`nix build nixpkgs#${outcome.candidates[0]}\`, or try \`nix run nixpkgs#${outcome.candidates[0]} -- <args>\`.`;
			case "aborted":
				return undefined;
		}
	}

	function stillFailingNote(cmd: string): string | undefined {
		const outcome = resolved.get(cmd);
		if (outcome?.kind !== "provisioned" || stillFailingNotified.has(cmd)) return undefined;
		stillFailingNotified.add(cmd);
		const { attr, branch, binDirs } = outcome.provision;
		return `${MARKER} \`${cmd}\` was already provisioned (${branch}#${attr}, ${binDirs.join(", ")}) but is still not being found. The bin directory should be on PATH — the command may be running with a scrubbed environment (env -i, sudo, a shebang shell resetting PATH). Workaround: \`nix run nixpkgs#${attr} -- <args>\`.`;
	}
}

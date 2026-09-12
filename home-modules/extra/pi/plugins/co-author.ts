// Appends the Co-Authored-By trailer to commits made by the agent.
//
// Earlier versions blocked `git commit` bash calls up front unless the trailer
// appeared verbatim in the command text - fragile with && chains, --fixup,
// -F files, and quoting (the parser saw everything after the closing quote on
// the same line). Those gave way to a version that checked the resulting
// commits afterwards and amended the trailer on when missing. That one had a
// hole that cost a commit: it only amended in place when a single commit was
// bad, and otherwise told the agent to "fix them (e.g. git rebase -i)" - i.e.
// it handed an unsupervised history rewrite to the very agent it promised
// would never have to think about trailers. It complied, and a reset --hard
// in that rewrite dropped an unrelated commit.
//
// So the extension now owns trailers end to end and never delegates:
//   - one bad commit at HEAD  -> amended in place (previous commit stays in
//     the reflog, nothing else moves)
//   - several bad commits     -> ONE scripted `rebase --exec` that appends the
//     trailer only to the commits that need it, behind a backup ref under
//     refs/co-author/, and rolled back if the rebase is anything but clean
//   - anything unsafe         -> report and touch nothing. No advice to run
//     rebase/reset, ever.
//
// "Unsafe" means: the command pushed (commits may be on a remote), the new
// commits are not a linear chain from the pre-commit HEAD, or the rewrite
// failed. In all of those the extension leaves history exactly as it found it.
//
// Note: a commit already carrying ANY Co-Authored-By line is left alone - the
// check is only whether the expected pi-mono trailer is *present*, not whether
// it is the only one.
//
// Opt-outs (a commit with no trailer is a legitimate state: it means a human
// wrote that change, not the model):
//   PI_NO_COAUTHOR=1       disable the extension for the whole session
//   Co-Authored-By: none   per-commit: the change is the user's; no trailer is
//   No-Co-Author: ...      appended, and the commit is never flagged

import { existsSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MARKER = "[co-author]";

// Every agent commit is co-authored by pi itself (https://github.com/pi-mono),
// with the running model's id recorded in the name. The email is GitHub's
// canonical noreply form for that account (id+login@users.noreply.github.com),
// so GitHub renders the trailer as a link to the profile.
function expectedTrailer(modelId: string | undefined): string {
	const name = modelId ? `pi (${modelId})` : "pi";
	return `Co-Authored-By: ${name} <261679550+pi-mono@users.noreply.github.com>`;
}

function trailerValue(trailer: string): string {
	return trailer.replace(/^Co-Authored-By:\s*/i, "");
}

function hasTrailer(body: string, trailer: string): boolean {
	const expected = trailerValue(trailer);
	return body
		.split("\n")
		.some((line) => /^co-authored-by:/i.test(line) && trailerValue(line).trim() === expected);
}

// A commit that says, explicitly, that no model co-author is wanted. Both
// spellings count; the check also keeps the rebase hook from re-adding one.
function isOptedOut(body: string): boolean {
	return body.split("\n").some((line) => {
		const l = line.trim();
		return /^co-authored-by:\s*(none|n\/a)$/i.test(l) || /^no-co-author:/i.test(l);
	});
}

function stripTrailerLines(body: string): string {
	return body
		.split("\n")
		.filter((line) => !/^co-authored-by:/i.test(line))
		.join("\n");
}

function coauthorDisabled(): boolean {
	const v = process.env.PI_NO_COAUTHOR;
	return v !== undefined && v !== "" && v !== "0" && v.toLowerCase() !== "false";
}

// Shell snippet for `git rebase --exec`, run once per replayed commit: append
// the trailer only when the commit has neither a trailer nor an opt-out. The
// trailer is single-quoted so its <> and @ survive the shell.
function rebaseExecCommand(trailer: string): string {
	const quoted = `'${trailer.replace(/'/g, `'\\''`)}'`;
	return (
		"git log -1 --format=%B | grep -qiE '^co-authored-by:|^no-co-author:'" +
		` || git commit --amend --no-edit --allow-empty --trailer ${quoted}`
	);
}

// `cd <dir>` targets from a bash command, so the git plumbing runs in the repo
// the command actually operated on rather than the session cwd. A `cd` to any
// directory inside a repo works (`git -C sub` walks up), so the candidates are
// tried newest-first.
function cdTargets(command: string): string[] {
	const re = /(?:^|&&|;|\|\|)\s*cd\s+(?:'([^']+)'|"([^"]+)"|([^\s;&|]+))/g;
	const out: string[] = [];
	for (let m = re.exec(command); m; m = re.exec(command)) {
		const raw = m[1] ?? m[2] ?? m[3];
		if (!raw || raw.startsWith("-")) continue;
		out.push(isAbsolute(raw) ? raw : resolve(process.cwd(), raw));
	}
	return out;
}

export default function coAuthorExtension(pi: ExtensionAPI) {
	if (coauthorDisabled()) return;

	// toolCallId -> HEAD before the call ran, plus the repo dir the command
	// targeted, so tool_result knows which commits are new and where they live.
	const headBefore = new Map<string, { head: string; dir: string | undefined }>();

	async function runGit(dir: string | undefined, args: string[], signal?: AbortSignal) {
		return pi
			.exec("git", dir ? ["-C", dir, ...args] : args, { signal })
			.catch(() => undefined);
	}

	async function isRepo(dir: string, signal?: AbortSignal): Promise<boolean> {
		const r = await runGit(dir, ["rev-parse", "--git-dir"], signal);
		return !!r && r.code === 0;
	}

	async function findRepoDir(command: string, signal?: AbortSignal): Promise<string | undefined> {
		for (const dir of cdTargets(command).reverse()) {
			if (existsSync(dir) && (await isRepo(dir, signal))) return dir;
		}
		return undefined; // fall back to the session cwd
	}

	async function gitBody(
		dir: string | undefined,
		sha: string,
		signal?: AbortSignal,
	): Promise<string | undefined> {
		const log = await runGit(dir, ["log", "-1", "--format=%B", sha], signal);
		return log && log.code === 0 ? log.stdout : undefined;
	}

	// The commits this call created, in order, and only when they form a
	// simple chain off `before` (so a rewrite can't drag in unrelated commits).
	async function linearNewCommits(
		dir: string | undefined,
		before: string,
		commits: string[],
		signal?: AbortSignal,
	): Promise<boolean> {
		if (!before || commits.length === 0) return false;
		const r = await runGit(dir, ["rev-list", "--reverse", "--parents", `${before}..HEAD`], signal);
		if (!r || r.code !== 0) return false;
		const rows = r.stdout
			.split("\n")
			.map((l) => l.trim())
			.filter(Boolean)
			.map((l) => l.split(/\s+/));
		if (rows.length !== commits.length) return false;
		let parent = before;
		for (let i = 0; i < rows.length; i++) {
			const row = rows[i]!;
			if (row.length !== 2 || row[0] !== commits[i] || row[1] !== parent) return false;
			parent = row[0]!;
		}
		return true;
	}

	// Fix several commits with one message-only rebase. Backed up first, rolled
	// back on any non-clean result, and never left half-applied.
	async function appendTrailersByRebase(
		dir: string | undefined,
		before: string,
		bad: string[],
		trailer: string,
		signal?: AbortSignal,
	): Promise<{ ok: boolean; reason?: string; backup?: string }> {
		const backup = `refs/co-author/backup-${Date.now()}`;
		const head = await runGit(dir, ["rev-parse", "HEAD"], signal);
		if (!head || head.code !== 0) return { ok: false, reason: "could not read HEAD" };
		const mk = await runGit(dir, ["update-ref", backup, head.stdout.trim()], signal);
		if (!mk || mk.code !== 0) return { ok: false, reason: `could not create backup ref ${backup}` };

		// Message-only rewrite: content is untouched, so the repo's pre-commit
		// hooks (which validate content) are skipped rather than run N times and
		// risk wedging mid-rebase. --autostash keeps unrelated working-tree
		// edits out of the way.
		const rb = await runGit(
			dir,
			[
				"-c",
				"core.hooksPath=/dev/null",
				"rebase",
				before,
				"--autostash",
				"--exec",
				rebaseExecCommand(trailer),
			],
			signal,
		);
		if (rb && rb.code === 0) return { ok: true, backup };

		// Anything but clean: put it back exactly as it was.
		await runGit(dir, ["rebase", "--abort"], signal);
		await runGit(dir, ["reset", "--hard", backup], signal);
		const detail = (rb?.stderr ?? "").trim().split("\n")[0] ?? "";
		return { ok: false, reason: `rewrite failed${detail ? ` (${detail})` : ""}, rolled back to ${backup}`, backup };
	}

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const command = commandOf(event.input);
		if (!/\bgit\s+commit\b/.test(command)) return;
		const dir = await findRepoDir(command, ctx.signal);
		const rev = await runGit(dir, ["rev-parse", "HEAD"], ctx.signal);
		headBefore.set(event.toolCallId, {
			head: rev && rev.code === 0 ? rev.stdout.trim() : "",
			dir,
		});
	});

	pi.on("tool_result", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const state = headBefore.get(event.toolCallId);
		if (state === undefined) return;
		headBefore.delete(event.toolCallId);

		const trailer = expectedTrailer(ctx.model?.id);

		const { dir } = state;
		const before = state.head;
		const note = (text: string) => ({
			content: [...event.content, { type: "text" as const, text }],
		});
		const short = (shas: string[]) => shas.map((s) => s.slice(0, 7)).join(", ");

		const rev = await runGit(dir, ["rev-parse", "HEAD"], ctx.signal);
		if (!rev || rev.code !== 0) return;
		const after = rev.stdout.trim();
		if (after === before) return; // nothing committed

		const rangeArgs = before ? [`${before}..${after}`] : [after];
		const list = await runGit(dir, ["rev-list", "--reverse", ...rangeArgs], ctx.signal);
		if (!list || list.code !== 0) return;
		const newCommits = list.stdout.split("\n").map((l) => l.trim()).filter(Boolean);

		const bad: string[] = [];
		for (const sha of newCommits) {
			const body = await gitBody(dir, sha, ctx.signal);
			if (body === undefined) continue;
			if (hasTrailer(body, trailer) || isOptedOut(body)) continue;
			bad.push(sha);
		}
		if (bad.length === 0) return;

		// Never rewrite what may already be on a remote.
		if (/\bgit\s+push\b/.test(commandOf(event.input))) {
			return note(
				`${MARKER} commit(s) ${short(bad)} lack the Co-Authored-By trailer, but the command pushed; history left untouched.`,
			);
		}

		// One commit at HEAD: amend in place. Nothing else moves, and the
		// previous commit stays reachable through the reflog.
		if (bad.length === 1 && bad[0] === after) {
			const body = await gitBody(dir, bad[0]!, ctx.signal);
			if (body !== undefined) {
				const message = `${stripTrailerLines(body).trimEnd()}\n\n${trailer}\n`;
				const file = join(tmpdir(), `co-author-${Date.now()}.txt`);
				writeFileSync(file, message);
				try {
					const amend = await runGit(
						dir,
						["commit", "--amend", "--allow-empty", "-F", file],
						ctx.signal,
					);
					if (amend && amend.code === 0) {
						return note(`${MARKER} appended trailer to ${short(bad)}`);
					}
				} finally {
					unlinkSync(file);
				}
			}
		}

		// Several commits (e.g. a chained `commit && commit` in one call): one
		// scripted rebase, which the extension runs itself.
		if (!(await linearNewCommits(dir, before, newCommits, ctx.signal))) {
			return note(
				`${MARKER} commit(s) ${short(bad)} lack the Co-Authored-By trailer; the new commits are not a linear chain from the pre-commit HEAD, so history was left untouched.`,
			);
		}

		const rewritten = await appendTrailersByRebase(dir, before, bad, trailer, ctx.signal);
		if (rewritten.ok) return note(`${MARKER} appended trailer to ${short(bad)}`);
		return note(
			`${MARKER} commit(s) ${short(bad)} lack the Co-Authored-By trailer; automatic fix failed (${rewritten.reason}). History was left untouched.`,
		);
	});

	function commandOf(input: unknown): string {
		return input && typeof input === "object" && "command" in input
			? String((input as { command: unknown }).command ?? "")
			: "";
	}

	// Say what the extension owns, and that the agent must not reach for
	// history surgery to satisfy it.
	pi.on("before_agent_start", async (event) => {
		if (event.systemPrompt.includes(`${MARKER} extension appends`)) return;
		return {
			systemPrompt: `${event.systemPrompt}\n\n## Commit attribution\n\nDo not add Co-Authored-By trailers to commit messages, and never rewrite history (rebase/reset/cherry-pick) to add one. The ${MARKER} extension appends the trailer (co-authoring every commit as https://github.com/pi-mono, with the running model's id in the co-author name) to every commit you make - including several commits in a single command. If the user says a change is theirs and should carry no model co-author, end that commit message with a trailer line: Co-Authored-By: none`,
		};
	});
}

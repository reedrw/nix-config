// Appends the Co-Authored-By trailer to commits made by the agent.
//
// Earlier versions blocked `git commit` bash calls up front unless the trailer
// appeared verbatim in the command text - fragile with && chains, --fixup,
// -F files, and quoting (the parser saw everything after the closing quote on
// the same line). Now the agent commits however it likes; this extension
// checks the resulting commits afterwards and amends the correct trailer on
// when it is missing or wrong.

import { writeFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MARKER = "[co-author]";

// Vendor segment (before "/") of the model id -> noreply domain. Vendors not
// listed here accept any noreply email rather than guessing a wrong domain.
const VENDOR_DOMAINS: Record<string, string> = {
	"z-ai": "z.ai",
	anthropic: "anthropic.com",
	openai: "openai.com",
	google: "google.com",
	deepseek: "deepseek.com",
	moonshotai: "moonshot.ai",
	qwen: "qwen.ai",
	mistral: "mistral.ai",
};

function vendorOf(modelId: string): string {
	return modelId.split("/")[0];
}

function expectedTrailer(modelId: string): string | undefined {
	const domain = VENDOR_DOMAINS[vendorOf(modelId)];
	return domain ? `Co-Authored-By: ${modelId} <noreply@${domain}>` : undefined;
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

function stripTrailerLines(body: string): string {
	return body
		.split("\n")
		.filter((line) => !/^co-authored-by:/i.test(line))
		.join("\n");
}

export default function coAuthorExtension(pi: ExtensionAPI) {
	// toolCallId -> HEAD before the call ran, so tool_result knows which commits
	// are new. Only tracked for bash calls that run git commit.
	const headBefore = new Map<string, string>();

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		if (!/\bgit\s+commit\b/.test(commandOf(event.input))) return;
		const rev = await pi
			.exec("git", ["rev-parse", "HEAD"], { signal: ctx.signal })
			.catch(() => undefined);
		headBefore.set(event.toolCallId, rev && rev.code === 0 ? rev.stdout.trim() : "");
	});

	pi.on("tool_result", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const before = headBefore.get(event.toolCallId);
		if (before === undefined) return;
		headBefore.delete(event.toolCallId);

		const modelId = ctx.model?.id;
		if (!modelId) return;
		const trailer = expectedTrailer(modelId);
		if (!trailer) return;

		const rev = await pi
			.exec("git", ["rev-parse", "HEAD"], { signal: ctx.signal })
			.catch(() => undefined);
		if (!rev || rev.code !== 0) return;
		const after = rev.stdout.trim();
		if (after === before) return; // nothing committed

		// Commits created by this call.
		const rangeArgs = before ? [`${before}..${after}`] : [after];
		const list = await pi
			.exec("git", ["rev-list", "--reverse", ...rangeArgs], { signal: ctx.signal })
			.catch(() => undefined);
		if (!list || list.code !== 0) return;
		const newCommits = list.stdout.split("\n").map((l) => l.trim()).filter(Boolean);

		const bad: string[] = [];
		for (const sha of newCommits) {
			const body = await gitBody(sha, ctx.signal);
			if (body !== undefined && !hasTrailer(body, trailer)) bad.push(sha);
		}
		if (bad.length === 0) return;

		// Fast path: one new bad commit and no push in the command -> amend it
		// ourselves. Never amend when the command also pushed, since the commit
		// may already be on the remote.
		const pushInCommand = /\bgit\s+push\b/.test(commandOf(event.input));
		if (bad.length === 1 && bad[0] === after && !pushInCommand) {
			const body = await gitBody(bad[0], ctx.signal);
			if (body !== undefined) {
				const message = `${stripTrailerLines(body).trimEnd()}\n\n${trailer}\n`;
				const file = join(tmpdir(), `co-author-${Date.now()}.txt`);
				writeFileSync(file, message);
				try {
					const amend = await pi
						// --allow-empty: amending an empty commit (message-only change)
						// would otherwise be refused; for non-empty commits it is a no-op.
						.exec("git", ["commit", "--amend", "--allow-empty", "-F", file], { signal: ctx.signal })
						.catch(() => undefined);
					if (amend && amend.code === 0) {
						// Note rides in the tool result rather than ctx.ui.notify —
						// notifications render as raw chat rows that interleave with
						// the claude-style batch glance lines.
						return {
							content: [
								...event.content,
								{ type: "text", text: `${MARKER} appended trailer to ${bad[0].slice(0, 7)}` },
							],
						};
					}
				} finally {
					unlinkSync(file);
				}
			}
		}

		// Fallback: tell the agent to fix it.
		const fixHint =
			bad.length === 1
				? "Amend it and add exactly this line after a blank line at the end of the message:"
				: "Fix them (e.g. git rebase -i) and add exactly this line after a blank line at the end of each message:";
		return {
			content: [
				...event.content,
				{
					type: "text",
					text: `${MARKER} commit(s) ${bad.map((s) => s.slice(0, 7)).join(", ")} ${bad.length === 1 ? "is" : "are"} missing the required Co-Authored-By trailer. ${fixHint}\n\n  ${trailer}\n\nUse the exact model ID you are running as, not a marketing name.`,
				},
			],
		};
	});

	async function gitBody(sha: string, signal?: AbortSignal): Promise<string | undefined> {
		const log = await pi
			.exec("git", ["log", "-1", "--format=%B", sha], { signal })
			.catch(() => undefined);
		return log && log.code === 0 ? log.stdout : undefined;
	}

	function commandOf(input: unknown): string {
		return input && typeof input === "object" && "command" in input
			? String((input as { command: unknown }).command ?? "")
			: "";
	}

	// The agent never needs to think about the trailer; say so up front.
	pi.on("before_agent_start", async (event) => {
		if (event.systemPrompt.includes(`${MARKER} extension automatically amends`)) return;
		return {
			systemPrompt: `${event.systemPrompt}\n\n## Commit attribution\n\nDo not add Co-Authored-By trailers to commit messages. The ${MARKER} extension automatically amends the correct trailer (derived from the running model) onto every commit you make. Just commit normally; if a commit somehow ends up with a missing or wrong trailer, a tool-result note will tell you which commit to fix.`,
		};
	});
}

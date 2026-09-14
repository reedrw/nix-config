// Blocks plain `git commit` calls until the commit message has been shown to
// the user and the user has replied.
//
// The rule (a refinement of "message must appear in the previous assistant
// message"):
//
//   A commit is allowed when, per commit subject in the command, the
//   transcript contains
//     - the subject in a USER message (the user dictated it - that is
//       approval by definition), or
//     - the subject in ASSISTANT text (shown to the user) with at least one
//       user message AFTER that latest mention (the user saw it and spoke).
//
// `--fixup`, `--amend` and `--squash` commits are not gated: they are
// corrections inside an already-steered flow, not the reflexive
// "task done, let me commit it" move this gate exists for.
//
// Multiple `git commit` invocations in one command are each checked against
// their own subject. Commit-message-less commits (editor flow) are allowed -
// they cannot happen through the bash tool anyway.
//
// Subject matching is whitespace-normalized substring matching against
// assistant TEXT blocks only (thinking and tool results are not user-visible
// proposals, and a blocked reason echoing the subject must not become its own
// approval). All session entries are scanned, not just the active branch:
// approvals survive compaction, at the cost of counting an approval voiced on
// an abandoned branch.
//
// Escape hatches:
//   PI_NO_COMMIT_GATE=1  disables the gate for the process (checked at load,
//                        so a per-call env prefix cannot flip it)
//   !git commit ...      user-run shell commands are not gated

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MARKER = "[commit-gate]";

function commandOf(input: unknown): string {
	return input && typeof input === "object" && "command" in input
		? String((input as { command: unknown }).command ?? "")
		: "";
}

// Split a bash command into segments on unquoted && || ; | so that a commit
// message containing `&&` does not merge two commits into one segment.
function splitSegments(command: string): string[] {
	const segments: string[] = [];
	let current = "";
	let quote: string | undefined;
	for (let i = 0; i < command.length; i++) {
		const c = command[i]!;
		if (quote) {
			current += c;
			if (c === quote && command[i - 1] !== "\\") quote = undefined;
			continue;
		}
		if (c === "'" || c === '"') {
			quote = c;
			current += c;
			continue;
		}
		if ((c === "&" && command[i + 1] === "&") || (c === "|" && command[i + 1] === "|")) {
			segments.push(current);
			current = "";
			i++;
			continue;
		}
		if (c === ";" || c === "|") {
			segments.push(current);
			current = "";
			continue;
		}
		current += c;
	}
	segments.push(current);
	return segments;
}

// First -m/--message value of a segment's `git commit`, if any: quoted ('...',
// "..."), --message=v, or bare word (bash semantics: the rest is pathspec).
function messageArg(segment: string): string | undefined {
	const re = /(?:^|\s)(?:-m|--message)\s*=?(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"|(\S+))/;
	const m = re.exec(segment);
	if (!m) return undefined;
	const raw = m[1] ?? m[2] ?? m[3];
	if (raw === undefined) return undefined;
	return raw
		.replace(/\\(['"])/g, "$1")
		.split("\n")[0]
		.trim();
}

function normalize(text: string): string {
	return text.replace(/\s+/g, " ").trim();
}

// Text of a transcript message for approval matching: user string/block
// content and assistant text blocks. Deliberately excludes thinking blocks
// and tool results, which are neither proposals shown to the user nor
// user replies.
function messageText(message: unknown): string {
	if (!message || typeof message !== "object") return "";
	const m = message as { role?: unknown; content?: unknown };
	if (typeof m.content === "string") return m.content;
	if (!Array.isArray(m.content)) return "";
	let out = "";
	for (const block of m.content) {
		if (block && typeof block === "object" && "text" in block) {
			out += ` ${String((block as { text: unknown }).text)}`;
		}
	}
	return out;
}

function isApproved(subject: string, messages: unknown[]): boolean {
	const needle = normalize(subject);
	// Any assistant mention followed by any user message counts: the committing
	// turn usually restates the subject ("committing X now"), and that
	// restatement is the LAST mention - requiring a reply after the latest one
	// would void the user's approval of the original proposal.
	let firstAssistantMention = -1;
	let userDictated = false;
	for (const [i, message] of messages.entries()) {
		const role = (message as { role?: unknown } | undefined)?.role;
		if (role !== "user" && role !== "assistant") continue;
		if (!normalize(messageText(message)).includes(needle)) continue;
		if (role === "user") userDictated = true;
		else if (firstAssistantMention === -1) firstAssistantMention = i;
	}
	if (userDictated) return true;
	return (
		firstAssistantMention >= 0 &&
		messages.some(
			(message, i) =>
				i > firstAssistantMention && (message as { role?: unknown })?.role === "user",
		)
	);
}

export default function commitGateExtension(pi: ExtensionAPI) {
	const env = process.env.PI_NO_COMMIT_GATE;
	if (env !== undefined && env !== "" && env !== "0" && env.toLowerCase() !== "false") return;

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const command = commandOf(event.input);
		const subjects: string[] = [];
		for (const segment of splitSegments(command)) {
			if (!/\bgit\s+commit\b/.test(segment)) continue;
			if (/--(?:fixup|amend|squash)\b/.test(segment)) continue;
			const message = messageArg(segment);
			if (message === undefined || message === "") continue;
			subjects.push(message);
		}
		if (subjects.length === 0) return;

		const messages = (ctx.sessionManager?.getEntries() ?? [])
			.filter((entry) => (entry as { type?: unknown }).type === "message")
			.map((entry) => (entry as { message?: unknown }).message);

		const unapproved = subjects.filter((subject) => !isApproved(subject, messages));
		if (unapproved.length === 0) return;

		const listed = unapproved.map((s) => `"${s}"`).join(", ");
		return {
			block: true,
			reason: `${MARKER} not approved: ${listed}. Show the commit message to the user and wait for their explicit approval`,
		};
	});

	pi.on("before_agent_start", async (event) => {
		if (event.systemPrompt.includes("## Commit approval gate")) return;
		return {
			systemPrompt: `${event.systemPrompt}\n\n## Commit approval gate\n\nNever commit without the user's approval - they need to see and agree to what gets committed on their behalf. Plain \`git commit\` is blocked until the exact commit message was shown to the user and they explicitly approved it: propose the message, end your turn, and commit only after their explicit approval. A refusal is not approval. --fixup/--amend/--squash are not gated.`,
		};
	});
}

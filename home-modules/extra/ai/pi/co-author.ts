// Enforces a Co-Authored-By trailer on commits made by the agent.
// Blocks `git commit` bash calls whose message lacks the correct trailer for
// the running model, and injects the expected trailer into the system prompt
// so commits are right on the first try.

import { readFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

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
  mistralai: "mistral.ai",
};

function vendorOf(modelId: string): string {
  return modelId.split("/")[0];
}

function expectedTrailer(modelId: string): string | undefined {
  const domain = VENDOR_DOMAINS[vendorOf(modelId)];
  return domain ? `Co-Authored-By: ${modelId} <noreply@${domain}>` : undefined;
}

function trailerMatches(value: string, modelId: string): boolean {
  const expected = expectedTrailer(modelId);
  if (expected) return value === expected.replace(/^Co-Authored-By:\s*/, "");
  const match = /^([^<>]+?)\s*<([^<>]+)>$/.exec(value);
  return match !== null && match[1].trim() === modelId;
}

function extractTrailers(text: string): string[] {
  // Trim trailing whitespace and shell quote chars left over from -m "...".
  return [...text.matchAll(/Co-Authored-By:\s*([^\n]+)/gi)].map((m) =>
    m[1].replace(/[\s"']+$/g, ""),
  );
}

export default function coAuthorExtension(pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const command: string = event.input.command ?? "";
    if (!/\bgit\s+commit\b/.test(command)) return;

    const modelId = ctx.model?.id;
    if (!modelId) return;

    // Collect candidate message text: the command itself plus any -F/--file
    // message files (readable at preflight since the agent writes them first).
    let text = command;
    for (const [, file] of command.matchAll(/(?:-F|--file)(?:=|\s+)([^\s"']+)/g)) {
      try {
        text += `\n${readFileSync(file, "utf8")}`;
      } catch {
        // File may not exist yet; the command itself is still checked.
      }
    }

    const trailers = extractTrailers(text);
    const ok = trailers.some((t) => trailerMatches(t, modelId));
    if (ok) return;

    const expected = expectedTrailer(modelId);
    const shown =
      expected ??
      `Co-Authored-By: ${modelId} <noreply@${vendorOf(modelId)}...>`;
    const problem =
      trailers.length === 0
        ? "Commit message is missing the required co-author trailer."
        : "Commit message has the wrong Co-Authored-By trailer.";
    return {
      block: true,
      reason: `${problem} Append exactly this line after a blank line at the end of the commit message, then retry:\n\n  ${shown}\n\nUse the exact model ID you are running as, not a marketing name.`,
    };
  });

  // Give the model the trailer up front so commits pass on the first try.
  pi.on("before_agent_start", async (event, ctx) => {
    const modelId = ctx.model?.id;
    if (!modelId) return;
    const trailer = expectedTrailer(modelId);
    if (!trailer) return;
    return {
      systemPrompt: `${event.systemPrompt}\n\n## Commit attribution\n\nWhen you create commits with git commit, end the commit message with this exact trailer:\n\n${trailer}`,
    };
  });
}

// OpenCode Go plan usage for the statusline's routing line: the official
// quota endpoint (GET /zen/go/v1/usage) authenticated with the same API key
// chat completions use. The server meters the plan in dollars and returns
// per-window percentages directly — rolling 5-hour, weekly, monthly — so
// no local accounting is needed. The key is re-read from auth.json at
// fetch time (/connect rewrites it).
//
// State lives on globalThis (__piOpencodeUsage*) because this lib is
// instantiated once per importing extension entry; /reload keeps
// globalThis, so the cache and in-flight dedup survive it.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const AGENT_DIR = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
const USAGE_URL = "https://opencode.ai/zen/go/v1/usage";

// Quotas move only when the user spends; a minute is plenty fresh for a
// footer bar and keeps us far from any rate limit.
export const OPENCODE_USAGE_TTL_MS = 60_000;

// Response shape of GET /zen/go/v1/usage (dollar-metered Go plan):
// { usage: { rolling: { status, percent, resetsAt }, weekly: …, monthly: … } }
export interface OpencodeUsageWindow {
	status?: string;
	percent?: number;
	resetsAt?: string;
}
export interface OpencodeUsage {
	rolling?: OpencodeUsageWindow;
	weekly?: OpencodeUsageWindow;
	monthly?: OpencodeUsageWindow;
}

interface UsageState {
	at: number;
	data: OpencodeUsage | null; // null = last fetch failed (or no key)
}

const gt = globalThis as Record<string, unknown>;

function usageState(): UsageState | undefined {
	return gt.__piOpencodeUsage as UsageState | undefined;
}
function usageLoad(): Promise<void> | undefined {
	return gt.__piOpencodeUsageLoad as Promise<void> | undefined;
}
function setUsageLoad(p: Promise<void> | undefined): void {
	gt.__piOpencodeUsageLoad = p;
}

function apiKey(): string | null {
	try {
		const raw = JSON.parse(readFileSync(join(AGENT_DIR, "auth.json"), "utf8")) as Record<
			string,
			unknown
		>;
		for (const name of ["opencode-go", "opencode"]) {
			const entry = raw[name] as { key?: unknown } | undefined;
			if (entry && typeof entry.key === "string" && entry.key !== "") return entry.key;
		}
	} catch {
		// no/unreadable auth file — nothing to authenticate with
	}
	return null;
}

// True for models served by the OpenCode Go gateway (provider id
// "opencode-go" in the models store; the baseUrl check covers custom
// provider entries pointing at the same gateway).
export function isOpencodeGoModel(
	model: { provider?: string; baseUrl?: string } | undefined,
): boolean {
	if (!model) return false;
	if (model.provider === "opencode-go") return true;
	return typeof model.baseUrl === "string" && model.baseUrl.includes("opencode.ai/zen/go");
}

// Last fetched quota (null until the first fetch succeeds) and whether one
// is in flight right now.
export function opencodeUsage(): { data: OpencodeUsage | null; loading: boolean } {
	return { data: usageState()?.data ?? null, loading: usageLoad() !== undefined };
}

// Fire-and-forget refresh, gated by the TTL and an in-flight dedup (the
// statusline render path calls this every frame while the line is shown).
// onDone fires after every real fetch — success or failure — so callers
// can request a render of the freshly resolved state.
export function ensureOpencodeUsage(
	model: { provider?: string; baseUrl?: string } | undefined,
	onDone: () => void,
): void {
	if (!isOpencodeGoModel(model)) return;
	const s = usageState();
	if (s && Date.now() - s.at < OPENCODE_USAGE_TTL_MS) return;
	const inFlight = usageLoad();
	if (inFlight) {
		// piggyback on the pending fetch instead of racing it
		void inFlight.finally(onDone);
		return;
	}
	const load = (async () => {
		const key = apiKey();
		let data: OpencodeUsage | null = null;
		if (key) {
			try {
				const res = await fetch(USAGE_URL, { headers: { Authorization: `Bearer ${key}` } });
				if (!res.ok) throw new Error(String(res.status));
				const body = (await res.json()) as any;
				const usage = body?.usage;
				data = usage && typeof usage === "object" ? (usage as OpencodeUsage) : null;
			} catch {
				data = null;
			}
		}
		gt.__piOpencodeUsage = { at: Date.now(), data };
	})();
	setUsageLoad(load.finally(() => setUsageLoad(undefined)));
	void load.finally(onDone);
}

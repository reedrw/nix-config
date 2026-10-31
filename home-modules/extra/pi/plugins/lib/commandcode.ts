// Command Code plan usage for the statusline's expanded line: the provider's
// own alpha quota endpoints (the ones pi-commandcode-provider's
// /commandcode-quota command and its usage report read), authenticated with
// the same API key chat completions use. The server meters the plan in
// credits and reports its two windows (rolling 5-hour, weekly) as used/cap
// pairs, so no local accounting is needed. The key is re-read at fetch time
// (/connect and /login rewrite auth.json).
//
// State lives on globalThis (__piCommandcodeUsage*) because this lib is
// instantiated once per importing extension entry; /reload keeps globalThis,
// so the cache and in-flight dedup survive it. Same shape as lib/opencode.ts,
// which does the equivalent job for the OpenCode Go gateway.

import { readFileSync } from "node:fs";
import { agentPath } from "./agent-dir.ts";

const DEFAULT_API_BASE = "https://api.commandcode.ai";
// Quotas move only when the user spends; a minute is plenty fresh for a
// footer bar and keeps us far from any rate limit.
export const COMMANDCODE_USAGE_TTL_MS = 60_000;
const TIMEOUT_MS = 15_000;

// The provider's API base ends in /provider/v1; the quota endpoints hang off
// the root, so strip the suffix exactly like pi-commandcode-provider does.
function legacyApiBase(base: string): string {
	return base.replace(/\/+$/, "").replace(/\/provider\/v1$/, "");
}

const API_BASE = legacyApiBase(process.env.COMMANDCODE_API_BASE ?? DEFAULT_API_BASE);

// One metered window of the plan (`/alpha/billing/credits` → windowLimits).
export interface CommandcodeWindow {
	/** Credits spent in this window. */
	used: number;
	/** Credits the window grants. */
	cap: number;
	/** Reset time, epoch milliseconds (null when the API omitted it). */
	resetAt: number | null;
}

export interface CommandcodeUsage {
	account?: string;
	planId?: string | null;
	fiveHour?: CommandcodeWindow;
	weekly?: CommandcodeWindow;
	/** Remaining credit pool and what the billing period has spent so far. */
	credits?: { remaining: number; spent?: number };
}

interface UsageState {
	at: number;
	data: CommandcodeUsage | null; // null = last fetch failed (or no key)
}

const gt = globalThis as Record<string, unknown>;

function usageState(): UsageState | undefined {
	return gt.__piCommandcodeUsage as UsageState | undefined;
}
function usageLoad(): Promise<void> | undefined {
	return gt.__piCommandcodeUsageLoad as Promise<void> | undefined;
}
function setUsageLoad(p: Promise<void> | undefined): void {
	gt.__piCommandcodeUsageLoad = p;
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function numberValue(value: unknown): number | undefined {
	return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : undefined;
}

function stringValue(value: unknown): string | undefined {
	return typeof value === "string" && value.length > 0 ? value : undefined;
}

// Epoch milliseconds from either form the API uses (ms digits or an ISO
// stamp); the provider normalizes to seconds, we keep milliseconds.
function resetAtValue(value: unknown): number | null {
	const n =
		typeof value === "number"
			? value
			: typeof value === "string" && value.trim() !== ""
				? /^\d+$/.test(value.trim())
					? Number(value.trim())
					: Date.parse(value)
				: undefined;
	if (n === undefined || !Number.isFinite(n) || n <= 0) return null;
	return n < 1e12 ? n * 1000 : n;
}

function windowValue(value: unknown): CommandcodeWindow | undefined {
	if (!isRecord(value)) return undefined;
	const used = numberValue(value.used);
	const cap = numberValue(value.cap);
	if (used === undefined || cap === undefined || (used === 0 && cap === 0)) return undefined;
	return { used, cap, resetAt: resetAtValue(value.resetAt) };
}

function credentialKey(value: unknown): string | undefined {
	if (!isRecord(value)) return undefined;
	if (value.type === "oauth") return stringValue(value.access);
	return stringValue(value.key) ?? stringValue(value.access);
}

// Mirror pi-commandcode-provider's api-key.ts lookup: env first, then the
// several shapes auth.json may hold a Command Code key under.
function apiKey(): string | null {
	const env = process.env;
	const fromEnv = env.COMMAND_CODE_API_KEY ?? env.COMMANDCODE_API_KEY;
	if (fromEnv) return fromEnv;
	try {
		const raw = JSON.parse(readFileSync(agentPath("auth.json"), "utf8")) as Record<string, unknown>;
		const candidates = ["commandcode", "command-code"];
		for (const name of candidates) {
			const direct = stringValue(raw[name]);
			if (direct) return direct;
			const entry = credentialKey(raw[name]);
			if (entry) return entry;
		}
		return stringValue(raw.apiKey) ?? null;
	} catch {
		// no/unreadable auth file — nothing to authenticate with
	}
	return null;
}

// True for models served by Command Code (provider id "commandcode" in the
// provider's registration; the baseUrl check covers catalog entries pointing
// at the same host).
export function isCommandcodeModel(
	model: { provider?: string; baseUrl?: string } | undefined,
): boolean {
	if (!model) return false;
	if (model.provider === "commandcode") return true;
	return typeof model.baseUrl === "string" && model.baseUrl.includes("api.commandcode.ai");
}

// Last fetched quota (null until the first fetch succeeds) and whether one
// is in flight right now.
export function commandcodeUsage(): { data: CommandcodeUsage | null; loading: boolean } {
	return { data: usageState()?.data ?? null, loading: usageLoad() !== undefined };
}

async function fetchUsage(key: string): Promise<CommandcodeUsage | null> {
	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
	const headers = { accept: "application/json", Authorization: `Bearer ${key}` };
	let orgId: string | undefined;

	const get = async (path: string, params: Record<string, string | undefined> = {}) => {
		const search = new URLSearchParams();
		for (const [name, value] of Object.entries(params)) {
			if (value) search.set(name, value);
		}
		const query = search.toString();
		const res = await fetch(`${API_BASE}${path}${query ? `?${query}` : ""}`, {
			headers,
			signal: controller.signal,
		});
		if (!res.ok) throw new Error(`${path} failed (${res.status})`);
		return (await res.json()) as unknown;
	};

	// Billing/subscription/summary are independent sections upstream too, so a
	// failing one drops its own bits instead of blanking the whole line.
	const safeGet = async (
		path: string,
		params: Record<string, string | undefined> = {},
	): Promise<unknown> => {
		try {
			return await get(path, params);
		} catch {
			return undefined;
		}
	};

	try {
		// whoami carries the account/org the billing endpoints are scoped to
		const whoami = await get("/alpha/whoami");
		const user = isRecord(whoami) && isRecord(whoami.user) ? whoami.user : undefined;
		const org = isRecord(whoami) && isRecord(whoami.org) ? whoami.org : undefined;
		const account =
			(org ? stringValue(org.login) : undefined) ?? (user ? stringValue(user.userName) : undefined);
		orgId = org ? stringValue(org.id) : undefined;

		const [creditsRaw, subscriptionRaw] = await Promise.all([
			safeGet("/alpha/billing/credits", { orgId }),
			safeGet("/alpha/billing/subscriptions", { orgId }),
		]);

		const data: CommandcodeUsage = { account, planId: null };

		const credits = isRecord(creditsRaw) && isRecord(creditsRaw.credits) ? creditsRaw.credits : undefined;
		const windows =
			isRecord(creditsRaw) && isRecord(creditsRaw.windowLimits) ? creditsRaw.windowLimits : undefined;
		data.fiveHour = windowValue(windows?.fiveHour);
		data.weekly = windowValue(windows?.weekly);
		if (credits) {
			const remaining =
				(numberValue(credits.monthlyCredits) ?? 0) +
				(numberValue(credits.purchasedCredits) ?? 0) +
				(numberValue(credits.freeCredits) ?? 0);
			data.credits = { remaining };
		}

		const subscription =
			isRecord(subscriptionRaw) && isRecord(subscriptionRaw.data) ? subscriptionRaw.data : undefined;
		const periodStart = subscription ? stringValue(subscription.currentPeriodStart) : undefined;
		if (subscription) data.planId = stringValue(subscription.planId) ?? null;

		// The billing-period spend is what `used` means for the credit pool;
		// without it the line reports the bare remainder.
		const summary = await safeGet("/alpha/usage/summary", { orgId, since: periodStart });
		const spent = isRecord(summary) ? numberValue(summary.totalCost) : undefined;
		if (spent !== undefined && data.credits) data.credits.spent = spent;

		const known =
			data.fiveHour !== undefined ||
			data.weekly !== undefined ||
			data.credits !== undefined;
		return known ? data : null;
	} catch {
		return null;
	} finally {
		clearTimeout(timer);
	}
}

// Fire-and-forget refresh, gated by the TTL and an in-flight dedup (the
// statusline render path calls this every frame while the line is shown).
// onDone fires after every real fetch — success or failure — so callers
// can request a render of the freshly resolved state.
export function ensureCommandcodeUsage(
	model: { provider?: string; baseUrl?: string } | undefined,
	onDone: () => void,
): void {
	if (!isCommandcodeModel(model)) return;
	const s = usageState();
	if (s && Date.now() - s.at < COMMANDCODE_USAGE_TTL_MS) return;
	const inFlight = usageLoad();
	if (inFlight) {
		// piggyback on the pending fetch instead of racing it
		void inFlight.finally(onDone);
		return;
	}
	const load = (async () => {
		const key = apiKey();
		const data = key ? await fetchUsage(key) : null;
		gt.__piCommandcodeUsage = { at: Date.now(), data } satisfies UsageState;
	})();
	setUsageLoad(load.finally(() => setUsageLoad(undefined)));
	void load.finally(onDone);
}

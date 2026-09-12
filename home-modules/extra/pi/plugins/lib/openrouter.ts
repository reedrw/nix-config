// Shared OpenRouter plumbing for pin-provider.ts and the statusline: pin
// state, endpoint/policy metadata caches, live routing capture, and the
// provider-pin dialog. Extend pin-provider.ts by copying it plus this file
// (and lib/custom-ui.ts, which owns the OSC 8 openUrl patch that makes the
// dialog's clickable headers work — the /pin-provider command and the
// request injection work without it).
//
// This lib is instantiated once per importing extension entry, so ALL
// cross-extension state lives on globalThis ("__piOpenrouter*" keys):
// pins, caches, in-flight loads, captured routing, the dialog's
// header-click sink, and the last known session UI context. /reload keeps
// globalThis, so state survives reloads.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { linkWrap, registerActionUrlHandler } from "./custom-ui.ts";

export const PIN_URL = "pi-action://pin-provider/open";
const SORT_URL_RE = /^pi-action:\/\/pin-provider\/sort\/(\d)$/;

const AGENT_DIR = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
const PINS_FILE = join(AGENT_DIR, "extension-data", "openrouter-pins.json");
const ENDPOINTS_TTL_MS = 5 * 60_000;

// ── OpenRouter routing capture ────────────────────────────────
//
// pi-ai's openai-completions parser drops OpenRouter's routing metadata: the
// `provider` field on every SSE chunk and the actual billed `usage.cost` on
// the final usage chunk. Patch globalThis.fetch once (globalThis flag —
// /reload re-imports this module and would otherwise chain a second patch)
// and tee the SSE of openrouter.ai chat-completions responses to harvest
// both. The tee'd branch is drained in the background and never disturbs
// pi's own read of the original body. State lives on globalThis so a
// reloaded instance reads what the surviving patch captures.

interface OrRouting {
	provider: string | null;
	cost: number | null; // OpenRouter's billed cost for the latest request
	at: number; // Date.now() of the last captured request
	bump?: () => void; // current instance's render nudge
}

const ROUTING_KEY = "__piOpenrouterRouting";

function routing(): OrRouting {
	const gt = globalThis as Record<string, unknown>;
	let r = gt[ROUTING_KEY] as OrRouting | undefined;
	if (!r) {
		r = { provider: null, cost: null, at: 0 };
		gt[ROUTING_KEY] = r;
	}
	return r;
}

function ingestRoutingChunk(chunk: any): void {
	const provider = typeof chunk?.provider === "string" && chunk.provider !== "" ? chunk.provider : null;
	const raw = chunk?.usage?.cost ?? null;
	const cost = typeof raw === "number" ? raw : typeof raw === "string" && raw !== "" ? Number(raw) : null;
	if (provider === null && !(cost != null && Number.isFinite(cost))) return;
	const r = routing();
	if (provider !== null) r.provider = provider;
	if (cost != null && Number.isFinite(cost)) r.cost = cost;
	r.at = Date.now();
	r.bump?.();
}

// Consume a tee'd response body and feed every SSE data line (or a JSON
// fallback) to ingestRoutingChunk. Aborts and network errors are expected
// here (pi may cancel the stream) — swallow everything.
function drainRoutingClone(clone: Response): void {
	const ct = clone.headers.get("content-type") ?? "";
	if (ct.includes("text/event-stream") && clone.body) {
		void (async () => {
			try {
				const reader = clone.body!.getReader();
				const decoder = new TextDecoder();
				let buf = "";
				for (;;) {
					const { done, value } = await reader.read();
					if (done) break;
					buf += decoder.decode(value, { stream: true });
					let nl: number;
					while ((nl = buf.indexOf("\n")) !== -1) {
						const line = buf.slice(0, nl).trim();
						buf = buf.slice(nl + 1);
						if (!line.startsWith("data:")) continue;
						const data = line.slice(5).trim();
						if (data === "" || data === "[DONE]") continue;
						try {
							ingestRoutingChunk(JSON.parse(data));
						} catch {
							// partial/invalid SSE line — ignore
						}
					}
				}
			} catch {
				// aborted stream — stop harvesting
			}
		})();
	} else if (ct.includes("json")) {
		void clone
			.text()
			.then((text) => ingestRoutingChunk(JSON.parse(text)))
			.catch(() => {});
	}
}

const OPENROUTER_URL_RE = /openrouter\.ai\/api\/v1\/chat\/completions/;

function installRoutingFetchPatch(): void {
	const gt = globalThis as Record<string, unknown> & { fetch: typeof fetch };
	const flag = gt as { __piOpenrouterFetchPatched?: boolean };
	if (flag.__piOpenrouterFetchPatched) return;
	flag.__piOpenrouterFetchPatched = true;
	const original = gt.fetch.bind(gt);
	gt.fetch = async (input: any, init?: any) => {
		const url = typeof input === "string" ? input : input instanceof URL ? input.href : (input?.url as string) ?? "";
		const res = await original(input, init);
		try {
			if (OPENROUTER_URL_RE.test(url) && res.ok) drainRoutingClone(res.clone());
		} catch {
			// teeing must never break the real request
		}
		return res;
	};
}

// ── OpenRouter endpoint metadata (public, no auth) ────────────
//
// The endpoints API lists every routed provider for a model with its
// quantization, 1-day uptime, and provider-reported throughput. We match the
// entry against the routed provider captured from the stream above.

interface EndpointCache {
	modelId: string;
	at: number;
	data: any[] | null;
}

// cross-extension state lives on globalThis (per-importing-extension module
// instances would otherwise keep separate caches — see the file header)
const gt_ = globalThis as Record<string, unknown>;
function endpointCache(): EndpointCache | null {
	return (gt_.__piOpenrouterEndpointCache as EndpointCache | undefined) ?? null;
}
function endpointLoad(): Promise<void> | null {
	return (gt_.__piOpenrouterEndpointLoad as Promise<void> | undefined) ?? null;
}
function setEndpointLoad(p: Promise<void> | null): void {
	gt_.__piOpenrouterEndpointLoad = p;
}

function loadEndpointData(modelId: string, onDone: () => void): Promise<void> {
	gt_.__piOpenrouterEndpointCache = { modelId, at: Date.now(), data: null };
	const load = (async () => {
		try {
			const res = await fetch(`https://openrouter.ai/api/v1/models/${modelId}/endpoints`);
			if (!res.ok) throw new Error(String(res.status));
			const body = (await res.json()) as any;
			// the whole list is cached; the entry matching the routed provider is
			// picked lazily at render time (routing can change between loads)
			const endpoints = (body?.data?.endpoints ?? []) as any[];
			const c = endpointCache();
			if (c && c.modelId === modelId) {
				c.data = endpoints.length > 0 ? endpoints : null;
			}
		} catch {
			const c = endpointCache();
			if (c && c.modelId === modelId) c.data = null;
		} finally {
			onDone();
		}
	})();
	setEndpointLoad(load.finally(() => setEndpointLoad(null)));
	return load;
}

function endpointFor(modelId: string, provider: string | null): { data: any | null; loading: boolean } {
	const c = endpointCache();
	if (!c || c.modelId !== modelId) return { data: null, loading: false };
	if (!Array.isArray(c.data)) return { data: null, loading: endpointLoad() !== null };
	if (provider === null) return { data: null, loading: false };
	const match = c.data.find((e: any) => e.provider_name === provider);
	return { data: match ?? null, loading: false };
}

// ── OpenRouter provider pin ──────────────────────────────
//
// Routing to a specific upstream is only steerable per request:
// `"provider": { "order": [slug], "allow_fallbacks": false }` in the
// chat-completions body. Pins live in a mutable state file keyed by the
// full OpenRouter model id ("author/slug") and are injected into every
// matching request via before_provider_request (below). globalThis mirror
// so a /reload re-reads the file instead of chaining a second patch.

const PINS_KEY = "__piOpenrouterPins";

function orPins(): Record<string, string> {
	const gt = globalThis as Record<string, unknown>;
	let pins = gt[PINS_KEY] as Record<string, string> | undefined;
	if (!pins) {
		pins = {};
		try {
			const raw = JSON.parse(readFileSync(PINS_FILE, "utf8")) as unknown;
			if (raw && typeof raw === "object" && !Array.isArray(raw)) {
				for (const [k, v] of Object.entries(raw as Record<string, unknown>)) {
					if (k !== "" && typeof v === "string" && v !== "") pins[k] = v;
				}
			}
		} catch {
			// no pin file yet — fine
		}
		gt[PINS_KEY] = pins;
	}
	return pins;
}

function setOrPin(modelId: string, slug: string | null): void {
	const pins = orPins();
	if (slug) pins[modelId] = slug;
	else delete pins[modelId];
	mkdirSync(join(AGENT_DIR, "extension-data"), { recursive: true });
	writeFileSync(PINS_FILE, JSON.stringify(pins, null, "\t") + "\n");
}

// Data-handling fields (training, prompt retention) are NOT in the public
// endpoints API, but the public model page embeds them. Two shapes live in
// its payload: provider_info.dataPolicy (camelCase, provider-level — matches
// the standard endpoints the API lists) and per-endpoint data_policy
// (snake_case, the only shape carrying retentionDays). The page also lists
// batch-variant endpoints (":batch" suffix) whose retention differs by
// design — those are skipped so their policy never leaks onto the standard
// endpoint the picker shows. Anything missing stays null and the dialog
// simply omits it.
interface OrPolicy {
	slug: string | null;
	training: boolean | null; // provider trains on user data
	retainsPrompts: boolean | null;
	retentionDays: number | null;
}

interface PolicyCache {
	modelId: string;
	at: number;
	data: Record<string, OrPolicy>;
	statsByEp: Record<string, number>;
}

function policyCache(): PolicyCache | null {
	return (gt_.__piOpenrouterPolicyCache as PolicyCache | undefined) ?? null;
}
function policyLoad(): Promise<void> | null {
	return (gt_.__piOpenrouterPolicyLoad as Promise<void> | undefined) ?? null;
}
function setPolicyLoad(p: Promise<void> | null): void {
	gt_.__piOpenrouterPolicyLoad = p;
}

function loadPolicies(modelId: string): Promise<void> {
	const inFlight = policyLoad();
	if (inFlight) return inFlight;
	gt_.__piOpenrouterPolicyCache = { modelId, at: Date.now(), data: {}, statsByEp: {} };
	const load = (async () => {
		try {
			const res = await fetch(`https://openrouter.ai/${modelId}`);
			if (!res.ok) throw new Error(String(res.status));
			const html = await res.text();
			const data: Record<string, OrPolicy> = {};
			const statsByEp: Record<string, number> = {};
			// Each endpoint appears several times (RSC chunks carry copies);
			// merge field-wise so a later complete copy fills earlier gaps.
			const nameRe = /\\?"provider_name\\?":\\?"([^"\\]+)\\?"/g;
			for (let m: RegExpExecArray | null; (m = nameRe.exec(html)) !== null; ) {
				const name = m[1];
				// slug and provider-level policy follow directly in provider_info
				const win = html.slice(m.index, m.index + 3000);
				const cur = (data[name] ??= { slug: null, training: null, retainsPrompts: null, retentionDays: null });
				if (cur.slug === null) cur.slug = /\\?"slug\\?":\\?"([^"\\]+)/.exec(win)?.[1] ?? null;
				const pol = /\\?"dataPolicy\\?":\{[^{]*\}/.exec(win)?.[0];
				if (pol && cur.retainsPrompts === null) {
					cur.training = /\\?"training\\?":(true|false)/.exec(pol)?.[1] === "true";
					cur.retainsPrompts = /\\?"retainsPrompts\\?":(true|false)/.exec(pol)?.[1] === "true";
				}
			}
			// retentionDays and measured throughput (stats.p50_throughput — the
			// public API's throughput_last_30m is null everywhere these days)
			// live on the per-endpoint object, whose provider_name can be
			// anywhere in the (large) object — associate by brace-balancing out
			// to that object. Strings in the payload (ids, URLs) contain no
			// braces, so balancing is safe.
			const polRe = /\\?"data_policy\\?":\{/g;
			for (let m: RegExpExecArray | null; (m = polRe.exec(html)) !== null; ) {
				const brace = m.index + m[0].length - 1;
				const span = enclosingObject(html, brace);
				if (!span) continue;
				const obj = html.slice(span[0], span[1] + 1);
				const name = /\\?"provider_name\\?":\\?"([^"\\]+)/.exec(obj)?.[1];
				const epName = /\\?"name\\?":\\?"([^"\\]+)/.exec(obj)?.[1] ?? "";
				if (!name || epName.includes(":batch")) continue;
				const cur = (data[name] ??= { slug: null, training: null, retainsPrompts: null, retentionDays: null });
				const days = /\\?"retentionDays\\?":(-?\d+)/.exec(obj)?.[1];
				if (days != null && cur.retentionDays === null) cur.retentionDays = Number(days);
				const tps = /\\?"p50_throughput\\?":([0-9.]+)/.exec(obj)?.[1];
				if (tps != null && statsByEp[epName] === undefined) statsByEp[epName] = Number(tps);
			}
			const c = policyCache();
			if (c && c.modelId === modelId) {
				c.data = data;
				c.statsByEp = statsByEp;
			}
		} catch {
			const c = policyCache();
			if (c && c.modelId === modelId) {
				c.data = {};
				c.statsByEp = {};
			}
		} finally {
			setPolicyLoad(null);
		}
	})();
	setPolicyLoad(load);
	return load;
}

// Span of the object that contains position `inside` (a `{`), via balance.
// Returns [openBrace, closeBrace] indexes or null when unbalanced.
function enclosingObject(html: string, inside: number): [number, number] | null {
	let depth = 0;
	let start = -1;
	for (let i = inside - 1; i >= 0; i--) {
		const c = html[i];
		if (c === "}") depth++;
		else if (c === "{") {
			if (depth === 0) {
				start = i;
				break;
			}
			depth--;
		}
	}
	if (start < 0) return null;
	let d = 0;
	for (let i = start; i < html.length; i++) {
		if (html[i] === "{") d++;
		else if (html[i] === "}") {
			d--;
			if (d === 0) return [start, i];
		}
	}
	return null;
}

// Merged view of one model's upstream providers for the picker: endpoints
// API for price/quant/uptime/throughput, page scrape for slug + data policy.
interface OrProviderView {
	name: string;
	slug: string | null; // OpenRouter routing slug (provider.order entry)
	quantization: string | null;
	inPrice: number | null; // USD per M input tokens
	outPrice: number | null; // USD per M output tokens
	uptime: number | null; // last 1d, percent
	throughput: number | null; // last 30m, tok/s
	policy: OrPolicy | null;
}

function providersFor(modelId: string): OrProviderView[] {
	const cache = endpointCache();
	if (!cache || cache.modelId !== modelId || !Array.isArray(cache.data)) return [];
	const pol = policyCache();
	const livePol = pol && pol.modelId === modelId ? pol : null;
	const policies = livePol?.data ?? {};
	const statsByEp = livePol?.statsByEp ?? {};
	const views: OrProviderView[] = [];
	for (const ep of cache.data) {
		const name = ep?.provider_name;
		if (typeof name !== "string") continue;
		const policy = policies[name] ?? null;
		const tag = typeof ep.tag === "string" ? ep.tag : "";
		views.push({
			name,
			slug: policy?.slug ?? (tag.includes("/") ? tag.split("/")[0] : tag || null),
			quantization: typeof ep.quantization === "string" ? ep.quantization : null,
			inPrice: numPerM(ep?.pricing?.prompt),
			outPrice: numPerM(ep?.pricing?.completion),
			uptime: typeof ep.uptime_last_1d === "number" ? ep.uptime_last_1d : null,
			throughput:
				statsByEp[ep.name] ?? (typeof ep.throughput_last_30m === "number" ? ep.throughput_last_30m : null),
			policy,
		});
	}
	views.sort((a, b) => (a.inPrice ?? Infinity) - (b.inPrice ?? Infinity) || a.name.localeCompare(b.name));
	return views;
}

// USD/token string -> USD per million tokens
function numPerM(v: unknown): number | null {
	if (typeof v !== "string" && typeof v !== "number") return null;
	const n = typeof v === "number" ? v : Number(v);
	return Number.isFinite(n) ? n * 1e6 : null;
}

// Resolved slug -> display name (endpoint provider_name), for the footer.
function pinDisplayName(modelId: string, slug: string): string {
	const cache = endpointCache();
	if (cache?.modelId === modelId && Array.isArray(cache.data)) {
		for (const ep of cache.data) {
			const name = ep?.provider_name;
			const policy = policiesFor(modelId)[name as string];
			const tag = typeof ep?.tag === "string" ? ep.tag : "";
			const s = policy?.slug ?? (tag.includes("/") ? tag.split("/")[0] : tag || null);
			if (s === slug && typeof name === "string") return name;
		}
	}
	return slug;
}

function policiesFor(modelId: string): Record<string, OrPolicy> {
	const c = policyCache();
	return c && c.modelId === modelId ? c.data : {};
}

// USD per million tokens, as a bare table cell (the header carries the unit)
function fmtPrice(perM: number): string {
	if (perM >= 1) return `$${perM.toFixed(2)}`;
	if (perM >= 0.1) return `$${perM.toFixed(3).replace(/0+$/, "").replace(/\.$/, "")}`;
	return `$${perM.toFixed(4).replace(/0+$/, "").replace(/\.$/, "")}`;
}

// tok/s colour follows the statusline's live-meter thresholds
// (red < 30, yellow < 80, green >= 80)
function tpsRole(tps: number | null): string {
	return tps == null ? "muted" : tps >= 80 ? "success" : tps >= 30 ? "warning" : "error";
}

// quantization precision: full/8-bit → success (fp8/int8 are near-lossless
// and what providers actually serve — e.g. Z.ai's own endpoints),
// 4-bit → warning, unknown → muted
function quantRole(q: string | null): string {
	if (!q || q === "unknown") return "muted";
	const u = q.toUpperCase();
	if (u === "BF16" || u === "FP16" || u === "FP8" || u === "INT8") return "success";
	return "warning"; // fp4 / int4 / nf4 / int2 …
}
export async function openPinDialog(ctxArg?: any, opts?: { onRequestRender?: () => void }): Promise<void> {
	const onRequestRender = opts?.onRequestRender;
	const ctx = ctxArg ?? ((globalThis as Record<string, unknown>).__piOpenrouterUiCtx as any);
	const model = ctx?.model as { provider?: string; id?: string } | undefined;
	if (!ctx?.ui || model?.provider !== "openrouter" || !model.id) {
		if (ctx?.hasUI) ctx.ui.notify("Provider pinning works with OpenRouter models only", "warning");
		return;
	}
	const modelId: string = model.id;
	// header-click sink is installed inside the component and always
	// cleared here when the dialog closes (dialogs are sequential)
	const clearSortSink = () => {
      delete (globalThis as Record<string, unknown>).__piOpenrouterSortSink;
    };

    let result: { slug: string | null } | null = null;
    try {
      result = (await ctx.ui.custom((
        tui: any,
      theme: any,
      _kb: unknown,
      done: (v: { slug: string | null } | null) => void,
      ) => {
        let sel = 0; // index into items
        let rows: OrProviderView[] = [];
        let ready = false; // endpoint data loaded (policies may lag)
        let cachedLines: string[] | undefined;
        // table layout budget (the tui knows the real terminal width even
        // before the first render call)
        const widthBudget = Math.max(20, tui?.terminal?.columns ?? 80);

        // ── column sorting ──
        // click a header (pi-action://pin-provider/sort/<i>) or press 1-8;
        // same column again flips the direction. Defaults per column:
        // ascending for lower-is-better (prices, retention, name, marks,
        // quant), descending for higher-is-better (uptime, throughput).
        const DEFAULT_ASC = [true, true, true, true, true, false, false, true];
        let sortCol = 3; // 💵 in $/M — cheapest first, like before
        let sortAsc = true;

        const sortKey = (v: OrProviderView, col: number): number | string | null => {
          switch (col) {
            case 0:
              return v.name.toLowerCase();
            case 1: {
              // pinned first, then routed, then the rest
              const pinSlug = orPins()[modelId];
              let m = 0;
              if (v.slug && pinSlug === v.slug) m += 2;
              if (routing().provider === v.name) m += 1;
              return m;
            }
            case 2:
              return v.quantization && v.quantization !== "unknown" ? v.quantization.toUpperCase() : "\uffff";
            case 3:
              return v.inPrice;
            case 4:
              return v.outPrice;
            case 5:
              return v.uptime;
            case 6:
              return v.throughput;
            case 7: {
              const p = v.policy;
              if (p?.retainsPrompts === false) return 0; // zero retention first
              if (p?.retainsPrompts === true) return p.retentionDays != null ? p.retentionDays : 3650;
              return null; // unknown always last
            }
            default:
              return null;
          }
        };

        const applySortOrder = (keepName: string | null): void => {
          rows.sort((a, b) => {
            const ka = sortKey(a, sortCol);
            const kb = sortKey(b, sortCol);
            let r: number;
            if (ka == null && kb == null) r = 0;
            else if (ka == null) r = 1; // missing values sort last, both directions
            else if (kb == null) r = -1;
            else {
              r = typeof ka === "string" ? String(ka).localeCompare(String(kb)) : (ka as number) - (kb as number);
              if (!sortAsc) r = -r;
            }
            return r !== 0 ? r : a.name.localeCompare(b.name);
          });
          if (keepName != null) {
            const idx = rows.findIndex((r) => r.name === keepName);
            if (idx >= 0) sel = idx + 1;
            else sel = Math.min(sel, rows.length);
          } else if (sel > rows.length) {
            sel = rows.length;
          }
        };

        const applySort = (col: number): void => {
          if (!ready || col < 0 || col > HEADER.length - 1) return;
          if (sortCol === col) sortAsc = !sortAsc;
          else {
            sortCol = col;
            sortAsc = DEFAULT_ASC[col];
          }
          const keepName = sel > 0 ? rows[sel - 1]?.name ?? null : null;
          applySortOrder(keepName);
          computeWidths();
          refresh();
        };

        // header clicks land here via the extension's action-URL handler;
        // the sink is cleared by openPinDialog's finally when the dialog closes
        (globalThis as Record<string, unknown>).__piOpenrouterSortSink = applySort;

        const refresh = () => {
          cachedLines = undefined;
          tui.requestRender();
        };

        const rebuild = () => {
          const keepName = sel > 0 ? rows[sel - 1]?.name ?? null : null;
          rows = providersFor(modelId);
          ready = true;
          applySortOrder(keepName);
          computeWidths();
          refresh();
        };

        const endpCache = endpointCache();
        const polCache = policyCache();
        const endpFresh =
          endpCache &&
          endpCache.modelId === modelId &&
          Date.now() - endpCache.at < ENDPOINTS_TTL_MS &&
          Array.isArray(endpCache.data);
        const polFresh =
          polCache &&
          polCache.modelId === modelId &&
          Date.now() - polCache.at < ENDPOINTS_TTL_MS;
        void Promise.all([
          endpFresh ? Promise.resolve() : loadEndpointData(modelId, () => onRequestRender?.()),
          polFresh ? Promise.resolve() : loadPolicies(modelId),
        ]).then(rebuild);

        const handleInput = (data: string): boolean => {
          if (data.length === 1 && data >= "1" && data <= "8") {
            applySort(Number(data) - 1);
            return true;
          }
          if (matchesKey(data, "up")) {
            sel = Math.max(0, sel - 1);
            refresh();
            return true;
          }
          if (matchesKey(data, "down")) {
            sel = Math.min(rows.length, sel + 1); // automatic row is index 0..rows
            refresh();
            return true;
          }
          if (matchesKey(data, "escape")) {
            done(null);
            return true;
          }
          if (matchesKey(data, "enter") || matchesKey(data, "return")) {
            if (!ready) return true; // ignore while loading
            done({ slug: sel === 0 ? null : rows[sel - 1].slug });
            return true;
          }
          return false;
        };

        // One line per provider, aligned like a table across all rows:
        // name · marks · quantization · in/out $/M · 1d uptime · tok/s ·
        // retention. Column widths are computed from the data (visibleWidth,
        // so the emoji in the headers stay aligned); numeric columns
        // right-align. "—" means OpenRouter doesn't report the value (e.g.
        // no recent traffic for the tok/s column). The name column is the
        // flexible one: it shrinks (with …) when the terminal is narrow.
        const HEADER = ["Provider", "", "🧬 quant", "💵 in $/M", "💸 out $/M", "📶 up 1d", "⚡ tok/s", "🔒 retention"];
        const RIGHT = [false, false, false, true, true, true, true, false];
        const SORT_URL = (i: number) => `pi-action://pin-provider/sort/${i}`;
        // the active column carries a ▲/▼ direction marker
        const headerCells = (): string[] =>
          HEADER.map((h, i) => (i === sortCol ? `${h}${sortAsc ? " ▲" : " ▼"}` : h));
        let widths: number[] = HEADER.map((h) => visibleWidth(h));

        // pad to a target VISIBLE width (emoji are 2 cells, not 2 UTF-16 units)
        const padTo = (s: string, w: number, right: boolean): string => {
          const fill = Math.max(0, w - visibleWidth(s));
          return right ? " ".repeat(fill) + s : s + " ".repeat(fill);
        };

        const providerCells = (v: OrProviderView): string[] => {
          const pinSlug = orPins()[modelId];
          const routed = routing().provider === v.name;
          const marks = (v.slug && pinSlug === v.slug ? "📌" : "") + (routed ? "🟢" : "");
          const quant =
            v.quantization && v.quantization !== "unknown" ? v.quantization.toUpperCase() : "—";
          let retain: string;
          if (v.policy?.retainsPrompts === true) {
            retain = v.policy.retentionDays != null ? `${v.policy.retentionDays}d` : "yes";
          } else if (v.policy?.retainsPrompts === false) {
            retain = "zero";
          } else {
            retain = "—";
          }
          if (v.policy?.training === true) retain += " 🚨";
          return [
            v.name,
            marks,
            quant,
            v.inPrice != null ? fmtPrice(v.inPrice) : "—",
            v.outPrice != null ? fmtPrice(v.outPrice) : "—",
            v.uptime != null ? `${v.uptime.toFixed(1)}%` : "—",
            v.throughput != null ? `${Math.round(v.throughput)}` : "—",
            retain,
          ];
        };

        const computeWidths = (): void => {
          widths = headerCells().map((h) => visibleWidth(h));
          for (const v of rows) {
            const c = providerCells(v);
            for (let i = 0; i < c.length; i++) widths[i] = Math.max(widths[i], visibleWidth(c[i]));
          }
          // fit the table to the terminal: the name column absorbs the
          // overflow (with ellipsis); anything still too wide is clamped
          // again at render time
          const avail = widthBudget - (widths.length - 1) * 2;
          if (widths.reduce((a, b) => a + b, 0) > avail) {
            const others = widths.slice(1).reduce((a, b) => a + b, 0);
            widths[0] = Math.max(6, avail - others);
          }
        };

        // Pad plain cells to the column layout, then colorize each padded
        // slice (padding first keeps the table aligned under color).
        const padRow = (cells: string[], colors: string[]): string => {
          let line = "";
          cells.forEach((s, i) => {
            if (i > 0) line += "  ";
            line += theme.fg(colors[i], padTo(s, widths[i], RIGHT[i]));
          });
          return line;
        };

        const rowLine = (v: OrProviderView, selected: boolean): string => {
          const prefix = selected ? theme.fg("accent", "▸ ") : "  ";
          const colors = ["text", "muted", quantRole(v.quantization), "muted", "muted", "muted", tpsRole(v.throughput), "muted"];
          const cells = providerCells(v);
          if (cells[7].includes("zero")) colors[7] = "success";
          if (cells[7].includes("🚨")) colors[7] = "warning";
          cells[0] = truncateToWidth(cells[0], Math.max(1, widths[0]), "…");
          let line = padRow(cells, colors);
          // recolor the pin/routed marks inside the (padded) marks cell
          line = line.replace("📌", theme.fg("success", "📌")).replace("🟢", theme.fg("accent", "🟢"));
          return truncateToWidth(prefix + line, widthBudget);
        };

        const render = (width: number): string[] => {
          if (cachedLines) return cachedLines;
          const lines: string[] = [];
          const border = theme.fg("accent", "─".repeat(Math.max(1, width)));
          lines.push(border);
          lines.push(` ${theme.fg("accent", theme.bold("📌 Provider pin"))} ${theme.fg("dim", modelId)}`);
          if (!ready) {
            lines.push(` ${theme.fg("dim", "loading provider metadata…")}`);
          } else if (rows.length === 0) {
            lines.push(` ${theme.fg("warning", "no endpoint data available for this model")}`);
          } else {
            lines.push("");
            // clickable header (one OSC 8 span per cell — never nested)
            const headerLine = headerCells()
              .map((h, i) => linkWrap(theme.fg("dim", padTo(h, widths[i], RIGHT[i])), SORT_URL(i)))
              .join("  ");
            lines.push(truncateToWidth(`  ${headerLine}`, widthBudget));
            // automatic row + table rows, windowed
            const total = rows.length + 1;
            const visible = Math.min(total, 14);
            const top = Math.min(Math.max(0, sel - (visible - 1)), Math.max(0, total - visible));
            if (top > 0) lines.push(theme.fg("dim", `  ↑ ${top} more`));
            for (let i = top; i < Math.min(total, top + visible); i++) {
              if (i === 0) {
                lines.push(`${i === sel ? theme.fg("accent", "▸ ") : "  "}${theme.fg("dim", "↺ automatic routing (clear pin)")}`);
              } else {
                lines.push(rowLine(rows[i - 1], i === sel));
              }
            }
            const below = total - top - visible;
            if (below > 0) lines.push(theme.fg("dim", `  ↓ ${below} more`));
          }
          lines.push("");
          lines.push(` ${theme.fg("dim", "↑↓ navigate · enter pin · 1-8 or click a header to sort · esc close")}`);
          lines.push(` ${theme.fg("dim", "📌 pinned · 🟢 routed now · 🚨 trains on data · — not reported")}`);
          lines.push(` ${theme.fg("dim", "pinned per model, survives restarts · 🟢🟡🔴 colour grades quality")}`);
          lines.push(border);
          cachedLines = lines;
          return lines;
        };

        return {
          render,
          invalidate: () => {
            cachedLines = undefined;
          },
          handleInput,
        };
      }) as { slug: string | null } | null);
    } finally {
      clearSortSink();
    }

    if (result) {
      setOrPin(modelId, result.slug);
      ctx.ui.notify(
        result.slug
          ? `Pinned ${modelId} → ${pinDisplayName(modelId, result.slug)}`
          : "Pin cleared — OpenRouter routes automatically",
        "info",
      );
      onRequestRender?.();
    }
  };

// Last known session UI context — set by the importing extensions (the
// command handler and the statusline footer) so the lib's own action-URL
// handler can open the dialog even when no extension ctx is at hand.
export function setSharedUiCtx(ctx: unknown): void {
	(globalThis as Record<string, unknown>).__piOpenrouterUiCtx = ctx;
}

// ── action URLs owned by this lib ────────────────────────────
//
// installPinActions() registers ONE id-keyed handler for PIN_URL (opens the
// dialog using the shared UI context) and the sort URLs (dispatch to the
// open dialog's sink). A /reload replaces the registration (same id) instead
// of stacking a stale closure — see registerActionUrlHandler in custom-ui.ts.

export function installPinActions(): void {
	registerActionUrlHandler(
		(url) => {
			if (url === PIN_URL) {
				void openPinDialog();
				return true;
			}
			const sortMatch = SORT_URL_RE.exec(url);
			if (sortMatch) {
				const sink = (globalThis as Record<string, unknown>).__piOpenrouterSortSink as
					| ((col: number) => void)
					| undefined;
				sink?.(Number(sortMatch[1]));
				return true;
			}
			return false;
		},
		"openrouter-pin",
	);
}

// OpenRouter endpoint metadata loader with TTL, for display code that
// doesn't open the dialog (the statusline routing line).
export function ensureEndpointData(
	model: { provider?: string; id?: string } | undefined,
	onDone: () => void,
): void {
	if (!model || model.provider !== "openrouter" || !model.id) return;
	const c = endpointCache();
	if (c && c.modelId === model.id && Date.now() - c.at < ENDPOINTS_TTL_MS) return;
	void loadEndpointData(model.id, onDone);
}

export {
	// live routing capture (statusline footer display)
	installRoutingFetchPatch,
	routing,
	type OrRouting,
	// endpoint metadata for display code
	endpointFor,
	type OrProviderView,
	// pin state (footer chip)
	orPins,
	pinDisplayName,
};

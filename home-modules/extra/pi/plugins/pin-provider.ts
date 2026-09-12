// Pin an OpenRouter model to a specific upstream provider.
//
// OpenRouter routes a model across upstreams (DeepInfra, Fireworks, …) that
// differ in price, quantization, uptime, throughput and data policy. This
// extension pins the current model to one upstream: every subsequent
// request for that model is sent with
//   `provider: { order: [slug], allow_fallbacks: false }`
// so a dead pinned provider errors instead of silently re-routing — which
// is what "pin" should mean. The choice persists across restarts in
// ~/.pi/agent/extension-data/openrouter-pins.json.
//
// /pin-provider opens the provider table (price, quantization, uptime,
// tok/s, data retention — sortable by column, click a header or press 1-8).
// The statusline's routing line links to the same dialog via this lib.
//
// Self-contained apart from ./lib/openrouter.ts (all state and data
// plumbing) and ./lib/custom-ui.ts (OSC 8 openUrl patch — without it the
// clickable headers are inert, but /pin-provider and the injection still
// work). State survives /reload; pins survive restarts.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { installPinActions, openPinDialog, orPins, setSharedUiCtx } from "./lib/openrouter.ts";

export default function pinProviderExtension(pi: ExtensionAPI) {
	// Own the pin/sort action URLs (idempotent; the statusline falls back to
	// the same lib if this extension is absent).
	installPinActions();

	// The dialog needs a session context; capture the freshest one.
	pi.on("session_start", (_event, ctx) => {
		setSharedUiCtx(ctx);
	});

	// Apply the pin to every outgoing request for a pinned OpenRouter model.
	// openrouter.ai accepts `provider: { order: [slug], allow_fallbacks: false }`
	// in the chat-completions body to route to one upstream and forbid
	// fallback (a dead pinned provider errors instead of silently re-routing,
	// which is what "pin" should mean).
	pi.on("before_provider_request", (event, ctx) => {
		if ((ctx.model as { provider?: string } | undefined)?.provider !== "openrouter") return;
		const p = event.payload as { model?: unknown } | null;
		if (!p || typeof p !== "object" || typeof (p as any).model !== "string") return;
		const slug = orPins()[(p as { model: string }).model];
		if (!slug) return;
		return { ...p, provider: { order: [slug], allow_fallbacks: false } };
	});

	pi.registerCommand("pin-provider", {
		description: "Pin the current OpenRouter model to a specific provider",
		handler: async (_args, ctx) => {
			setSharedUiCtx(ctx);
			await openPinDialog(ctx);
		},
	});
}

// Remember the last model/provider used and restore it at startup.
//
// pi's own "save as startup default" (Ctrl+S in /model) writes
// defaultModel/defaultProvider into ~/.pi/agent/settings.json — which is
// declaratively managed by home-manager, so the saved value resets on every
// switch. This extension persists the last model selection to a mutable state
// file instead and applies it on the next interactive startup:
//   - model_select (source "set"/"cycle") -> save {provider, modelId}
//   - session_start (reason "startup")    -> apply the saved model via
//     pi.setModel(), falling back silently to the settings default when the
//     state file is missing, corrupt, or the model no longer exists.
// Session switch flows are untouched: /resume, /fork and friends restore the
// session's own model (source "restore", never saved here) — it then simply
// becomes the remembered one the next time it's set or cycled.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
const stateFile = join(agentDir, "extension-data", "remember-model.json");

interface SavedModel {
	provider: string;
	modelId: string;
}

function loadSaved(): SavedModel | undefined {
	try {
		const raw = JSON.parse(readFileSync(stateFile, "utf8")) as Partial<SavedModel>;
		if (typeof raw.provider === "string" && typeof raw.modelId === "string") {
			return { provider: raw.provider, modelId: raw.modelId };
		}
	} catch {
		// Missing or corrupt state: fall back to the settings default.
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("model_select", async (event) => {
		// "restore" fires on /resume etc. — the session's own model, not a choice.
		if (event.source === "restore") return;
		mkdirSync(join(agentDir, "extension-data"), { recursive: true });
		writeFileSync(
			stateFile,
			JSON.stringify({ provider: event.model.provider, modelId: event.model.id } satisfies SavedModel, null, "\t") + "\n",
		);
	});

	// Only override the startup default; session switches manage their own model.
	pi.on("session_start", async (event, ctx) => {
		if (event.reason !== "startup") return;
		const saved = loadSaved();
		if (!saved) return;
		if (ctx.model?.id === saved.modelId && ctx.model.provider === saved.provider) return;
		const model = ctx.modelRegistry.find(saved.provider, saved.modelId);
		if (!model) return; // catalog changed; keep the settings default
		const ok = await pi.setModel(model);
		if (!ok && ctx.hasUI) {
			ctx.ui.notify(`remember-model: ${saved.provider}/${saved.modelId} has no API key; using the default`, "warning");
		}
	});
}

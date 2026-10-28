import { homedir } from "node:os";
import { join } from "node:path";

/**
 * The agent directory Pi runs from: `$PI_CODING_AGENT_DIR`, else `~/.pi/agent`.
 *
 * Extensions that read their own data files (`model-behaviors.json`, the pet's
 * frames) must resolve them from here rather than from `import.meta.url`: when
 * an extension is compiled into Pi-Bolt, Bun constant-folds that URL to the
 * build-time path, which does not exist on the machine running the build's
 * output.
 */
export function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi/agent");
}

/** A path under the agent directory, e.g. `agentPath("extensions", "pet-assets")`. */
export function agentPath(...parts: string[]): string {
	return join(agentDir(), ...parts);
}

import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { constants, existsSync } from "node:fs";
import { access, readFile, stat, unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { promisify } from "node:util";
import type { ImageContent } from "./content.ts";

const execFileAsync = promisify(execFile);

export const IMAGE_MIME_TYPES = ["image/png", "image/jpeg", "image/gif", "image/webp"] as const;
export const IMAGE_CLIPBOARD_MAX_BYTES = 50 * 1024 * 1024;
export const TEXT_CLIPBOARD_MAX_BYTES = 10 * 1024 * 1024;
const CLIPBOARD_TIMEOUT_MS = 1500;

type ExecResult = { stdout: string | Buffer };
type ClipboardExec = (file: string, args: readonly string[], options: { timeout: number; maxBuffer: number; encoding?: "buffer" | "utf8" }) => Promise<ExecResult>;

export type ClipboardDeps = {
	execFile?: ClipboardExec;
	access?: (path: string, mode?: number) => Promise<void>;
};

export type ClipboardPayload =
	| { kind: "image"; image: ImageContent }
	| { kind: "text"; text: string }
	| { kind: "empty" };

type LinuxBackend = "wl-paste" | "xclip" | "xsel";

function runClipboardCommand(file: string, args: readonly string[], maxBuffer: number, deps: ClipboardDeps): Promise<ExecResult> {
	const run = deps.execFile ?? ((command, commandArgs, options) => execFileAsync(command, [...commandArgs], options) as Promise<ExecResult>);
	return run(file, args, { timeout: CLIPBOARD_TIMEOUT_MS, maxBuffer, encoding: "buffer" });
}

function outputBuffer(stdout: string | Buffer): Buffer {
	return Buffer.isBuffer(stdout) ? stdout : Buffer.from(stdout);
}

function outputText(stdout: string | Buffer): string | undefined {
	const bytes = outputBuffer(stdout);
	if (bytes.length === 0 || bytes.length > TEXT_CLIPBOARD_MAX_BYTES) return undefined;
	return bytes.toString("utf8");
}

export function supportsDirectClipboard(env: NodeJS.ProcessEnv = process.env, platform: NodeJS.Platform = process.platform): boolean {
	return platform === "darwin" || platform === "win32" || Boolean(env.WSL_DISTRO_NAME || env.WSL_INTEROP);
}

/**
 * `access(path, X_OK)` also succeeds for a directory, so a directory named
 * `xclip` on PATH would register as the executable. Require a regular file.
 */
async function executableAt(path: string, mode?: number): Promise<void> {
	const stats = await stat(path);
	if (!stats.isFile()) throw new Error(`${path} is not a regular file`);
	await access(path, mode ?? constants.X_OK);
}

async function executableExists(command: string, env: NodeJS.ProcessEnv, deps: ClipboardDeps): Promise<boolean> {
	const checkAccess = deps.access ?? executableAt;
	const directories = (env.PATH ?? "").split(delimiter).filter(Boolean);
	for (const directory of directories) {
		try {
			await checkAccess(join(directory, command), constants.X_OK);
			return true;
		} catch {
			// Keep searching PATH asynchronously.
		}
	}
	return false;
}

let backendCache: { signature: string; backend: LinuxBackend } | undefined;

function backendSignature(env: NodeJS.ProcessEnv): string {
	return [env.PATH ?? "", env.WAYLAND_DISPLAY ?? "", env.DISPLAY ?? ""].join("\u0000");
}

/**
 * Probing PATH costs one filesystem call per directory, and a paste should not
 * pay for it on every keystroke. Only a successful probe is cached: caching a
 * negative result would keep direct paste disabled for the rest of the process
 * even after the user installs `wl-paste`. A miss costs one scan per session
 * start, because without a backend this module never handles a paste at all.
 * Injected dependencies bypass the cache so tests stay deterministic.
 */
async function resolveLinuxBackend(env: NodeJS.ProcessEnv, deps: ClipboardDeps): Promise<LinuxBackend | undefined> {
	if (deps.access || deps.execFile) return linuxBackend(env, deps);
	const signature = backendSignature(env);
	if (backendCache?.signature === signature) return backendCache.backend;
	const backend = await linuxBackend(env, deps);
	backendCache = backend ? { signature, backend } : undefined;
	return backend;
}

/** Drops the cached probe so a vanished command is rediscovered on the next read. */
function forgetLinuxBackend(): void {
	backendCache = undefined;
}

async function linuxBackend(env: NodeJS.ProcessEnv, deps: ClipboardDeps): Promise<LinuxBackend | undefined> {
	if (env.WAYLAND_DISPLAY && await executableExists("wl-paste", env, deps)) return "wl-paste";
	// Many Wayland desktops also expose XWayland. Fall back to its clipboard
	// tools when wl-clipboard is not installed instead of disabling direct paste.
	if (!env.DISPLAY) return undefined;
	if (await executableExists("xclip", env, deps)) return "xclip";
	return (await executableExists("xsel", env, deps)) ? "xsel" : undefined;
}

/** Asynchronously determines whether this runtime can replace Pi's built-in paste handler. */
export async function canReadDirectClipboard(
	env: NodeJS.ProcessEnv = process.env,
	platform: NodeJS.Platform = process.platform,
	deps: ClipboardDeps = {},
): Promise<boolean> {
	if (supportsDirectClipboard(env, platform)) return true;
	return platform === "linux" && Boolean(await resolveLinuxBackend(env, deps));
}

async function macImage(): Promise<ImageContent | undefined> {
	for (const [clipboardClass, extension, mimeType] of [
		["PNGf", "png", "image/png"],
		["JPEG", "jpg", "image/jpeg"],
	] as const) {
		const file = join(tmpdir(), `pi-image-view-clipboard-${randomUUID()}.${extension}`);
		try {
			await execFileAsync("osascript", [
				"-e", `set imageData to the clipboard as «class ${clipboardClass}»`,
				"-e", `set outputFile to open for access POSIX file ${JSON.stringify(file)} with write permission`,
				"-e", "set eof of outputFile to 0",
				"-e", "write imageData to outputFile",
				"-e", "close access outputFile",
			], { timeout: CLIPBOARD_TIMEOUT_MS, maxBuffer: 1024 * 1024 });
			const bytes = await readFile(file);
			if (bytes.length > 0 && bytes.length <= IMAGE_CLIPBOARD_MAX_BYTES) {
				return { type: "image", data: bytes.toString("base64"), mimeType };
			}
		} catch {
			// Try the next format, then text.
		} finally {
			try { await unlink(file); } catch { /* best effort */ }
		}
	}
	return undefined;
}

function powershellExecutable(platform: NodeJS.Platform): string {
	if (platform === "win32") return "powershell.exe";
	for (const candidate of [
		"/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
		"/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe",
	]) if (existsSync(candidate)) return candidate;
	return "powershell.exe";
}

async function windowsImage(platform: NodeJS.Platform): Promise<ImageContent | undefined> {
	const script = [
		"$ErrorActionPreference = 'Stop'",
		"Add-Type -AssemblyName System.Windows.Forms | Out-Null",
		"Add-Type -AssemblyName System.Drawing | Out-Null",
		"$img = [System.Windows.Forms.Clipboard]::GetImage()",
		"if ($img -eq $null) { exit 2 }",
		"$ms = New-Object System.IO.MemoryStream",
		"$img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)",
		"[Console]::Out.Write([Convert]::ToBase64String($ms.ToArray()))",
	].join("; ");
	try {
		const { stdout } = await execFileAsync(powershellExecutable(platform), ["-NoProfile", "-NonInteractive", "-STA", "-Command", script], {
			timeout: 2500, encoding: "utf8", maxBuffer: 70 * 1024 * 1024,
		});
		const data = stdout.trim();
		const bytes = Buffer.from(data, "base64");
		return bytes.length > 0 && bytes.length <= IMAGE_CLIPBOARD_MAX_BYTES
			? { type: "image", data, mimeType: "image/png" }
			: undefined;
	} catch { return undefined; }
}

async function clipboardText(platform: NodeJS.Platform): Promise<string | undefined> {
	try {
		const { stdout } = platform === "darwin"
			? await execFileAsync("pbpaste", [], { timeout: CLIPBOARD_TIMEOUT_MS, encoding: "utf8", maxBuffer: TEXT_CLIPBOARD_MAX_BYTES })
			: await execFileAsync(powershellExecutable(platform), ["-NoProfile", "-NonInteractive", "-Command", "[Console]::Out.Write((Get-Clipboard -Raw))"], { timeout: 2500, encoding: "utf8", maxBuffer: TEXT_CLIPBOARD_MAX_BYTES });
		return stdout || undefined;
	} catch { return undefined; }
}

function targets(stdout: string | Buffer): Set<string> {
	return new Set(outputBuffer(stdout).toString("utf8").split(/[\r\n]+/).map((target) => target.trim()).filter(Boolean));
}

function imageTarget(available: Set<string>): (typeof IMAGE_MIME_TYPES)[number] | undefined {
	return IMAGE_MIME_TYPES.find((mimeType) => available.has(mimeType));
}

function textTarget(available: Set<string>): string | undefined {
	return ["UTF8_STRING", "text/plain;charset=utf-8", "text/plain", "STRING"].find((target) => available.has(target));
}

async function linuxClipboard(backend: LinuxBackend, deps: ClipboardDeps): Promise<ClipboardPayload> {
	try {
		if (backend === "xsel") {
			// xsel has no target-selection option: its -t flag is a retrieval timeout,
			// so it is deliberately text-only rather than pretending it can request image MIME.
			const { stdout } = await runClipboardCommand("xsel", ["--clipboard", "--output"], TEXT_CLIPBOARD_MAX_BYTES, deps);
			const text = outputText(stdout);
			return text ? { kind: "text", text } : { kind: "empty" };
		}
		const listArgs = backend === "wl-paste" ? ["--list-types"] : ["-selection", "clipboard", "-out", "-target", "TARGETS"];
		const { stdout: listed } = await runClipboardCommand(backend, listArgs, TEXT_CLIPBOARD_MAX_BYTES, deps);
		const available = targets(listed);
		const imageMime = imageTarget(available);
		if (imageMime) {
			const imageArgs = backend === "wl-paste" ? ["--no-newline", "--type", imageMime] : ["-selection", "clipboard", "-out", "-target", imageMime];
			const { stdout } = await runClipboardCommand(backend, imageArgs, IMAGE_CLIPBOARD_MAX_BYTES, deps);
			const bytes = outputBuffer(stdout);
			if (bytes.length > 0 && bytes.length <= IMAGE_CLIPBOARD_MAX_BYTES) return { kind: "image", image: { type: "image", data: bytes.toString("base64"), mimeType: imageMime } };
		}
		const target = textTarget(available);
		if (!target) return { kind: "empty" };
		const textArgs = backend === "wl-paste" ? ["--no-newline", "--type", target] : ["-selection", "clipboard", "-out", "-target", target];
		const { stdout } = await runClipboardCommand(backend, textArgs, TEXT_CLIPBOARD_MAX_BYTES, deps);
		const text = outputText(stdout);
		return text ? { kind: "text", text } : { kind: "empty" };
	} catch {
		return { kind: "empty" };
	}
}

export async function readDirectClipboard(
	env: NodeJS.ProcessEnv = process.env,
	platform: NodeJS.Platform = process.platform,
	deps: ClipboardDeps = {},
): Promise<ClipboardPayload> {
	if (platform === "linux" && !supportsDirectClipboard(env, platform)) {
		const backend = await resolveLinuxBackend(env, deps);
		if (!backend) return { kind: "empty" };
		const payload = await linuxClipboard(backend, deps);
		// A failed read can mean the command was uninstalled since the probe.
		if (payload.kind === "empty") forgetLinuxBackend();
		return payload;
	}
	if (!supportsDirectClipboard(env, platform)) return { kind: "empty" };
	const image = platform === "darwin" ? await macImage() : await windowsImage(platform);
	if (image) return { kind: "image", image };
	const text = await clipboardText(platform);
	return text ? { kind: "text", text } : { kind: "empty" };
}

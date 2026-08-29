/**
 * Debug logging utility for pi-image-view.
 *
 * Set the PI_IMAGE_VIEW_DEBUG environment variable to enable debug output.
 * Logs are written to stderr so they don't interfere with terminal rendering.
 *
 * @example
 *   PI_IMAGE_VIEW_DEBUG=1 pi
 */
const DEBUG_ENABLED = Boolean(process.env.PI_IMAGE_VIEW_DEBUG);

export function debugLog(message: string, error?: unknown): void {
	if (!DEBUG_ENABLED) return;

	const prefix = "[pi-image-view]";
	if (error) {
		console.error(prefix, message, error);
	} else {
		console.error(prefix, message);
	}
}

# shellcheck shell=bash
# ExecStartPre guard for the kitty-server systemd service: refuses to start
# (exit 1) when a live kitty single-instance primary already exists, because
# `kitty --single-instance` would then JOIN it — opening a stray visible
# window running the server's sleep child — and the client would exit 0,
# leaving the service dead.
#
# Single-instance sockets live at /tmp/kitty-<pid>; the pid in the name is
# the primary's pid, so liveness is checked via /proc/<pid>/comm. A crashed
# kitty leaves a stale socket whose pid is gone (or reused by a non-kitty
# process), which the comm check ignores — the service then legitimately
# takes over as primary.
shopt -s nullglob
for sock in /tmp/kitty-*; do
	[[ -S $sock ]] || continue
	pid=${sock##*/kitty-}
	[[ $pid =~ ^[0-9]+$ ]] || continue
	if [[ ! -r /proc/$pid/comm ]]; then
		continue # stale socket, primary is gone
	fi
	comm=$(< "/proc/$pid/comm")
	# nixpkgs wraps kitty's ELF, so the kernel comm is `.kitty-wrapped`
	if [[ $comm == kitty* || $comm == .kitty-wrapped ]]; then
		echo "kitty-server: live single-instance primary exists (pid $pid), skipping start" >&2
		exit 1
	fi
done

# Privileges & elevation

You run as user `reed` (in `wheel`). You generally do NOT have — and should not
use — `sudo` or `run0`. Any elevation pops an interactive polkit password prompt
for the operator, who must inspect and approve it.

## Commands that never need root

Run these directly as `reed`; never prefix them with `sudo` or `run0`:

- `journalctl` — wheel grants read access to all journal logs.
- Read-only `systemctl` verbs: `status`, `show`, `cat`, `list-units`,
  `list-unit-files`, `list-timers`, `list-sockets`, `list-jobs`,
  `list-dependencies`, `is-active`, `is-enabled`, `is-failed`,
  `is-system-running`, `show-environment`.

## If you think you need elevation

1. First, check whether the task actually needs it — most inspection does not.
2. If it genuinely does, stop and explain to the operator what command you want
   to run as root and why, before running it. They will approve the polkit
   prompt if it's justified.
3. Never wrap elevated commands in `sh -c` or otherwise obscure what the
   operator will see in the prompt. What they approve is what runs.

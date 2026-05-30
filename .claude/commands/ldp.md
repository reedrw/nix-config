First, run `ldp $ARGUMENTS`.

If `$ARGUMENTS` contains ` -- `, treat everything before ` -- ` as the ldp arguments and everything after as additional instructions to follow *after* the command has been run.

After completing any additional instructions, always rerun the original ldp command (the part before ` -- `, or the full `$ARGUMENTS` if there was no ` -- `) to confirm the changes achieved what the user asked for.

# Output budget

Every token of tool output stays in the conversation and is re-read on every later turn, so a
careless `cat` or an unfiltered test run compounds. This is the shared read/output discipline for
the heavy run skills (`feature`, `fix`, `remediate`, `upgrade`, `deploy`, `docs`, `lint`,
`test-generate`, `review`, `audit`). It changes how much is printed, never what is checked.

1. **Locate, then read a range.** Use `grep -n` to find the anchor, then `Read` with
   `offset`/`limit` or `sed -n 'a,bp'`. Never `cat` a file over 150 lines whole. Don't re-read a
   file already read in this conversation unless it changed (exception: rule 6).
2. **Specs and blueprints: read once.** Afterwards, grep the heading of the section you need and
   read only that section.
3. **Tests and lint: summary first.** Trimming output never hides the exit code: redirect to a log,
   keep `rc`, then show only the tail, and judge pass/fail on `rc`, not on the tail (a bare
   `cmd | tail` reports tail's status, not the command's).
   Pattern (portable to bash and zsh; log under the run's docs folder or a `mktemp` file):
   `cmd > {log} 2>&1; rc=$?; tail -n 40 {log}; echo "exit=$rc"`
   - phpunit: `--no-progress` with that pattern (`tail -n 40`); on failure, re-run only the failing
     test with `--filter`.
   - phpcs: `--report=summary` first, then `--report=emacs` on the failing files only, same pattern
     with `head -n 60 {log}`.
   - `bin/magento` setup/compile: same pattern with `tail -n 20 {log}`; a non-zero `rc` is a
     failure (deploy stops and rolls back) however clean the tail looks.
4. **Long outputs go to a file.** Logs, smoke runs, dumps go to a file under the run's docs
   folder. Print only the path, a count and the error lines.
5. **Create files with the Write tool,** not heredoc-plus-echo chains.
6. **Plugin files: read the section, not the file.** Grep the anchor and read only that section.
   Never `sed -n 1,200p` a whole SKILL.md or reference.
   Exception: when a skill tells you to read a `references/` file at a phase, read that file whole
   with the Read tool, and re-read it after a context compaction or whenever the skill says to
   (e.g. every smoke iteration).
7. **Browser smoke: summaries, not page dumps.** Use the plugin's runner scripts and print the
   summary path, not page dumps.

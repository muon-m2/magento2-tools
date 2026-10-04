# Output budget

Every token of tool output stays in the conversation and is re-read on every later turn, so a
careless `cat` or an unfiltered test run compounds. This is the shared read/output discipline for
the heavy run skills (`feature`, `fix`, `remediate`, `upgrade`, `deploy`, `docs`, `lint`,
`test-generate`, `review`, `audit`). It changes how much is printed, never what is checked.

1. **Locate, then read a range.** Use `grep -n` to find the anchor, then `Read` with
   `offset`/`limit` or `sed -n 'a,bp'`. Never `cat` a file over 150 lines whole. Don't re-read a
   file already read in this conversation unless it changed.
2. **Specs and blueprints: read once.** Afterwards, grep the heading of the section you need and
   read only that section.
3. **Tests and lint: summary first.**
   - phpunit: `--no-progress … 2>&1 | tail -n 40`; on failure, re-run only the failing test with
     `--filter`.
   - phpcs: `--report=summary` first, then `--report=emacs` on the failing files only,
     `| head -n 60`.
   - `bin/magento` setup/compile: `| tail -n 20`.
4. **Long outputs go to a file.** Logs, smoke runs, dumps go to a file under the run's docs
   folder. Print only the path, a count and the error lines.
5. **Create files with the Write tool,** not heredoc-plus-echo chains.
6. **Plugin files: read the section, not the file.** Grep the anchor and read only that section.
   Never `sed -n 1,200p` a whole SKILL.md or reference.
7. **Browser smoke: summaries, not page dumps.** Use the plugin's runner scripts and print the
   summary path, not page dumps.

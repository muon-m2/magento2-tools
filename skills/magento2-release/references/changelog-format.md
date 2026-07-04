# CHANGELOG Format

Structure, entry-category vocabulary, linking, and the multi-module-repo layout are
defined once, canonically, in `magento2-context/references/changelog-format.md`. This
file covers only release's "populate" step: mapping commits to categories and generating
entries.

## Sourcing Entries from Commits

| Commit                       | Category                                     |
|------------------------------|----------------------------------------------|
| `feat:`                      | Added                                        |
| `fix:`                       | Fixed                                        |
| `refactor:`                  | Changed (if user-visible) else skip          |
| `perf:`                      | Changed                                      |
| `deprecation:`               | Deprecated                                   |
| `security:`                  | Security                                     |
| `BREAKING CHANGE:` body      | Changed (and notes "BREAKING:" in the entry) |
| `docs:` / `chore:` / `test:` | Skip                                         |

## Generating Entries

The skill generates an initial draft from the commit messages, then presents it for the
user to edit before committing. Commit subjects are sometimes terse — users may want to
expand them for the changelog.

## Anti-Patterns

- Single-bullet release ("- bug fixes") — list specifics.
- Internal language ("refactored XYZModel") — describe the user-visible effect.
- Mixing tenses — use past tense for what was done in the release.
- Linking to internal issue trackers visible only to the team — use public references.

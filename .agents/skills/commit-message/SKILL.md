---
name: commit-message
description: "Generate a concise commit message from staged Git changes or current Perforce workspace changes. Use when asked to write, draft, or generate a commit message."
argument-hint: "Optional: Git stash reference or Jira/task ID"
user-invocable: true
---

# Generate a Commit Message

Inspect the staged Git change or current Perforce workspace change, infer its primary intent, and return only the commit message in a plain-text code block. This skill is strictly read-only: never commit, submit, push, stage, unstage, revert, or otherwise modify repository state or files. Do not invoke any command or tool that performs these actions.

## Select and inspect the change

1. Identify the repository and version-control system from the current workspace.
2. For Git, inspect only the index (staged changes), using `git diff --cached --stat` and `git diff --cached` (or equivalent read-only commands). Do not use the stash or include unstaged working-tree changes. If the staged diff is empty, say so and ask the user to stage the intended changes.
3. For Perforce, inspect the current workspace's opened files and their diffs. Use read-only commands such as `p4 opened` and `p4 diff -du`. Never submit, shelve, revert, or otherwise modify Perforce state.
4. If the VCS cannot be identified, the change cannot be read, or the diff is empty, report that explicitly rather than inventing a message.
5. Read enough of the diff and surrounding context to understand the purpose, user-visible or operational effect, and any known Jira/task identifier. Do not infer a ticket number that is not present in the user's input or change context.

## Decide the message size

Count changed files and added plus deleted lines from the change summary. Classify it as **small only when all** of these are true:

- It expresses one narrowly scoped intent.
- It changes no more than 2 files and no more than 30 lines in total.
- It does not alter a public interface, data/schema format, security behavior, build/release configuration, or behavior across multiple components.

If any condition is false, classify it as **large**. When counts are unavailable, use the large format rather than guessing that a change is small.

## Write the message

### Subject

- Use one line of at most 50 characters, counting the emoji and punctuation.
- Begin with exactly one task-type emoji from this mapping:
  - `✨` Feature
  - `🪲` Bugfix
  - `♻️` Refactoring, cleanup, or removal of unused code
  - `⚡` Performance
  - `🔧` Configuration
  - `📝` Documentation
  - `👷` Build system, infrastructure, Jenkins, or CI
  - `🛡️` Security
  - `🚨` Hotfix
  - `⬆️` Dependency upgrade
  - `⏪` Revert
  - `🚀` Release
  - `🚧` Work in progress or experiment
- After the emoji and a space, write one concise imperative sentence. Start it with a capitalized verb from this list: Add, Create, Implement, Enable, Update, Improve, Enhance, Optimize, Refactor, Simplify, Rename, Extend, Remove, Drop, Deprecate, Disable, Fix, Adjust, Handle, Prevent, Configure, Build, Migrate, Revert, Merge, Truncate, or Clarify.
- End the sentence with a period. Keep it specific to the main intent; shorten wording as needed to stay within 50 characters.

### Small change

Return only the subject line.

### Large change

After the subject, add a blank line and 3-5 bullet lines. Keep every bullet on one line and the entire body to at most 5 lines. Describe the conceptual reason and outcome of the change, not implementation mechanics or affected filenames. Prioritize the most important changes; do not pad the list with minor details.

Optionally add a blank line followed by 1-2 lines of searchable, single-word tags. Use a `Tags:` prefix and comma-separated words; include a known Jira/task identifier here. Omit the tagline if no useful search tags or identifier are available.

## Output

Return only the finished message inside a plain-text code block, with no explanation, headings, or alternative drafts. Preserve the required blank lines and line limits. Generating the message is the only action: do not create a commit, submit a changelist, push to a remote, or run any follow-up VCS operation.

Fetch and display comments from the current GitHub pull request, then walk through them one by one to fix.

## Steps

1. Capture PR identity. Run:
   ```bash
   pr_json=$(GITHUB_TOKEN= gh pr view --json number,url,headRefName,baseRefName,headRepositoryOwner,headRepository)
   pr_number=$(jq -r '.number' <<<"$pr_json")
   pr_owner=$(jq -r '.headRepositoryOwner.login' <<<"$pr_json")
   pr_repo=$(jq -r '.headRepository.name' <<<"$pr_json")
   pr_branch=$(jq -r '.headRefName' <<<"$pr_json")
   ```

   The `GITHUB_TOKEN=` prefix clears an env-set token for that command so `gh` falls back to its keyring credentials (broader scope). If you see "gh: not authenticated", run `gh auth login`. Apply the same prefix to every `gh` call.

2. Fetch PR-level (issue) comments:
   ```bash
   GITHUB_TOKEN= gh api "/repos/$pr_owner/$pr_repo/issues/$pr_number/comments"
   ```

3. Fetch review comments:
   ```bash
   GITHUB_TOKEN= gh api "/repos/$pr_owner/$pr_repo/pulls/$pr_number/comments"
   ```
   Parse `body`, `diff_hunk`, `path`, `line`, `in_reply_to_id`, etc. To inspect referenced source:
   ```bash
   # Node fallback for portability (base64 -d vs -D differs between Linux/macOS):
   GITHUB_TOKEN= gh api "/repos/$pr_owner/$pr_repo/contents/$path?ref=$pr_branch" \
     | node -e 'process.stdout.write(Buffer.from(JSON.parse(require("fs").readFileSync(0,"utf8")).content,"base64").toString())'
   ```
   For files >1 MB the `contents` API returns `"content": ""` and an `errors` array — check for that before decoding.

4. Display the comments as a numbered list using the Format below. Include both PR-level and review comments, preserve reply threading, and show file/line context.

5. Then iterate through the actionable comments (skip bot-only noise and pure nits unless asked), one at a time:
   - State the comment number and what it asks for.
   - Fix it (follow the repo's own conventions in `.claude/CLAUDE.md`).
   - Move to the next one.

   If the user passed arguments (e.g. specific comment numbers), only handle those.

## Format

```
## Comments

[For each comment thread:]
N. @author `file.ts#line`:
   ```diff
   [diff_hunk from the API response]
   ```
   > quoted comment text

   [any replies indented]
```

If there are no comments, return "No comments found."

## Guidelines

- Always use `GITHUB_TOKEN=` before `gh`, and take owner/repo from `gh pr view --json headRepositoryOwner,headRepository` rather than inferring from cwd.
- Use `jq` to parse the API JSON.
- Only show the actual comments in the list, no extra explanatory text.

$ARGUMENTS

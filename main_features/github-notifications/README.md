# GitHub Notification Audit

GitHub Notification Audit checks repository-level subscription state for every
active repository owned by the authenticated GitHub account. It includes public
and private repositories returned by the account, follows pagination, and skips
archived repositories while reporting their count.

Run it from either Dev Tools launcher:

```text
dev-tools --github-notifications
```

`--gh-notifications` is also accepted as a shorter alias. The default audit is
read-only and never changes GitHub settings.

## Why GitHub CLI Is Required

Normal `git` authentication covers repository operations such as clone, fetch,
pull, and push. Notification subscriptions are GitHub account-level API data,
so Git credentials alone are not sufficient. This feature uses the authenticated
GitHub CLI (`gh`) only for its own API requests; `gh` is not a global Dev Tools
dependency and Dev Tools never reads or stores its access token.

Install and authenticate GitHub CLI:

```powershell
# Windows
winget install --id GitHub.cli --source winget
gh auth login
```

```bash
# macOS
brew install gh
gh auth login
```

For Linux, follow the current official package instructions in
[Installing gh on Linux and BSD](https://github.com/cli/cli/blob/trunk/docs/install_linux.md),
then run `gh auth login`.

## Audit States

- **Subscribed**: GitHub returned an active repository subscription. The API
  does not reveal which Custom event categories are selected.
- **Not subscribed**: the documented subscription endpoint returned HTTP 404,
  meaning the authenticated user has no repository subscription.
- **Ignored**: the subscription response explicitly returned `ignored=true`,
  meaning repository notifications are blocked.
- **Error**: authentication, permission, transport, or unexpected API response
  prevented a reliable classification. Errors are not treated as unsubscribed.

Repository discovery uses the authenticated-user endpoint with
`affiliation=owner` and `visibility=all`; `gh api --paginate` retrieves more than
100 repositories when necessary. Subscription checks use the documented
`GET /repos/{owner}/{repo}/subscription` endpoint and REST API version
`2026-03-10`.

## Custom Notification Limitation

GitHub's public repository subscription API exposes broad `subscribed` and
`ignored` state. It cannot inspect or configure the individual categories under
**Watch → Custom**, so the audit never claims that Issues, Pull requests, or
Security alerts are enabled.

For actively maintained repositories, review the repository page manually and
prefer:

```text
Watch → Custom
[x] Issues
[x] Pull requests
[x] Security alerts
```

The first implementation intentionally omits the broad “watch all activity”
write operation to avoid accidental notification spam.

## Tests

From the repository root:

```bash
bash main_features/github-notifications/tests/github_notifications_tests.sh
```

```powershell
pwsh -NoProfile -File main_features/github-notifications/tests/github_notifications_tests.ps1
```

Both suites fake GitHub CLI responses and make no real GitHub API changes.

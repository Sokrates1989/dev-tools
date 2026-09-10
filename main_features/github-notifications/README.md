# GitHub Notification Audit

GitHub Notification Audit checks the public API watch state for every active
repository owned by the authenticated GitHub account. It includes public and
private repositories, follows pagination, skips archived repositories while
reporting their count, and links to GitHub's watched-repository management page
at <https://github.com/watching>.

Run it from either Dev Tools launcher:

```text
dev-tools --github-notifications
```

`--gh-notifications` and `--gn` are also accepted as shorter aliases. The
default audit is read-only and never changes GitHub settings.

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

The PowerShell audit refreshes its process PATH from the persisted Windows user
and machine PATH before reporting `gh` as missing. This makes a new winget
installation available immediately, without requiring a new terminal window.

```bash
# macOS
brew install gh
gh auth login
```

For Linux, follow the current official package instructions in
[Installing gh on Linux and BSD](https://github.com/cli/cli/blob/trunk/docs/install_linux.md),
then run `gh auth login`.

## Audit States

- **All Activity / broad watch**: GraphQL returns `SUBSCRIBED`, documented as
  notifications for all conversations.
- **Custom / API-unrepresented**: GraphQL returns `null`. A known Custom control
  appears in this state, but GitHub does not document `null` as exclusively
  Custom and does not expose the selected event categories.
- **Participating / @mentions only**: GraphQL returns `UNSUBSCRIBED`, documented
  as notifications only when participating or mentioned.
- **Ignored**: GraphQL returns `IGNORED`, documented as never notified.
- **Error**: authentication, permission, transport, or unexpected API response
  prevented a reliable classification.

Repository discovery and classification use a paginated GraphQL
`viewer.repositories` query with `affiliations: [OWNER]`, `viewerSubscription`,
and `viewerCanSubscribe`. This retrieves more than 100 repositories when
necessary and replaces one REST subscription request per repository.

The REST `GET /repos/{owner}/{repo}/subscription` endpoint is deliberately not
used for classification. It returns the same HTTP 404 response for the known
Custom control and a repository GraphQL identifies as Participating/@mentions.
Likewise, the observed `GET /user/subscriptions` result exactly matched the
GraphQL `SUBSCRIBED` set and omitted the Custom control, so it represents broad
watches in this observed account rather than every repository configured in the
web Watch menu.

## Custom Notification Limitation

GitHub's public GraphQL schema exposes only `SUBSCRIBED`, `UNSUBSCRIBED`, and
`IGNORED` repository subscription values. The schema contains no repository
preference fields for Issues, pull requests, releases, discussions, or security
alerts. REST notification endpoints return historical notification threads and
reasons, not current repository-level preferences, so the audit never uses
thread history to infer configuration.

For actively maintained repositories, review the repository page manually and
prefer:

```text
Watch → Custom
[x] Issues
[x] Pull requests
[x] Security alerts
```

The audit intentionally performs no subscription mutation and uses no browser
cookies, authenticated HTML scraping, private endpoints, extensions, or local
token storage.

## Real-world regression control

`Sokrates1989/thunderbird-ai` was manually configured in the GitHub web UI as
Custom with Issues, pull requests, releases, discussions, and security alerts.
On 2026-09-10, the supported APIs returned:

- REST repository subscription: HTTP 404.
- Authenticated watched-repository list: absent.
- GraphQL `viewerSubscription`: `null` with `viewerCanSubscribe=true`.

The audit therefore places this repository under **Custom /
API-unrepresented**, never under a “not subscribed” heading. Automated tests
mock this control and do not access the live account.

Official references:

- [Configuring notifications](https://docs.github.com/en/subscriptions-and-notifications/get-started/configuring-notifications)
- [REST API endpoints for watching](https://docs.github.com/en/rest/activity/watching?apiVersion=2026-03-10)
- [GraphQL activity and `SubscriptionState`](https://docs.github.com/en/graphql/reference/activity)
- [REST API endpoints for notifications](https://docs.github.com/en/rest/activity/notifications?apiVersion=2026-03-10)

## Tests

From the repository root:

```bash
bash main_features/github-notifications/tests/github_notifications_tests.sh
```

```powershell
pwsh -NoProfile -File main_features/github-notifications/tests/github_notifications_tests.ps1
```

Both suites fake GitHub CLI responses and make no real GitHub API changes. They
cover all observable states, the Custom control, API errors, pagination beyond
100 repositories, private repositories, and archived repositories.
